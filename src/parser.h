#ifndef CLC_PARSER_H
#define CLC_PARSER_H
#include "lexer.h"
#include "ast.h"

typedef struct {
    Lexer l;
    Token t;
    int errors;
} Parser;

void parser_init(Parser*, const char*);
Program* parser_parse(Parser*);
int parser_errors(Parser*);

#endif
