unit semantic;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, ast, symtable, errors;

type
  TSemanticAnalyzer = class
  private
    FSymTable: TSymTable;
    FCurrentFileName: String;
    FHasMain: Boolean;
    
    function MapTypeStrToVarType(const TypeStr: String): TVarType;
  public
    constructor Create(const AFileName: String);
    destructor Destroy; override;

    procedure AnalyzeProgram(ProgramNode: TProgramNode);
    procedure AnalyzeFunction(FuncNode: TFunctionNode);
    procedure AnalyzeStatement(StmtNode: TStatementNode);
    
    property SymTable: TSymTable read FSymTable;
  end;

implementation

constructor TSemanticAnalyzer.Create(const AFileName: String);
begin
  inherited Create;
  FSymTable := TSymTable.Create;
  FCurrentFileName := AFileName;
  FHasMain := False;
end;

destructor TSemanticAnalyzer.Destroy;
begin
  FSymTable.Free;
  inherited Destroy;
end;

function TSemanticAnalyzer.MapTypeStrToVarType(const TypeStr: String): TVarType;
begin
  if TypeStr = '<int>' then Result := vtInt
  else if TypeStr = '<flt>' then Result := vtFlt
  else if TypeStr = '<txt>' then Result := vtTxt
  else Result := vtUnknown;
end;

procedure TSemanticAnalyzer.AnalyzeProgram(ProgramNode: TProgramNode);
var
  I: Integer;
begin
  if ProgramNode = nil then Exit;

  // Анализируем все функции в программе
  for I := 0 to ProgramNode.FunctionCount - 1 do
  begin
    AnalyzeFunction(ProgramNode.Functions[I]);
  end;

  // Проверяем, была ли найдена точка входа main
  if not FHasMain then
    ReportError(etSemantic, FCurrentFileName, 0, 0, 'Missing mandatory entry point function "main".');
end;

procedure TSemanticAnalyzer.AnalyzeFunction(FuncNode: TFunctionNode);
var
  I: Integer;
begin
  if FuncNode = nil then Exit;

  if FuncNode.Name = 'main' then
    FHasMain := True;

  // Открываем новую область видимости для функции
  FSymTable.EnterScope;

  // Проходим по всем стейтментам внутри функции
  for I := 0 to FuncNode.StatementCount - 1 do
  begin
    AnalyzeStatement(FuncNode.Statements[I]);
  end;

  // Закрываем область видимости функции
  FSymTable.LeaveScope;
end;

procedure TSemanticAnalyzer.AnalyzeStatement(StmtNode: TStatementNode);
var
  VarSym: PSymbol;
  VType: TVarType;
begin
  if StmtNode = nil then Exit;

  case StmtNode.NodeType of
    ntMakeVar:
      begin
        VType := MapTypeStrToVarType(StmtNode.VarTypeStr);
        if VType = vtUnknown then
          ReportError(etSemantic, FCurrentFileName, StmtNode.Line, StmtNode.Col, 
            'Unknown data type: ' + StmtNode.VarTypeStr);

        // Регистрируем переменную в таблице символов текущего скоупа
        try
          FSymTable.AddSymbol(StmtNode.VarName, VType, StmtNode.VarSize);
        except
          on E: Exception do
            ReportError(etSemantic, FCurrentFileName, StmtNode.Line, StmtNode.Col, E.Message);
        end;
      end;

    ntAssignment:
      begin
        // Проверяем, объявлена ли целевая переменная
        VarSym := FSymTable.Lookup(StmtNode.VarName);
        if VarSym = nil then
          ReportError(etSemantic, FCurrentFileName, StmtNode.Line, StmtNode.Col, 
            'Undeclared variable used in assignment: ' + StmtNode.VarName);
      end;

    ntOPrint, ntITaker:
      begin
        // Проверка вызовов ввода/вывода (проверяем переменные в аргументах, если есть)
        if (StmtNode.VarName <> '') and (FSymTable.Lookup(StmtNode.VarName) = nil) then
          ReportError(etSemantic, FCurrentFileName, StmtNode.Line, StmtNode.Col, 
            'Undeclared variable in I/O statement: ' + StmtNode.VarName);
      end;

    ntIf, ntWhile:
      begin
        // Открываем вложенный скоуп для блока ustart / uend внутри условий и циклов
        FSymTable.EnterScope;
        // Рекурсивно проверяем тело блока (если оно представлено списком стейтментов)
        // ... обход дочерних узлов тела блока ...
        FSymTable.LeaveScope;
      end;
  else
    // Другие типы узлов пока пропуском без фатальных ошибок
  end;
end;

end.
