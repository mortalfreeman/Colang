unit semantic;

interface

uses
  Classes, SysUtils, Generics.Collections, ast;

type
  TSymbol = record
    Name: string;
    VarType: string;
    Size: string;
    Line: Integer;
  end;

  TSymbolTable = class
  private
    Fsymbols: specialize TDictionary<string, TSymbol>;
  public
    constructor Create;
    destructor Destroy; override;
    function Define(const Name, VarType, Size: string; Line: Integer): Boolean;
    function Lookup(const Name: string; out Sym: TSymbol): Boolean;
  end;

  TSemanticAnalyzer = class
  private
    FErrorCount: Integer;
    procedure LogError(const Msg: string; Line, Col: Integer);
    procedure AnalyzeExpr(Expr: TExprNode; Symbols: TSymbolTable);
    procedure AnalyzeStmt(Stmt: TStmtNode; Symbols: TSymbolTable);
  public
    constructor Create;
    function Analyze(ProgramNode: TProgramNode): Boolean;
    property ErrorCount: Integer read FErrorCount;
  end;

implementation

{ TSymbolTable }

constructor TSymbolTable.Create;
begin
  Fsymbols := specialize TDictionary<string, TSymbol>.Create;
end;

destructor TSymbolTable.Destroy;
begin
  Fsymbols.Free;
  inherited;
end;

function TSymbolTable.Define(const Name, VarType, Size: string; Line: Integer): Boolean;
begin
  if Fsymbols.ContainsKey(Name) then
    Exit(False); // Уже объявлена
    
  var Sym: TSymbol;
  Sym.Name := Name;
  Sym.VarType := VarType;
  Sym.Size := Size;
  Sym.Line := Line;
  Fsymbols.Add(Name, Sym);
  Result := True;
end;

function TSymbolTable.Lookup(const Name: string; out Sym: TSymbol): Boolean;
begin
  Result := Fsymbols.TryGetValue(Name, Sym);
end;

{ TSemanticAnalyzer }

constructor TSemanticAnalyzer.Create;
begin
  FErrorCount := 0;
end;

procedure TSemanticAnalyzer.LogError(const Msg: string; Line, Col: Integer;);
begin
  Inc(FErrorCount);
  Writeln(ErrOutput, Format('Семантическая ошибка [строка %d, кол %d]: %s', [Line, Col, Msg]));
end;

procedure TSemanticAnalyzer.AnalyzeExpr(Expr: TExprNode; Symbols: TSymbolTable);
var
  VarRef: TVarRefNode;
  BinOp: TBinaryOpNode;
  Sym: TSymbol;
begin
  if not Assigned(Expr) then Exit;

  if Expr is TVarRefNode then
  begin
    VarRef := TVarRefNode(Expr);
    if not Symbols.Lookup(VarRef.Name, Sym) then
      LogError(Format('Использование необъявленной переменной "%s"', [VarRef.Name]), VarRef.Line, VarRef.Column);
  end
  else if Expr is TBinaryOpNode then
  begin
    BinOp := TBinaryOpNode(Expr);
    AnalyzeExpr(BinOp.Left, Symbols);
    AnalyzeExpr(BinOp.Right, Symbols);
  end;
end;

procedure TSemanticAnalyzer.AnalyzeStmt(Stmt: TStmtNode; Symbols: TSymbolTable);
var
  VarDecl: TVarDeclNode;
  Assign: TAssignNode;
  Print: TPrintNode;
  IfNode: TIfNode;
  WhileNode: TWhileNode;
  Sym: TSymbol;
  I: Integer;
begin
  if not Assigned(Stmt) then Exit;

  if Stmt is TVarDeclNode then
  begin
    VarDecl := TVarDeclNode(Stmt);
    if not Symbols.Define(VarDecl.VarName, VarDecl.VarType, VarDecl.Size, VarDecl.Line) then
      LogError(Format('Передекларация переменной "%s"', [VarDecl.VarName]), VarDecl.Line, VarDecl.Column);
  end
  else if Stmt is TAssignNode then
  begin
    Assign := TAssignNode(Stmt);
    if not Symbols.Lookup(Assign.VarName, Sym) then
      LogError(Format('Присваивание в необъявленную переменную "%s"', [Assign.VarName]), Assign.Line, Assign.Column);
    AnalyzeExpr(Assign.Expr, Symbols);
  end
  else if Stmt is TPrintNode then
  begin
    Print := TPrintNode(Stmt);
    if Assigned(Print.ArgExpr) then
      AnalyzeExpr(Print.ArgExpr, Symbols);
  end
  else if Stmt is TIfNode then
  begin
    IfNode := TIfNode(Stmt);
    AnalyzeExpr(IfNode.Condition, Symbols);
    if Assigned(IfNode.ThenBody) then
      for I := 0 to IfNode.ThenBody.Count - 1 do
        AnalyzeStmt(TStmtNode(IfNode.ThenBody[I]), Symbols);
  end
  else if Stmt is TWhileNode then
  begin
    WhileNode := TWhileNode(Stmt);
    AnalyzeExpr(WhileNode.Condition, Symbols);
    if Assigned(WhileNode.Body) then
      for I := 0 to WhileNode.Body.Count - 1 do
        AnalyzeStmt(TStmtNode(WhileNode.Body[I]), Symbols);
  end;
end;

function TSemanticAnalyzer.Analyze(ProgramNode: TProgramNode): Boolean;
var
  F: TFunctionNode;
  Symbols: TSymbolTable;
  I, J: Integer;
  HasMain: Boolean;
begin
  HasMain := False;
  Symbols := TSymbolTable.Create;
  try
    for I := 0 to ProgramNode.Functions.Count - 1 do
    begin
      F := TFunctionNode(ProgramNode.Functions[I]);
      if F.Name = 'main' then
        HasMain := True;

      if Assigned(F.Body) then
      begin
        for J := 0 to F.Body.Count - 1 do
          AnalyzeStmt(TStmtNode(F.Body[J]), Symbols);
      end;
    end;

    if not HasMain then
    begin
      Inc(FErrorCount);
      Writeln(ErrOutput, 'Семантическая ошибка: в программе отсутствует обязательная функция "main".');
    end;

    Result := (FErrorCount = 0);
  finally
    Symbols.Free;
  end;
end;

end.
