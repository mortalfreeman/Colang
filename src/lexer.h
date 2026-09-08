#ifndef CLC_LEXER_H
#define CLC_LEXER_H
#include <stddef.h>

// Все поддерживаемые типы токенов (лексем)
typedef enum {
    TOK_EOF, TOK_IDENT, TOK_INT, TOK_FLOAT, TOK_STRING,
    TOK_DOT, TOK_LPAREN, TOK_RPAREN, TOK_LBRACK, TOK_RBRACK,
    TOK_COMMA, TOK_COLON, TOK_SEMICOLON, TOK_PLUS, TOK_MINUS, TOK_STAR, TOK_SLASH,
    TOK_EQ, TOK_NE, TOK_LT, TOK_LE, TOK_GT, TOK_GE, TOK_ASSIGN,
    TOK_ANDAND, TOK_ARROW, TOK_BANG,
    // Ключевые слова
    TOK_USE, TOK_FUNC, TOK_USTART, TOK_UEND, TOK_MAKE, TOK_VAR,
    TOK_LET, TOK_IF, TOK_ELSIF, TOK_ELSE, TOK_WHILE, TOK_FOR, TOK_FOREACH,
    TOK_DO, TOK_BREAK, TOK_CONTINUE, TOK_RETURN, TOK_OPRINT, TOK_ITAKER,
    TOK_WAIT, TOK_SUCCESS, TOK_INT_T, TOK_FLT_T, TOK_TXT_T, TOK_COMBINE
} TokenKind;

// Структура токена
typedef struct {
    TokenKind kind;
    const char *start;
    size_t len;
    int line;
    long long ival;
    double fval;
    char *sval;
} Token;

// Структура состояния лексера
typedef struct {
    const char *src;
    size_t pos, len;
    int line;
} Lexer;

// Функции для работы с лексером
void lexer_init(Lexer *l, const char *src);
Token lexer_next(Lexer *l);
const char *token_name(TokenKind k);
void token_free(Token *t);

#endif
