#include "ast.h"
#include <stdlib.h>
#include <string.h>

static char* d(const char* s) {
    size_t n = strlen(s);
    char* p = malloc(n + 1);
    if (p) memcpy(p, s, n + 1);
    return p;
}

Expr* ex_int(long long x) { Expr* e = calloc(1, sizeof* e); e->kind = EX_INT; e->type = TY_INT; e->ival = x; return e; }
Expr* ex_float(double x) { Expr* e = calloc(1, sizeof* e); e->kind = EX_FLOAT; e->type = TY_FLT; e->fval = x; return e; }
Expr* ex_str(const char* s) { Expr* e = calloc(1, sizeof* e); e->kind = EX_STR; e->type = TY_TXT; e->sval = d(s); return e; }
Expr* ex_var(const char* s) { Expr* e = calloc(1, sizeof* e); e->kind = EX_VAR; e->type = TY_VOID; e->var = d(s); return e; }
Expr* ex_bin(OpKind o, Expr* a, Expr* b) { Expr* e = calloc(1, sizeof* e); e->kind = EX_BINARY; e->type = TY_INT; e->bin.op = o; e->bin.a = a; e->bin.b = b; return e; }
Expr* ex_un(OpKind o, Expr* a) { Expr* e = calloc(1, sizeof* e); e->kind = EX_UNARY; e->type = TY_INT; e->un.op = o; e->un.a = a; return e; }

void expr_free(Expr* e) {
    if (!e) return;
    switch (e->kind) {
        case EX_STR: free(e->sval); break;
        case EX_VAR: free(e->var); break;
        case EX_BINARY: expr_free(e->bin.a); expr_free(e->bin.b); break;
        case EX_UNARY: expr_free(e->un.a); break;
        default: break;
    }
    free(e);
}

void stmtlist_add(StmtList* l, Stmt* s) {
    if (l->n == l->cap) {
        l->cap = l->cap ? l->cap * 2 : 8;
        l->v = realloc(l->v, l->cap * sizeof(*l->v));
    }
    l->v[l->n++] = s;
}

void stmt_free(Stmt* s) {
    if (!s) return;
    switch (s->kind) {
        case ST_BLOCK: 
            for (size_t i = 0; i < s->block.body.n; i++) stmt_free(s->block.body.v[i]); 
            free(s->block.body.v); 
            break;
        case ST_VAR: 
            free(s->var.name); 
            expr_free(s->var.init); 
            break;
        case ST_ASSIGN: 
            free(s->assign.name); 
            expr_free(s->assign.value); 
            break;
        case ST_PRINT: 
            free(s->print.format); 
            for (size_t i = 0; i < s->print.n; i++) expr_free(s->print.args[i]); 
            free(s->print.args); 
            break;
        case ST_INPUT: 
            free(s->input.format); 
            free(s->input.name); 
            break;
        case ST_IF: 
            for (IfBranch* b = s->iff.branches; b;) {
                IfBranch* n = b->next;
                for (size_t i = 0; i < b->body.n; i++) stmt_free(b->body.v[i]);
                free(b->body.v);
                expr_free(b->cond);
                free(b);
                b = n;
            }
            for (size_t i = 0; i < s->iff.else_b.n; i++) stmt_free(s->iff.else_b.v[i]);
            free(s->iff.else_b.v);
            break;
        case ST_WHILE: 
            expr_free(s->wh.cond);
            for (size_t i = 0; i < s->wh.body.n; i++) stmt_free(s->wh.body.v[i]);
            free(s->wh.body.v);
            break;
        case ST_RETURN: 
            expr_free(s->ret.value); 
            free(s->ret.target); 
            break;
        case ST_WAIT_ASYNC: 
            expr_free(s->wait_async.seconds); 
            stmt_free(s->wait_async.action); 
            break;
        default: break;
    }
    free(s);
}

void program_free(Program* p) {
    for (size_t i = 0; i < p->nuses; i++) free(p->uses[i]);
    free(p->uses);
    for (size_t i = 0; i < p->nfuncs; i++) {
        free(p->funcs[i].name);
        for (size_t j = 0; j < p->funcs[i].body.n; j++) stmt_free(p->funcs[i].body.v[j]);
        free(p->funcs[i].body.v);
    }
    free(p->funcs);
}
