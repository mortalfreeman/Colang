unit runtime;

interface

{$mode objfpc}{$H+}

{ Экспортируемые функции для связи с сгенерированным ассемблерным кодом }
procedure colang_print_int(val: Int64); cdecl; export;
procedure colang_print_str(p: PChar); cdecl; export;
function colang_input_int: Int64; cdecl; export;

implementation

uses
  SysUtils;

procedure colang_print_int(val: Int64); cdecl; export;
begin
  Writeln(val);
end;

procedure colang_print_str(p: PChar); cdecl; export;
begin
  if Assigned(p) then
    Write(StrPas(p))
  else
    Write('(null)');
end;

function colang_input_int: Int64; cdecl; export;
var
  InputStr: string;
  Code: Integer;
  Val: Int64;
begin
  Readln(InputStr);
  Val(InputStr, Val, Code);
  if Code = 0 then
    Result := Val
  else
    Result := 0;
end;

end.
