unit lexer;

interface

type
  TTokenType = (
    ttEof,
    ttIdentifier,
    ttKeyword,
    ttInteger,
    ttFloat,
    ttString,
    // Операторы и знаки
    ttAssign,      // =
    ttEqual,       // ==
    ttNotEqual,    // !=
    ttLess,        // <
    ttGreater,     // >
    ttPlus,        // +
    ttMinus,       // -
    ttAnd,         // &&
    ttPipe,        // >> или разделители
    ttLBracket,    // [
    ttRBracket,    // ]
    ttLAngle,      // < (в типах)
    ttRAngle,      // > (в типах)
    ttDot,         // .
    ttComma,       // ,
    ttSemicolon,   // ;
    ttColon,       // :
    ttError
  );

  TToken = record
    TokenType: TTokenType;
    Value: string;
    Line: Integer;
    Column: Integer;
  end;

  TLexer = class
    private
      FSource: string;
      FPos: Integer;
      FLine: Integer;
      FCol: Integer;
      FLength: Integer;
      
      function Peek: Char;
      function GetChar: Char;
      function IsAlpha(C: Char): Boolean;
      function IsDigit(C: Char): Boolean;
      function IsAlphaNumeric(C: Char): Boolean;
      procedure SkipWhitespaceAndComments;
      
      function LexNumber: TToken;
      function LexIdentifierOrKeyword: TToken;
      function LexString: TToken;
    public
      constructor Create(const ASource: string);
      function NextToken: TToken;
  end;

implementation

constructor TLexer.Create(const ASource: string);
begin
  FSource := ASource;
  FPos := 1;
  FLine := 1;
  FCol := 1;
  FLength := Length(FSource);
end;

function TLexer.Peek: Char;
begin
  if FPos <= FLength then
    Result := FSource[FPos]
  else
    Result := #0;
end;

function TLexer.GetChar: Char;
begin
  if FPos <= FLength then
  begin
    Result := FSource[FPos];
    Inc(FPos);
    if Result = #10 then
    begin
      Inc(FLine);
      FCol := 1;
    end
    else
      Inc(FCol);
  end
  else
    Result := #0;
end;

function TLexer.IsAlpha(C: Char): Boolean;
begin
  Result := (C in ['a'..'z', 'A'..'Z', '_']);
end;

function TLexer.IsDigit(C: Char): Boolean;
begin
  Result := (C in ['0'..'9']);
end;

function TLexer.IsAlphaNumeric(C: Char): Boolean;
begin
  Result := IsAlpha(C) or IsDigit(C);
end;

procedure TLexer.SkipWhitespaceAndComments;
begin
  while FPos <= FLength do
  begin
    case Peek of
      #9, #10, #13, ' ':
        GetChar;
      '!': // Комментарии в CoLang начинаются с ! и идут до |
        begin
          GetChar; // пропускаем '!'
          while (FPos <= FLength) and (Peek <> '|') do
            GetChar;
          if FPos <= FLength then
            GetChar; // пропускаем '|'
        end;
      else
        Break;
    end;
  end;
end;

function TLexer.LexNumber: TToken;
var
  ValStr: string;
  IsFl: Boolean;
  StartLine, StartCol: Integer;
begin
  StartLine := FLine;
  StartCol := FCol;
  ValStr := '';
  IsFl := False;

  while IsDigit(Peek) do
    ValStr := ValStr + GetChar;

  if (Peek = '.') then
  begin
    IsFl := True;
    ValStr := ValStr + GetChar;
    while IsDigit(Peek) do
      ValStr := ValStr + GetChar;
  end;

  Result.Line := StartLine;
  Result.Column := StartCol;
  Result.Value := ValStr;
  if IsFl then
    Result.TokenType := ttFloat
  else
    Result.TokenType := ttInteger;
end;

function TLexer.LexIdentifierOrKeyword: TToken;
var
  ValStr: string;
  StartLine, StartCol: Integer;
begin
  StartLine := FLine;
  StartCol := FCol;
  ValStr := '';

  while IsAlphaNumeric(Peek) or (Peek = '.') do
    ValStr := ValStr + GetChar;

  Result.Line := StartLine;
  Result.Column := StartCol;
  Result.Value := ValStr;

  // Проверяем ключевые слова CoLang
  if (ValStr = 'func') or (ValStr = 'ustart') or (ValStr = 'uend') or
     (ValStr = 'make') or (ValStr = 'var') or (ValStr = 'let') or
     (ValStr = 'if') or (ValStr = 'elsif') or (ValStr = 'else') or
     (ValStr = 'while') or (ValStr = 'for') or (ValStr = 'break') or
     (ValStr = 'continue') or (ValStr = 'return') or (ValStr = '.use') or
     (ValStr = 'oprint') or (ValStr = 'itaker') or (ValStr = 'wait') then
    Result.TokenType := ttKeyword
  else
    Result.TokenType := ttIdentifier;
end;

function TLexer.LexString: TToken;
var
  ValStr: string;
  StartLine, StartCol: Integer;
begin
  StartLine := FLine;
  StartCol := FCol;
  GetChar; // пропуск открывающей кавычки
  ValStr := '';

  while (FPos <= FLength) and (Peek <> '"') do
  begin
    ValStr := ValStr + GetChar;
  end;

  if Peek = '"' then
    GetChar; // пропуск закрывающей кавычки

  Result.TokenType := ttString;
  Result.Value := ValStr;
  Result.Line := StartLine;
  Result.Column := StartCol;
end;

function TLexer.NextToken: TToken;
var
  StartLine, StartCol: Integer;
  C: Char;
begin
  SkipWhitespaceAndComments;

  StartLine := FLine;
  StartCol := FCol;

  if FPos > FLength then
  begin
    Result.TokenType := ttEof;
    Result.Value := '';
    Result.Line := StartLine;
    Result.Column := StartCol;
    Exit;
  end;

  C := Peek;

  if IsAlpha(C) or (C = '.') then
  begin
    // Если это просто точка без букв, обрабатываем отдельно, иначе это идентификатор/ключевик
    if (C = '.') and not IsAlpha(FSource[FPos+1]) then
    begin
      GetChar;
      Result.TokenType := ttDot;
      Result.Value := '.';
      Result.Line := StartLine;
      Result.Column := StartCol;
      Exit;
    end;
    Exit(LexIdentifierOrKeyword);
  end;

  if IsDigit(C) then
    Exit(LexNumber);

  if C = '"' then
    Exit(LexString);

  // Обработка операторов и знаков препинания
  GetChar;
  Result.Line := StartLine;
  Result.Column := StartCol;

  case C of
    '=':
      if Peek = '=' then
      begin
        GetChar;
        Result.TokenType := ttEqual;
        Result.Value := '==';
      end
      else
      begin
        Result.TokenType := ttAssign;
        Result.Value := '=';
      end;
    '!':
      if Peek = '=' then
      begin
        GetChar;
        Result.TokenType := ttNotEqual;
        Result.Value := '!=';
      end
      else
      begin
        Result.TokenType := ttError;
        Result.Value := '!';
      end;
    '<':
      begin
        Result.TokenType := ttLAngle; // или ttLess в выражениях
        Result.Value := '<';
      end;
    '>':
      begin
        if Peek = '>' then
        begin
          GetChar;
          Result.TokenType := ttPipe; // >> для возвратов
          Result.Value := '>>';
        end
        else
        begin
          Result.TokenType := ttRAngle;
          Result.Value := '>';
        end;
      end;
    '&':
      if Peek = '&' then
      begin
        GetChar;
        Result.TokenType := ttAnd;
        Result.Value := '&&';
      end
      else
      begin
        Result.TokenType := ttError;
        Result.Value := '&';
      end;
    '+': begin Result.TokenType := ttPlus; Result.Value := '+'; end;
    '-': begin Result.TokenType := ttMinus; Result.Value := '-'; end;
    '[': begin Result.TokenType := ttLBracket; Result.Value := '['; end;
    ']': begin Result.TokenType := ttRBracket; Result.Value := ']'; end;
    ',': begin Result.TokenType := ttComma; Result.Value := ','; end;
    ';': begin Result.TokenType := ttSemicolon; Result.Value := ';'; end;
    ':': begin Result.TokenType := ttColon; Result.Value := ':'; end;
  else
    begin
      Result.TokenType := ttError;
      Result.Value := C;
    end;
  end;
end;

end.
