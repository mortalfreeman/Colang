unit errors;

{$mode objfpc}{$H+

interface

uses
  SysUtils;

type
  TErrorType = (etLexical, etSyntax, etSemantic, etInternal);

  // Процедуры для вывода красивых ошибок с привязкой к позиции в коде
  procedure ReportError(ErrType: TErrorType; const AFileName: String; ALine, ACol: Integer; const AMessage: String);
  procedure ReportFatal(const AMessage: String);
  
  function GetErrorCount: Integer;
  procedure ResetErrorCount;

implementation

var
  GErrorCount: Integer = 0;

function ErrorTypeToString(ErrType: TErrorType): String;
begin
  case ErrType of
    etLexical:   Result := 'Lexical Error';
    etSyntax:    Result := 'Syntax Error';
    etSemantic:  Result := 'Semantic Error';
    etInternal:  Result := 'Internal Compiler Error';
  else
    Result := 'Error';
  end;
end;

procedure ReportError(ErrType: TErrorType; const AFileName: String; ALine, ACol: Integer; const AMessage: String);
begin
  Inc(GErrorCount);
  
  // Формат вывода: файл:строка:колонка: Тип: Сообщение
  if AFileName <> '' then
    Writeln(StdErr, AFileName, ':', ALine, ':', ACol, ' - ', ErrorTypeToString(ErrType), ': ', AMessage)
  else
    Writeln(StdErr, '[Line ', ALine, ':', ACol, '] - ', ErrorTypeToString(ErrType), ': ', AMessage);
end;

procedure ReportFatal(const AMessage: String);
begin
  Inc(GErrorCount);
  Writeln(StdErr, 'FATAL ERROR: ', AMessage);
  Halt(1); // Экстренный выход из компилятора
end;

function GetErrorCount: Integer;
begin
  Result := GErrorCount;
end;

procedure ResetErrorCount;
begin
  GErrorCount := 0;
end;

end.
