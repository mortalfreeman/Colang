unit runtime;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

// Экспортируемые процедуры для обращения из NASM (соглашение cdecl)
procedure colang_print_int(Val: LongInt); cdecl; export;
procedure colang_print_str(StrPtr: PChar); cdecl; export;
procedure colang_input_int(VarPtr: PLongInt); cdecl; export;

implementation

procedure colang_print_int(Val: LongInt); cdecl;
begin
  Write(Val);
  Flush(Output);
end;

procedure colang_print_str(StrPtr: PChar); cdecl;
begin
  if StrPtr <> nil then
  begin
    Write(StrPtr);
    Flush(Output);
  end;
end;

procedure colang_input_int(VarPtr: PLongInt); cdecl;
var
  InputVal: LongInt;
begin
  if VarPtr <> nil then
  begin
    Read(InputVal);
    VarPtr^ := InputVal;
  end;
end;

end.
