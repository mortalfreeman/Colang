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
      // Загружаем число в аккумулятор RAX
      Emit('    mov rax, ' + Lit.Value);
    end;
  end
  else if Expr is TVarRefNode then
  begin
    VarRef := TVarRefNode(Expr);
    // Пока заглушка для стека переменных
    Emit('    ; чтение переменной ' + VarRef.Name);
    Emit('    mov rax, 0');
  end
  else if Expr is TBinaryOpNode then
  begin
    BinOp := TBinaryOpNode(Expr);
    GenExpr(BinOp.Left);
    Emit('    push rax'); // сохраняем левый операнд в стек
    GenExpr(BinOp.Right);
    Emit('    pop rbx');  // достаем левый операнд в rbx, правый в rax
    
    if BinOp.Op = '+' then
      Emit('    add rax, rbx')
    else if BinOp.Op = '-' then
    begin
      Emit('    xchg rax, rbx'); // rax - левый, rbx - правый
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
    // Здесь будет запись из rax в стек или секцию данных
  end
  else if Stmt is TPrintNode then
  begin
    Print := TPrintNode(Stmt);
    if Assigned(Print.ArgExpr) then
    begin
      GenExpr(Print.ArgExpr);
      // Перекладываем результат для системного вывода (System V AMD64 ABI: rdi/rsi)
      Emit('    mov rsi, rax');
    end;
    Emit('    ; вызов oprint / системного вывода');
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
  
  // Заголовок NASM для Linux x86_64
  Emit('BITS 64');
  Emit('global main');
  Emit('extern printf');
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

    // Стандартный выход из функции
    Emit('    mov rsp, rbp');
    Emit('    pop rbp');
    if Func.Name = 'main' then
    begin
      Emit('    mov rax, 60'); // системный вызов exit в Linux
      Emit('    xor rdi, rdi');
      Emit('    syscall');
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
