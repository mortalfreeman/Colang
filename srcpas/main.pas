program clc_pascal;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, lexer, parser, ast;

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
begin
  Writeln('=== CoLang Compiler (FPC Stable Version) ===');
  
  if ParamCount < 1 then
  begin
    PrintUsage(ParamStr(0));
    Halt(1);
  end;

  SrcFile := ParamStr(1);
  Writeln('Чтение файла: ', SrcFile);

  // Шаг 1. Читаем исходный код .cl
  SourceCode := ReadFileToString(SrcFile);

  // Шаг 2. Лексический анализ
  Writeln('[1/3] Запуск лексера...');
  Lex := TLexer.Create(SourceCode);

  // Шаг 3. Синтаксический анализ (Парсер)
  Writeln('[2/3] Построение синтаксического дерева (AST)...');
  Pars := TParser.Create(Lex);
  
  ProgramNode := Pars.ParseProgram;

  if Pars.ErrorCount > 0 then
  begin
    Writeln(ErrOutput, Format('Компиляция прервана: обнаружено ошибок: %d', [Pars.ErrorCount]));
    ProgramNode.Free;
    Pars.Free;
    Lex.Free;
    Halt(1);
  end;

  Writeln('[3/3] Синтаксический анализ успешно завершен!');
  Writeln(Format('Успешно разобрано функций: %d', [ProgramNode.Functions.Count]));

  // Очистка памяти
  ProgramNode.Free;
  Pars.Free;
  Lex.Free;

  Writeln('Готово! Базовый конвейер на Free Pascal работает стабильно.');
end.
