unit symtable;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

type
  TVarType = (vtInt, vtFlt, vtTxt, vtUnknown);

  // Информация о переменной
  PSymbol = ^TSymbol;
  TSymbol = record
    Name: String;
    VarType: TVarType;
    Size: Integer;      // Размер в байтах (например, 4 для int, 64 для txt)
    StackOffset: Integer; // Смещение относительно rbp в стеке
  end;

  // Узел области видимости (Scope)
  PScope = ^TScope;
  TScope = record
    Symbols: TFPList;       // Список указателей на TSymbol
    Parent: PScope;         // Родительский блок (для вложенных ustart/uend)
  end;

  // Менеджер таблицы символов
  TSymTable = class
  private
    FCurrentScope: PScope;
    FTotalStackOffset: Integer; // Автоматический расчет смещения в стеке
  public
    constructor Create;
    destructor Destroy; override;

    procedure EnterScope;
    procedure LeaveScope;

    function AddSymbol(const AName: String; AVarType: TVarType; ASize: Integer): PSymbol;
    function Lookup(const AName: String): PSymbol;
    
    property CurrentScope: PScope read FCurrentScope;
  end;

implementation

constructor TSymTable.Create;
begin
  inherited Create;
  FCurrentScope := nil;
  FTotalStackOffset := 0;
  EnterScope; // Создаем глобальный scope (для main и верхнего уровня)
end;

destructor TSymTable.Destroy;
begin
  while FCurrentScope <> nil do
    LeaveScope;
  inherited Destroy;
end;

procedure TSymTable.EnterScope;
var
  NewScope: PScope;
begin
  NewScope := New(PScope);
  NewScope^.Symbols := TFPList.Create;
  NewScope^.Parent := FCurrentScope;
  FCurrentScope := NewScope;
end;

procedure TSymTable.LeaveScope;
var
  OldScope: PScope;
  I: Integer;
  Sym: PSymbol;
begin
  if FCurrentScope = nil then Exit;

  OldScope := FCurrentScope;
  
  // Очищаем память символов текущего scope
  for I := 0 to OldScope^.Symbols.Count - 1 do
  begin
    Sym := PSymbol(OldScope^.Symbols[I]);
    Dispose(Sym);
  end;
  
  OldScope^.Symbols.Free;
  FCurrentScope := OldScope^.Parent;
  Dispose(OldScope);
end;

function TSymTable.AddSymbol(const AName: String; AVarType: TVarType; ASize: Integer): PSymbol;
var
  Sym: PSymbol;
begin
  // Проверяем, нет ли уже такой переменной в текущем скоупе
  if Lookup(AName) <> nil then
    raise Exception.Create('Semantic Error: Variable "' + AName + '" already declared in this scope.');

  New(Sym);
  Sym^.Name := AName;
  Sym^.VarType := AVarType;
  Sym^.Size := ASize;
  
  // Выравниваем стек и инкрементируем смещение (растет вниз по стеку)
  FTotalStackOffset := FTotalStackOffset + ASize;
  Sym^.StackOffset := -FTotalStackOffset;

  FCurrentScope^.Symbols.Add(Sym);
  Result := Sym;
end;

function TSymTable.Lookup(const AName: String): PSymbol;
var
  Scope: PScope;
  I: Integer;
  Sym: PSymbol;
begin
  Scope := FCurrentScope;
  while Scope <> nil do
  begin
    for I := 0 to Scope^.Symbols.Count - 1 do
    begin
      Sym := PSymbol(Scope^.Symbols[I]);
      if Sym^.Name = AName then
        Exit(Sym); // Нашли переменную в текущем или родительском скоупе
    end;
    Scope := Scope^.Parent;
  end;
  Result := nil; // Не найдено
end;

end.
