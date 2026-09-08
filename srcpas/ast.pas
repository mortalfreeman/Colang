unit ast;

interface

uses
  Classes, Generics.Collections;

type
  // Базовый класс для всех узлов AST
  TNode = class
  public
    Line: Integer;
    Column: Integer;
    constructor Create(ALine, ACol: Integer);
    destructor Destroy; override;
  end;

  // Выражения
  TExprNode = class(TNode)
  end;

  TLiteralNode = class(TExprNode)
  public
    Value: string;
    LitType: string; // 'int', 'flt', 'str'
    constructor Create(const AVal, AType: string; ALine, ACol: Integer);
  end;

  TVarRefNode = class(TExprNode)
  public
    Name: string;
    constructor Create(const AName: string; ALine, ACol: Integer);
  end;

  TBinaryOpNode = class(TExprNode)
  public
    Op: string;
    Left: TExprNode;
    Right: TExprNode;
    constructor Create(const AOp: string; ALeft, ARight: TExprNode; ALine, ACol: Integer);
    destructor Destroy; override;
  end;

  // Инструкции (Statements)
  TStmtNode = class(TNode)
  end;

  TVarDeclNode = class(TStmtNode)
  public
    VarName: string;
    Size: string;     // Размер буфера (например, '64' или '1')
    VarType: string;  // '<int>', '<txt>', '<flt>'
    constructor Create(const AName, ASize, AType: string; ALine, ACol: Integer);
  end;

  TAssignNode = class(TStmtNode)
  public
    VarName: string;
    Expr: TExprNode;
    constructor Create(const AName: string; AExpr: TExprNode; ALine, ACol: Integer);
    destructor Destroy; override;
  end;

  TPrintNode = class(TStmtNode)
  public
    FormatStr: string;
    ArgExpr: TExprNode; // Опционально (может быть nil)
    IsCombine: Boolean;
    constructor Create(const AFmt: string; AArg: TExprNode; ACombine: Boolean; ALine, ACol: Integer);
    destructor Destroy; override;
  end;

  TIfNode = class(TStmtNode)
  public
    Condition: TExprNode;
    ThenBody: TList; // Список TStmtNode
    ElseBody: TList; // Список TStmtNode (может быть пустым)
    constructor Create(ACond: TExprNode; AThen, AElse: TList; ALine, ACol: Integer);
    destructor Destroy; override;
  end;

  TWhileNode = class(TStmtNode)
  public
    Condition: TExprNode;
    Body: TList; // Список TStmtNode
    constructor Create(ACond: TExprNode; ABody: TList; ALine, ACol: Integer);
    destructor Destroy; override;
  end;

  // Функция
  TFunctionNode = class(TNode)
  public
    Name: string;
    Body: TList; // Список TStmtNode
    constructor Create(const AName: string; ABody: TList; ALine, ACol: Integer);
    destructor Destroy; override;
  end;

  // Корень программы
  TProgramNode = class(TNode)
  public
    Functions: TList; // Список TFunctionNode
    constructor Create;
    destructor Destroy; override;
    procedure AddFunction(Func: TFunctionNode);
  end;

implementation

{ TNode }

constructor TNode.Create(ALine, ACol: Integer);
begin
  Line := ALine;
  Column := ACol;
end;

destructor TNode.Destroy;
begin
  inherited;
end;

{ TLiteralNode }

constructor TLiteralNode.Create(const AVal, AType: string; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  Value := AVal;
  LitType := AType;
end;

{ TVarRefNode }

constructor TVarRefNode.Create(const AName: string; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  Name := AName;
end;

{ TBinaryOpNode }

constructor TBinaryOpNode.Create(const AOp: string; ALeft, ARight: TExprNode; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  Op := AOp;
  Left := ALeft;
  Right := ARight;
end;

destructor TBinaryOpNode.Destroy;
begin
  if Assigned(Left) then Left.Free;
  if Assigned(Right) then Right.Free;
  inherited;
end;

{ TVarDeclNode }

constructor TVarDeclNode.Create(const AName, ASize, AType: string; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  VarName := AName;
  Size := ASize;
  VarType := AType;
end;

{ TAssignNode }

constructor TAssignNode.Create(const AName: string; AExpr: TExprNode; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  VarName := AName;
  Expr := AExpr;
end;

destructor TAssignNode.Destroy;
begin
  if Assigned(Expr) then Expr.Free;
  inherited;
end;

{ TPrintNode }

constructor TPrintNode.Create(const AFmt: string; AArg: TExprNode; ACombine: Boolean; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FormatStr := AFmt;
  ArgExpr := AArg;
  IsCombine := ACombine;
end;

destructor TPrintNode.Destroy;
begin
  if Assigned(ArgExpr) then ArgExpr.Free;
  inherited;
end;

{ TIfNode }

constructor TIfNode.Create(ACond: TExprNode; AThen, AElse: TList; ALine, ACol: Integer);
var
  I: Integer;
begin
  inherited Create(ALine, ACol);
  Condition := ACond;
  ThenBody := AThen;
  ElseBody := AElse;
end;

destructor TIfNode.Destroy;
var
  I: Integer;
begin
  if Assigned(Condition) then Condition.Free;
  if Assigned(ThenBody) then
  begin
    for I := 0 to ThenBody.Count - 1 do
      TObject(ThenBody[I]).Free;
    ThenBody.Free;
  end;
  if Assigned(ElseBody) then
  begin
    for I := 0 to ElseBody.Count - 1 do
      TObject(ElseBody[I]).Free;
    ElseBody.Free;
  end;
  inherited;
end;

{ TWhileNode }

constructor TWhileNode.Create(ACond: TExprNode; ABody: TList; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  Condition := ACond;
  Body := ABody;
end;

destructor TWhileNode.Destroy;
var
  I: Integer;
begin
  if Assigned(Condition) then Condition.Free;
  if Assigned(Body) then
  begin
    for I := 0 to Body.Count - 1 do
      TObject(Body[I]).Free;
    Body.Free;
  end;
  inherited;
end;

{ TFunctionNode }

constructor TFunctionNode.Create(const AName: string; ABody: TList; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  Name := AName;
  Body := ABody;
end;

destructor TFunctionNode.Destroy;
var
  I: Integer;
begin
  if Assigned(Body) then
  begin
    for I := 0 to Body.Count - 1 do
      TObject(Body[I]).Free;
    Body.Free;
  end;
  inherited;
end;

{ TProgramNode }

constructor TProgramNode.Create;
begin
  inherited Create(0, 0);
  Functions := TList.Create;
end;

destructor TProgramNode.Destroy;
var
  I: Integer;
begin
  if Assigned(Functions) then
  begin
    for I := 0 to Functions.Count - 1 do
      TObject(Functions[I]).Free;
    Functions.Free;
  end;
  inherited;
end;

procedure TProgramNode.AddFunction(Func: TFunctionNode);
begin
  Functions.Add(Func);
end;

end.
