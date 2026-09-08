program clc_pascal;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, lexer, parser, ast, semantic, codegen_x64;

procedure PrintUsage(const ProgramName: string);
begin
  Writeln('Использование: ', ExtractFileName(ProgramName), ' <файл.cl>');
  Writeln('Стабильный компилятор CoLang (Free Pascal Edition)');
end;

function ReadFileToString(const FileName: string): string;
var
  Stream: TStringStream;
begin
  if not FileExists(FileName) then
  begin
    Writeln(ErrOutput, 'Ошибка: файл не найден -> ', FileName);
    Halt(1);
  end;
  
  Stream := TStringStream.Create('', TEncoding.UTF8);
  try
    Stream.LoadFromFile(FileName);
    Result := Stream.DataString;
  finally
    Stream.Free;
  end;
end;

var
  SrcFile: string;
  SourceCode: string;
  Lex: TLexer;
  Pars: TParser;
  ProgramNode: TProgramNode;
  Sem: TSemanticAnalyzer;
  Codegen: TCodeGenerator;
  AsmCode: string;
begin
  Writeln('=== CoLang Compiler (FPC Stable Version) ===');
  
  if ParamCount < 1 then
  begin
    PrintUsage(ParamStr(0));
    Halt(1);
  end;

  SrcFile := ParamStr(1);
  Writeln('Чтение файла: ', SrcFile);

  SourceCode := ReadFileToString(SrcFile);

  // 1. Лексер
  Writeln('[1/4] Лексический анализ...');
  Lex := TLexer.Create(SourceCode);

  // 2. Парсер (AST)
  Writeln('[2/4] Синтаксический анализ...');
  Pars := TParser.Create(Lex);
  ProgramNode := Pars.ParseProgram;

  if Pars.ErrorCount > 0 then
  begin
    Writeln(ErrOutput, Format('Компиляция прервана: ошибок синтаксиса: %d', [Pars.ErrorCount]));
    ProgramNode.Free; Pars.Free; Lex.Free;
    Halt(1);
  end;

  // 3. Семантический анализ
  Writeln('[3/4] Семантический анализ...');
  Sem := TSemanticAnalyzer.Create;
  if not Sem.Analyze(ProgramNode) then
  begin
    Writeln(ErrOutput, Format('Компиляция прервана: семантических ошибок: %d', [Sem.ErrorCount]));
    Sem.Free; ProgramNode.Free; Pars.Free; Lex.Free;
    Halt(1);
  end;
  Sem.Free;

  // 4. Генерация кода x64 (NASM)
  Writeln('[4/4] Генерация x64 ассемблера...');
  Codegen := TCodeGenerator.Create;
  AsmCode := Codegen.Generate(ProgramNode);
  Codegen.Free;

  // Сохраняем ассемблер в файл
  AsmCodeToFile:
  stringList := TStringList.Create;
  try
    stringList.Text := AsmCode;
    stringList.SaveToFile('output.asm');
  finally
    stringList.Free;
  end;

  Writeln('Успешно! Ассемблер сохранен в файл: output.asm');

  ProgramNode.Free;
  Pars.Free;
  Lex.Free;
end.
