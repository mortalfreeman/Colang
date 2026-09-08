unit codegen_x64;

interface

uses
  Classes, SysUtils, ast;

type
  TCodeGenerator = class
  private
    FOutput: TStringList;
    procedure Emit(const Line: string);
    procedure GenExpr(Expr: TExprNode);
    procedure GenStmt(Stmt: TStmtNode);
  public
    constructor Create;
    destructor Destroy; override;
    function Generate(ProgramNode: TProgramNode): string;
  end;

implementation

constructor TCodeGenerator.Create;
begin
  FOutput := TStringList.Create;
end;

destructor TCodeGenerator.Destroy;
begin
  FOutput.Free;
  inherited;
end;

procedure TCodeGenerator.Emit(const Line: string);
begin
  FOutput.Add(Line);
end;

procedure TCodeGenerator.GenExpr(Expr: TExprNode);
var
  Lit: TLiteralNode;
  VarRef: TVarRefNode;
  BinOp: TBinaryOpNode;
begin
  if not Assigned(Expr) then Exit;

  if Expr is TLiteralNode then
  begin
    Lit := TLiteralNode(Expr);
    if Lit.LitType = 'int' then
    begin
      Emit('    mov rax, ' + Lit.Value);
    end;
  end
  else if Expr is TVarRefNode then
  begin
    VarRef := TVarRefNode(Expr);
    Emit('    ; чтение переменной ' + VarRef.Name);
    Emit('    mov rax, 0'); // Заглушка до реализации стека переменных
  end
  else if Expr is TBinaryOpNode then
  begin
    BinOp := TBinaryOpNode(Expr);
    GenExpr(BinOp.Left);
    Emit('    push rax');
    GenExpr(BinOp.Right);
    Emit('    pop rbx');
    
    if BinOp.Op = '+' then
      Emit('    add rax, rbx')
    else if BinOp.Op = '-' then
    begin
      Emit('    xchg rax, rbx');
      Emit('    sub rax, rbx');
    end;
  end;
end;

procedure TCodeGenerator.GenStmt(Stmt: TStmtNode);
var
  Assign: TAssignNode;
  Print: TPrintNode;
  I: Integer;
  IfNode: TIfNode;
begin
  if not Assigned(Stmt) then Exit;

  if Stmt is TAssignNode then
  begin
    Assign := TAssignNode(Stmt);
    GenExpr(Assign.Expr);
    Emit('    ; сохранение в переменную ' + Assign.VarName);
  end
  else if Stmt is TPrintNode then
  begin
    Print := TPrintNode(Stmt);
    if Assigned(Print.ArgExpr) then
    begin
      GenExpr(Print.ArgExpr);
      // Переносим результат из RAX в RDI (первый аргумент по соглашению x86_64 ABI)
      Emit('    mov rdi, rax');
      Emit('    call colang_print_int');
    end;
  end
  else if Stmt is TIfNode then
  begin
    IfNode := TIfNode(Stmt);
    GenExpr(IfNode.Condition);
    Emit('    cmp rax, 0');
    Emit('    je .L_else_end');
    if Assigned(IfNode.ThenBody) then
      for I := 0 to IfNode.ThenBody.Count - 1 do
        GenStmt(TStmtNode(IfNode.ThenBody[I]));
    Emit('.L_else_end:');
  end;
end;

function TCodeGenerator.Generate(ProgramNode: TProgramNode): string;
var
  I, J: Integer;
  Func: TFunctionNode;
begin
  FOutput.Clear;
  
  // Заголовок NASM с экспортом main и импортом рантайма на Паскале
  Emit('BITS 64');
  Emit('global main');
  Emit('extern colang_print_int');
  Emit('extern colang_print_str');
  Emit('extern colang_input_int');
  Emit('section .text');
  Emit('');

  for I := 0 to ProgramNode.Functions.Count - 1 do
  begin
    Func := TFunctionNode(ProgramNode.Functions[I]);
    Emit(Func.Name + ':');
    Emit('    push rbp');
    Emit('    mov rbp, rsp');

    if Assigned(Func.Body) then
    begin
      for J := 0 to Func.Body.Count - 1 do
        GenStmt(TStmtNode(Func.Body[J]));
    end;

    Emit('    mov rsp, rbp');
    Emit('    pop rbp');
    if Func.Name = 'main' then
    begin
      Emit('    mov rax, 0'); // возвращаем 0 из main
      Emit('    ret');
    end
    else
    begin
      Emit('    ret');
    end;
    Emit('');
  end;

  Result := FOutput.Text;
end;

end.
