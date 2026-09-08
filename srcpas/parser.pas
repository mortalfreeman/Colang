unit parser;

interface

uses
  Classes, SysUtils, lexer, ast;

type
  TParser = class
  private
    FLexer: TLexer;
    FCurrentToken: TToken;
    FErrorCount: Integer;
    
    procedure Advance;
    procedure Expect(AType: TTokenType; const AMessage: string);
    
    function ParseExpr: TExprNode;
    function ParsePrimary: TExprNode;
    function ParseTerm: TExprNode;
    function ParseAdditive: TExprNode;
    function ParseComparison: TExprNode;
    
    function ParseStatement: TStmtNode;
    function ParseStatementList: TList;
    function ParseFunction: TFunctionNode;
  public
    constructor Create(ALexer: TLexer);
    function ParseProgram: TProgramNode;
    property ErrorCount: Integer read FErrorCount;
  end;

implementation

constructor TParser.Create(ALexer: TLexer);
begin
  FLexer := ALexer;
  FErrorCount := 0;
  Advance; // Загружаем первый токен
end;

procedure TParser.Advance;
begin
  FCurrentToken := FLexer.NextToken;
end;

procedure TParser.Expect(AType: TTokenType; const AMessage: string);
begin
  if FCurrentToken.TokenType = AType then
    Advance
  else
    begin
      Inc(FErrorCount);
      Writeln(Format('Ошибка синтаксиса в строке %d, кол %d: %s (найдено: %s)', 
        [FCurrentToken.Line, FCurrentToken.Column, AMessage, FCurrentToken.Value]));
    end;
end;

// Разбор выражений (базовый приоритет)
function TParser.ParsePrimary: TExprNode;
var
  Val, LitType: string;
  Line, Col: Integer;
begin
  Line := FCurrentToken.Line;
  Col := FCurrentToken.Column;

  if FCurrentToken.TokenType = ttInteger then
  begin
    Val := FCurrentToken.Value;
    LitType := 'int';
    Advance;
    Exit(TLiteralNode.Create(Val, LitType, Line, Col));
  end
  else if FCurrentToken.TokenType = ttFloat then
  begin
    Val := FCurrentToken.Value;
    LitType := 'flt';
    Advance;
    Exit(TLiteralNode.Create(Val, LitType, Line, Col));
  end
  else if FCurrentToken.TokenType = ttString then
  begin
    Val := FCurrentToken.Value;
    LitType := 'str';
    Advance;
    Exit(TLiteralNode.Create(Val, LitType, Line, Col));
  end
  else if FCurrentToken.TokenType = ttIdentifier then
  begin
    Val := FCurrentToken.Value;
    Advance;
    Exit(TVarRefNode.Create(Val, Line, Col));
  end
  else
  begin
    Inc(FErrorCount);
    Writeln(Format('Ошибка: ожидалось выражение в строке %d, кол %d', [Line, Col]));
    Advance;
    Result := TLiteralNode.Create('0', 'int', Line, Col);
  end;
end;

function TParser.ParseTerm: TExprNode;
var
  Node: TExprNode;
  Op: string;
  Line, Col: Integer;
begin
  Node := ParsePrimary;
  while (FCurrentToken.Value = '*') or (FCurrentToken.Value = '/') do
  begin
    Line := FCurrentToken.Line;
    Col := FCurrentToken.Column;
    Op := FCurrentToken.Value;
    Advance;
    Node := TBinaryOpNode.Create(Op, Node, ParsePrimary, Line, Col);
  end;
  Result := Node;
end;

function TParser.ParseAdditive: TExprNode;
var
  Node: TExprNode;
  Op: string;
  Line, Col: Integer;
begin
  Node := ParseTerm;
  while (FCurrentToken.Value = '+') or (FCurrentToken.Value = '-') do
  begin
    Line := FCurrentToken.Line;
    Col := FCurrentToken.Column;
    Op := FCurrentToken.Value;
    Advance;
    Node := TBinaryOpNode.Create(Op, Node, ParseTerm, Line, Col);
  end;
  Result := Node;
end;

function TParser.ParseComparison: TExprNode;
var
  Node: TExprNode;
  Op: string;
  Line, Col: Integer;
begin
  Node := ParseAdditive;
  if (FCurrentToken.TokenType = ttEqual) or (FCurrentToken.TokenType = ttNotEqual) or
     (FCurrentToken.TokenType = ttLAngle) or (FCurrentToken.TokenType = ttRAngle) then
  begin
    Line := FCurrentToken.Line;
    Col := FCurrentToken.Column;
    Op := FCurrentToken.Value;
    Advance;
    Node := TBinaryOpNode.Create(Op, Node, ParseAdditive, Line, Col);
  end;
  Result := Node;
end;

function TParser.ParseExpr: TExprNode;
begin
  Result := ParseComparison;
end;

// Разбор инструкций
function TParser.ParseStatement: TStmtNode;
var
  Line, Col: Integer;
  VarName, Size, VarType: string;
  Expr: TExprNode;
  FmtStr: string;
  ArgExpr: TExprNode;
  IsCombine: Boolean;
  Cond: TExprNode;
  ThenList, ElseList: TList;
begin
  Line := FCurrentToken.Line;
  Col := FCurrentToken.Column;

  // make var имя[размер] <тип>
  if (FCurrentToken.TokenType = ttKeyword) and (FCurrentToken.Value = 'make') then
  begin
    Advance; // пропускаем 'make'
    // может быть 'var'
    if (FCurrentToken.TokenType = ttKeyword) and (FCurrentToken.Value = 'var') then
      Advance;

    VarName := FCurrentToken.Value;
    Expect(ttIdentifier, 'Ожидалось имя переменной');
    
    Expect(ttLBracket, 'Ожидалось "["');
    Size := FCurrentToken.Value;
    Advance;
    Expect(ttRBracket, 'Ожидалось "]"');

    // Ожидаем тип вроде <int> или <txt>
    VarType := '';
    if FCurrentToken.TokenType = ttLAngle then
    begin
      Advance;
      VarType := '<' + FCurrentToken.Value + '>';
      Advance;
      if FCurrentToken.TokenType = ttRAngle then
        Advance;
    end;

    Exit(TVarDeclNode.Create(VarName, Size, VarType, Line, Col));
  end;

  // let имя = выражение
  if (FCurrentToken.TokenType = ttKeyword) and (FCurrentToken.Value = 'let') then
  begin
    Advance;
    VarName := FCurrentToken.Value;
    Expect(ttIdentifier, 'Ожидалось имя переменной для присваивания');
    Expect(ttAssign, 'Ожидалось "="');
    Expr := ParseExpr;
    Exit(TAssignNode.Create(VarName, Expr, Line, Col));
  end;

  // oprint("текст", аргумент)
  if (FCurrentToken.TokenType = ttKeyword) and (FCurrentToken.Value = 'oprint') then
  begin
    Advance;
    // круглые скобки
    Advance; // пропуск '('
    FmtStr := FCurrentToken.Value;
    Advance; // пропуск строки
    
    ArgExpr := nil;
    if FCurrentToken.TokenType = ttComma then
    begin
      Advance;
      ArgExpr := ParseExpr;
    end;
    
    if FCurrentToken.TokenType = ttRBracket then // закрывающая скобка может распарситься по-разному, упрощенно:
      Advance;

    IsCombine := False;
    if (FCurrentToken.TokenType = ttLAngle) or (FCurrentToken.Value = '<combine>') then
    begin
      IsCombine := True;
      // пропуск <combine>
      while (FCurrentToken.TokenType <> ttEof) and (FCurrentToken.Value <> '>') do
        Advance;
      if FCurrentToken.Value = '>' then Advance;
    end;

    Exit(TPrintNode.Create(FmtStr, ArgExpr, IsCombine, Line, Col));
  end;

  // if условие ustart ... uend
  if (FCurrentToken.TokenType = ttKeyword) and (FCurrentToken.Value = 'if') then
  begin
    Advance;
    Cond := ParseExpr;
    
    if (FCurrentToken.TokenType = ttKeyword) and (FCurrentToken.Value = 'ustart') then
      Advance;

    ThenList := ParseStatementList;
    ElseList := nil; // Упрощенно для базового каркаса

    Exit(TIfNode.Create(Cond, ThenList, ElseList, Line, Col));
  end;

  // Если инструкция не распознана, продвигаемся дальше во избежание зацикливания
  Advance;
  Result := nil;
end;

function TParser.ParseStatementList: TList;
var
  List: TList;
  Stmt: TStmtNode;
begin
  List := TList.Create;
  while (FCurrentToken.TokenType <> ttEof) do
  begin
    if (FCurrentToken.TokenType = ttKeyword) and 
       ((FCurrentToken.Value = 'uend') or (FCurrentToken.Value = 'else') or (FCurrentToken.Value = 'elsif')) then
    begin
      if FCurrentToken.Value = 'uend' then
        Advance; // съедаем uend
      Break;
    end;

    Stmt := ParseStatement;
    if Assigned(Stmt) then
      List.Add(Stmt);
  end;
  Result := List;
end;

function TParser.ParseFunction: TFunctionNode;
var
  FuncName: string;
  Body: TList;
  Line, Col: Integer;
begin
  Line := FCurrentToken.Line;
  Col := FCurrentToken.Column;

  Expect(ttKeyword, 'Ожидалось ключевое слово func');
  FuncName := FCurrentToken.Value;
  Expect(ttIdentifier, 'Ожидалось имя функции');

  if (FCurrentToken.TokenType = ttKeyword) and (FCurrentToken.Value = 'ustart') then
    Advance;

  Body := ParseStatementList;

  Result := TFunctionNode.Create(FuncName, Body, Line, Col);
end;

function TParser.ParseProgram: TProgramNode;
var
  Prog: TProgramNode;
  Func: TFunctionNode;
begin
  Prog := TProgramNode.Create;
  while FCurrentToken.TokenType <> ttEof do
  begin
    if (FCurrentToken.TokenType = ttKeyword) and (FCurrentToken.Value = 'func') then
    begin
      Func := ParseFunction;
      Prog.AddFunction(Func);
    end
    else
    begin
      Advance;
    end;
  end;
  Result := Prog;
end;

end.
