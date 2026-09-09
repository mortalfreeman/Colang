program main;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  lexer, ast, parser, symtable, errors, semantic, codegen_x64, runtime;

var
  InputFile: String = '';
  OutputFile: String = 'output.asm';
  VerboseMode: Boolean = False;

procedure PrintHelp;
begin
  Writeln('CoLang Compiler (clc_fpc) v0.2 [Free Pascal Edition]');
  Writeln('Usage: clc_fpc <input_file.cl> [options]');
  Writeln('');
  Writeln('Options:');
  Writeln('  -o <file>   Specify output assembly file (default: output.asm)');
  Writeln('  -v          Enable verbose compilation output');
  Writeln('  -h, --help  Display this help message');
  Halt(0);
end;

procedure ParseCommandLine;
var
  I: Integer;
  Arg: String;
begin
  if ParamCount = 0 then
  begin
    Writeln(StdErr, 'Error: No input file specified.');
    PrintHelp;
  end;

  I := 1;
  while I <= ParamCount do
  begin
    Arg := ParamStr(I);

    if (Arg = '-h') or (Arg = '--help') then
      PrintHelp
    else if Arg = '-v' then
      VerboseMode := True
    else if Arg = '-o' then
    begin
      Inc(I);
      if I <= ParamCount then
        OutputFile := ParamStr(I)
      else
        ReportFatal('Option -o requires an output filename argument.');
    end
    else if (Length(Arg) > 0) and (Arg[1] = '-') then
      ReportFatal('Unknown command line option: ' + Arg)
    else
      InputFile := Arg;

    Inc(I);
  end;

  if InputFile = '' then
    ReportFatal('No input CoLang file (.cl) provided.');
end;

var
  LexerObj: TLexer;
  ParserObj: TParser;
  SemanticObj: TSemanticAnalyzer;
  CodegenObj: TCodeGeneratorX64;
  ASTRoot: TProgramNode;

begin
  // 1. Разбор аргументов командной строки
  ParseCommandLine;

  if VerboseMode then
  begin
    Writeln('[CLC_FPC] Input file:  ', InputFile);
    Writeln('[CLC_FPC] Output file: ', OutputFile);
  end;

  if not FileExists(InputFile) then
    ReportFatal('Input file not found: ' + InputFile);

  try
    // 2. Лексический анализ (Lexer)
    if VerboseMode then Writeln('[CLC_FPC] Stage 1: Lexical analysis...');
    LexerObj := TLexer.Create(InputFile);

    // 3. Синтаксический анализ и построение AST (Parser)
    if VerboseMode then Writeln('[CLC_FPC] Stage 2: Parsing & AST construction...');
    ParserObj := TParser.Create(LexerObj);
    ASTRoot := ParserObj.ParseProgram;

    if GetErrorCount > 0 then
      ReportFatal('Compilation halted due to syntax errors.');

    // 4. Семантический анализ и валидация (Semantic Analyzer)
    if VerboseMode then Writeln('[CLC_FPC] Stage 3: Semantic analysis & Scope checking...');
    SemanticObj := TSemanticAnalyzer.Create(InputFile);
    SemanticObj.AnalyzeProgram(ASTRoot);

    if GetErrorCount > 0 then
      ReportFatal('Compilation halted due to semantic errors.');

    // 5. Генерация кода NASM x86_64 (Code Generator)
    if VerboseMode then Writeln('[CLC_FPC] Stage 4: Code generation (NASM x86_64)...');
    CodegenObj := TCodeGeneratorX64.Create(SemanticObj.SymTable, InputFile);
    CodegenObj.GenerateProgram(ASTRoot, OutputFile);

    if VerboseMode then
      Writeln('[CLC_FPC] Compilation successful! Saved to ', OutputFile)
    else
      Writeln('Assembly code successfully written to ', OutputFile);

  except
    on E: Exception do
    begin
      Writeln(StdErr, 'Unhandled Compiler Exception: ', E.Message);
      Halt(1);
    end;
  end;
end.
