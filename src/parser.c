#include "parser.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *dupstr(const char *s) {
    size_t n = strlen(s);
    char *p = malloc(n + 1);
    if (p) memcpy(p, s, n + 1);
    return p;
}

static void adv(Parser *p) {
    token_free(&p->t);
    p->t = lexer_next(&p->l);
}

static int is(Parser *p, TokenKind k) {
    return p->t.kind == k;
}

static int eat(Parser *p, TokenKind k) {
    if (is(p, k)) {
        adv(p);
        return 1;
    }
    return 0;
}

static void err(Parser *p, const char *m) {
    fprintf(stderr, "CLC parser: line %d: %s\n", p->t.line, m);
    p->errors++;
}

static char* name(Parser *p) {
    if (!is(p, TOK_IDENT)) {
        err(p, "expected identifier");
        return NULL;
    }
    char *s = malloc(p->t.len + 1);
    memcpy(s, p->t.start, p->t.len);
    s[p->t.len] = 0;
    adv(p);
    return s;
}

static Expr* expr(Parser*);
static Stmt* statement(Parser*);

static StmtList block(Parser *p) {
    StmtList b = {0};
    if (!eat(p, TOK_USTART)) {
        err(p, "expected ustart");
        return b;
    }
    while (!is(p, TOK_UEND) && !is(p, TOK_EOF)) {
        Stmt *s = statement(p);
        if (s) stmtlist_add(&b, s);
        else if (!is(p, TOK_UEND)) adv(p);
    }
    if (!eat(p, TOK_UEND)) err(p, "expected uend");
    return b;
}

static Expr* primary(Parser *p) {
    if (is(p, TOK_INT)) {
        Expr *e = ex_int(p->t.ival);
        adv(p);
        return e;
    }
    if (is(p, TOK_FLOAT)) {
        Expr *e = ex_float(p->t.fval);
        adv(p);
        return e;
    }
    if (is(p, TOK_STRING)) {
        Expr *e = ex_str(p->t.sval ? p->t.sval : "");
        adv(p);
        return e;
    }
    if (is(p, TOK_IDENT)) {
        char *s = name(p);
        Expr *e = ex_var(s);
        free(s);
        return e;
    }
    if (eat(p, TOK_LPAREN)) {
        Expr *e = expr(p);
        if (!eat(p, TOK_RPAREN)) err(p, "expected )");
        return e;
    }
    err(p, "expected expression");
    return ex_int(0);
}

static Expr* unary(Parser *p) {
    if (eat(p, TOK_MINUS)) return ex_un(OP_NEG, unary(p));
    return primary(p);
}

static Expr* mul(Parser *p) {
    Expr *e = unary(p);
    while (is(p, TOK_STAR) || is(p, TOK_SLASH)) {
        TokenKind k = p->t.kind;
        adv(p);
        e = ex_bin(k == TOK_STAR ? OP_MUL : OP_DIV, e, unary(p));
    }
    return e;
}

static Expr* add(Parser *p) {
    Expr *e = mul(p);
    while (is(p, TOK_PLUS) || is(p, TOK_MINUS)) {
        TokenKind k = p->t.kind;
        adv(p);
        e = ex_bin(k == TOK_PLUS ? OP_ADD : OP_SUB, e, mul(p));
    }
    return e;
}

static Expr* cmp(Parser *p) {
    Expr *e = add(p);
    while (is(p, TOK_EQ) || is(p, TOK_NE) || is(p, TOK_LT) || is(p, TOK_LE) || is(p, TOK_GT) || is(p, TOK_GE)) {
        TokenKind k = p->t.kind;
        adv(p);
        OpKind o = (k == TOK_EQ) ? OP_EQ : (k == TOK_NE) ? OP_NE : (k == TOK_LT) ? OP_LT : (k == TOK_LE) ? OP_LE : (k == TOK_GT) ? OP_GT : OP_GE;
        e = ex_bin(o, e, add(p));
    }
    return e;
}

static Expr* expr(Parser *p) {
    return cmp(p);
}

static Stmt* statement(Parser *p) {
    if (eat(p, TOK_SEMICOLON)) return NULL;
    
    if (eat(p, TOK_MAKE)) {
        eat(p, TOK_VAR);
        char *n = name(p);
        if (!eat(p, TOK_LBRACK)) err(p, "expected [size]");
        long long sz = 0;
        if (is(p, TOK_INT)) {
            sz = p->t.ival;
            adv(p);
        }
        if (!eat(p, TOK_RBRACK)) err(p, "expected ]");
        if (!eat(p, TOK_LT)) err(p, "expected <type>");
        TypeKind ty = TY_VOID;
        if (eat(p, TOK_INT_T)) ty = TY_INT;
        else if (eat(p, TOK_FLT_T)) ty = TY_FLT;
        else if (eat(p, TOK_TXT_T)) ty = TY_TXT;
        else err(p, "unknown type");
        if (!eat(p, TOK_GT)) err(p, "expected >");
        Stmt *s = calloc(1, sizeof*s);
        s->kind = ST_VAR;
        s->line = p->t.line;
        s->var.name = n;
        s->var.bytes = (size_t)(sz < 1 ? 1 : sz);
        s->var.type = ty;
        return s;
    }
    
    if (eat(p, TOK_LET)) {
        char *n = name(p);
        if (!eat(p, TOK_ASSIGN)) err(p, "expected =");
        Stmt *s = calloc(1, sizeof*s);
        s->kind = ST_ASSIGN;
        s->assign.name = n;
        s->assign.value = expr(p);
        return s;
    }
    
    if (eat(p, TOK_OPRINT)) {
        if (!eat(p, TOK_LPAREN)) err(p, "expected (");
        char *fmt = NULL;
        if (is(p, TOK_STRING)) {
            fmt = dupstr(p->t.sval ? p->t.sval : "");
            adv(p);
        } else err(p, "oprint requires format string");
        
        Expr **args = NULL;
        size_t n = 0, cap = 0;
        if (eat(p, TOK_COMMA)) {
            do {
                if (n == cap) {
                    cap = cap ? cap * 2 : 4;
                    args = realloc(args, cap * sizeof*args);
                }
                args[n++] = expr(p);
            } while (eat(p, TOK_COMMA));
        }
        if (!eat(p, TOK_RPAREN)) err(p, "expected )");
        int comb = eat(p, TOK_LT);
        if (comb) {
            if (!eat(p, TOK_COMBINE)) err(p, "expected combine");
            if (!eat(p, TOK_GT)) err(p, "expected >");
        }
        Stmt *s = calloc(1, sizeof*s);
        s->kind = ST_PRINT;
        s->print.format = fmt;
        s->print.args = args;
        s->print.n = n;
        s->print.combine = comb;
        return s;
    }
    
    if (eat(p, TOK_ITAKER)) {
        if (!eat(p, TOK_LPAREN)) err(p, "expected (");
        char *fmt = NULL;
        if (is(p, TOK_STRING)) {
            fmt = dupstr(p->t.sval ? p->t.sval : "");
            adv(p);
        } else err(p, "itaker requires format");
        if (!eat(p, TOK_COMMA)) err(p, "expected ,");
        char *n = name(p);
        if (!eat(p, TOK_RPAREN)) err(p, "expected )");
        Stmt *s = calloc(1, sizeof*s);
        s->kind = ST_INPUT;
        s->input.format = fmt;
        s->input.name = n;
        return s;
    }
    
    if (eat(p, TOK_IF)) {
        IfBranch *head = NULL, *tail = NULL;
        IfBranch *b = calloc(1, sizeof*b);
        b->cond = expr(p);
        b->body = block(p);
        head = tail = b;
        while (eat(p, TOK_ELSIF)) {
            b = calloc(1, sizeof*b);
            b->cond = expr(p);
            b->body = block(p);
            tail->next = b;
            tail = b;
        }
        Stmt *s = calloc(1, sizeof*s);
        s->kind = ST_IF;
        s->iff.branches = head;
        if (eat(p, TOK_ELSE)) s->iff.else_b = block(p);
        return s;
    }
    
    if (eat(p, TOK_WHILE)) {
        Stmt *s = calloc(1, sizeof*s);
        s->kind = ST_WHILE;
        s->wh.cond = expr(p);
        s->wh.body = block(p);
        return s;
    }
    
    if (eat(p, TOK_BREAK)) { Stmt *s = calloc(1, sizeof*s); s->kind = ST_BREAK; return s; }
    if (eat(p, TOK_CONTINUE)) { Stmt *s = calloc(1, sizeof*s); s->kind = ST_CONTINUE; return s; }
    
    if (eat(p, TOK_RETURN)) {
        Expr *v = NULL;
        char *target = NULL;
        if (eat(p, TOK_LPAREN)) {
            if (!eat(p, TOK_RPAREN)) while (!is(p, TOK_RPAREN) && !is(p, TOK_EOF)) adv(p);
        }
        if (eat(p, TOK_ARROW)) target = name(p);
        Stmt *s = calloc(1, sizeof*s);
        s->kind = ST_RETURN;
        s->ret.value = v;
        s->ret.target = target;
        return s;
    }
    
    if (eat(p, TOK_WAIT)) {
        if (!eat(p, TOK_LPAREN)) err(p, "expected (");
        Expr *sec = expr(p);
        if (!eat(p, TOK_RPAREN)) err(p, "expected )");
        if (!eat(p, TOK_ANDAND)) err(p, "expected &&");
        Stmt *act = statement(p);
        Stmt *s = calloc(1, sizeof*s);
        s->kind = ST_WAIT_ASYNC;
        s->wait_async.seconds = sec;
        s->wait_async.action = act;
        return s;
    }
    
    if (is(p, TOK_IDENT)) {
        char *n = name(p);
        if (!eat(p, TOK_ASSIGN)) {
            err(p, "expected =");
            free(n);
            return NULL;
        }
        Stmt *s = calloc(1, sizeof*s);
        s->kind = ST_ASSIGN;
        s->assign.name = n;
        s->assign.value = expr(p);
        return s;
    }
    
    err(p, "unexpected token");
    return NULL;
}

void parser_init(Parser *p, const char *src) {
    memset(p, 0, sizeof*p);
    lexer_init(&p->l, src);
    p->t = lexer_next(&p->l);
}

Program* parser_parse(Parser *p) {
    Program *pr = calloc(1, sizeof*pr);
    while (!is(p, TOK_EOF)) {
        if (eat(p, TOK_DOT)) {
            if (eat(p, TOK_USE)) {
                char *u = name(p);
                pr->uses = realloc(pr->uses, (pr->nuses + 1) * sizeof(char*));
                pr->uses[pr->nuses++] = u;
            } else {
                err(p, "expected use after .");
            }
            continue;
        }
        if (eat(p, TOK_FUNC)) {
            char *n = name(p);
            if (!eat(p, TOK_USTART)) err(p, "expected ustart");
            Function f = {0};
            f.name = n;
            while (!is(p, TOK_UEND) && !is(p, TOK_EOF)) {
                Stmt *s = statement(p);
                if (s) stmtlist_add(&f.body, s);
                else if (!is(p, TOK_UEND)) adv(p);
            }
            if (!eat(p, TOK_UEND)) err(p, "expected uend");
            pr->funcs = realloc(pr->funcs, (pr->nfuncs + 1) * sizeof(Function));
            pr->funcs[pr->nfuncs++] = f;
            continue;
        }
        err(p, "expected .use or func");
        adv(p);
    }
    return pr;
}

int parser_errors(Parser *p) {
    return p->errors;
}
