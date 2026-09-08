#include "lexer.h"
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// Вспомогательная функция проверки ключевых слов
static int kw(const char *s, size_t n, TokenKind *k) {
    #define K(x,y) if(n==sizeof(x)-1 && memcmp(s,x,n)==0){*k=y;return 1;}
    K("use",TOK_USE) K("func",TOK_FUNC) K("ustart",TOK_USTART) K("uend",TOK_UEND)
    K("make",TOK_MAKE) K("var",TOK_VAR) K("let",TOK_LET) K("if",TOK_IF) K("elsif",TOK_ELSIF)
    K("else",TOK_ELSE) K("while",TOK_WHILE) K("for",TOK_FOR) K("foreach",TOK_FOREACH) K("do",TOK_DO)
    K("break",TOK_BREAK) K("continue",TOK_CONTINUE) K("return",TOK_RETURN) K("oprint",TOK_OPRINT)
    K("itaker",TOK_ITAKER) K("wait",TOK_WAIT) K("success",TOK_SUCCESS) K("int",TOK_INT_T)
    K("flt",TOK_FLT_T) K("txt",TOK_TXT_T) K("combine",TOK_COMBINE)
    #undef K
    return 0;
}

void lexer_init(Lexer *l, const char *src) {
    memset(l, 0, sizeof(*l));
    l->src = src;
    l->len = strlen(src);
    l->line = 1;
}

static Token t(TokenKind k, const char *s, size_t n, int line) {
    Token x = {0};
    x.kind = k;
    x.start = s;
    x.len = n;
    x.line = line;
    return x;
}

static char *dup_range(const char *s, size_t n) {
    char *p = malloc(n + 1);
    if (!p) return NULL;
    memcpy(p, s, n);
    p[n] = 0;
    return p;
}

void token_free(Token *tk) {
    if (tk->kind == TOK_STRING) free(tk->sval);
    tk->sval = NULL;
}

Token lexer_next(Lexer *l) {
    // Пропуск пробелов и комментариев
    while (l->pos < l->len) {
        char c = l->src[l->pos];
        if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
            if (c == '\n') l->line++;
            l->pos++;
            continue;
        }
        // Комментарии начинаются с '!' (но не '!=') и идут до '|'
        if (c == '!' && !(l->pos + 1 < l->len && l->src[l->pos + 1] == '=')) {
            l->pos++;
            while (l->pos < l->len && l->src[l->pos] != '|') {
                if (l->src[l->pos] == '\n') l->line++;
                l->pos++;
            }
            if (l->pos < l->len) l->pos++; // Пропускаем '|'
            continue;
        }
        break;
    }

    if (l->pos >= l->len) return t(TOK_EOF, l->src + l->len, 0, l->line);
    
    size_t p = l->pos;
    int line = l->line;
    char c = l->src[l->pos++];

    // Идентификаторы и ключевые слова
    if (isalpha((unsigned char)c) || c == '_') {
        while (l->pos < l->len && (isalnum((unsigned char)l->src[l->pos]) || l->src[l->pos] == '_')) {
            l->pos++;
        }
        Token x = t(TOK_IDENT, l->src + p, l->pos - p, line);
        kw(x.start, x.len, &x.kind);
        return x;
    }

    // Числа (целые и вещественные)
    if (isdigit((unsigned char)c)) {
        int dot = 0;
        while (l->pos < l->len && (isdigit((unsigned char)l->src[l->pos]) || (!dot && l->src[l->pos] == '.'))) {
            if (l->src[l->pos] == '.') dot = 1;
            l->pos++;
        }
        Token x = t(dot ? TOK_FLOAT : TOK_INT, l->src + p, l->pos - p, line);
        char *b = dup_range(x.start, x.len);
        if (dot) x.fval = strtod(b, NULL);
        else x.ival = strtoll(b, NULL, 10);
        free(b);
        return x;
    }

    // Строки
    if (c == '"') {
        size_t st = l->pos;
        char *buf = NULL;
        size_t cap = 0, n = 0;
        while (l->pos < l->len) {
            char q = l->src[l->pos++];
            if (q == '"') break;
            if (q == '\n') l->line++;
            if (q == '\\' && l->pos < l->len) {
                char e = l->src[l->pos++];
                char z = e == 'n' ? '\n' : e == 't' ? '\t' : e == 'r' ? '\r' : e;
                if (n + 1 >= cap) { cap = cap ? cap * 2 : 32; buf = realloc(buf, cap); }
                buf[n++] = z;
            } else {
                if (n + 1 >= cap) { cap = cap ? cap * 2 : 32; buf = realloc(buf, cap); }
                buf[n++] = q;
            }
        }
        if (!buf) buf = malloc(1);
        buf[n] = 0;
        Token x = t(TOK_STRING, l->src + st, l->pos - st, line);
        x.sval = buf;
        return x;
    }

    // Составные операторы
    if (c == '=' && l->pos < l->len && l->src[l->pos] == '=') { l->pos++; return t(TOK_EQ, l->src + p, 2, line); }
    if (c == '!' && l->pos < l->len && l->src[l->pos] == '=') { l->pos++; return t(TOK_NE, l->src + p, 2, line); }
    if (c == '<' && l->pos < l->len && l->src[l->pos] == '=') { l->pos++; return t(TOK_LE, l->src + p, 2, line); }
    if (c == '>' && l->pos < l->len && l->src[l->pos] == '=') { l->pos++; return t(TOK_GE, l->src + p, 2, line); }
    if (c == '&' && l->pos < l->len && l->src[l->pos] == '&') { l->pos++; return t(TOK_ANDAND, l->src + p, 2, line); }
    if (c == '>' && l->pos < l->len && l->src[l->pos] == '>') { l->pos++; return t(TOK_ARROW, l->src + p, 2, line); }

    // Одиночные символы
    #define ONE(ch, kd) if(c == ch) return t(kd, l->src + p, 1, line)
    ONE('.', TOK_DOT); ONE('(', TOK_LPAREN); ONE(')', TOK_RPAREN);
    ONE('[', TOK_LBRACK); ONE(']', TOK_RBRACK); ONE(',', TOK_COMMA);
    ONE(':', TOK_COLON); ONE(';', TOK_SEMICOLON); ONE('+', TOK_PLUS);
    ONE('-', TOK_MINUS); ONE('*', TOK_STAR); ONE('/', TOK_SLASH);
    ONE('=', TOK_ASSIGN); ONE('<', TOK_LT); ONE('>', TOK_GT); ONE('!', TOK_BANG);
    #undef ONE

    return t(TOK_EOF, l->src + p, 1, line);
}

const char *token_name(TokenKind k) {
    static const char *n[] = {
        "eof", "identifier", "integer", "float", "string", ".", "(", ")", "[", "]",
        ",", ":", "+", "-", "*", "/", "==", "!=", "<", "<=", ">", ">=", "=", "&&", "=>", "!"
    };
    if (k < TOK_USE) return n[k];
    return "keyword";
}
