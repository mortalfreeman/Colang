#include "semantic.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

static char *dupstr(const char *s) {
    size_t n = strlen(s);
    char *p = malloc(n + 1);
    if (p) memcpy(p, s, n + 1);
    return p;
}

typedef struct Sym {
    char *n;
    TypeKind t;
    size_t bytes;
    struct Sym *next;
} Sym;

static Sym* find(Sym *s, const char *n) {
    for (; s; s = s->next) {
        if (!strcmp(s->n, n)) return s;
    }
    return NULL;
}

static int exprc(Expr *e, Sym *s) {
    if (!e) return 0;
    if (e->kind == EX_VAR) {
        Sym *x = find(s, e->var);
        if (!x) {
            fprintf(stderr, "CLC semantic: unknown variable '%s'\n", e->var);
            return 1;
        }
        e->type = x->t;
        return 0;
    }
    if (e->kind == EX_BINARY) {
        int a = exprc(e->bin.a, s), b = exprc(e->bin.b, s);
        if (a || b) return 1;
        if (e->bin.a->type == TY_TXT || e->bin.b->type == TY_TXT) {
            fprintf(stderr, "CLC semantic: arithmetic/comparison on txt is not implemented\n");
            return 1;
        }
    }
    if (e->kind == EX_UNARY) return exprc(e->un.a, s);
    return 0;
}

static int stmts(StmtList *b, Sym **sp) {
    int er = 0;
    for (size_t i = 0; i < b->n; i++) {
        Stmt *x = b->v[i];
        switch (x->kind) {
            case ST_VAR:
                if (find(*sp, x->var.name)) {
                    fprintf(stderr, "CLC semantic: duplicate variable '%s'\n", x->var.name);
                    er++;
                } else {
                    Sym *z = calloc(1, sizeof*z);
                    z->n = dupstr(x->var.name);
                    z->t = x->var.type;
                    z->bytes = x->var.bytes;
                    z->next = *sp;
                    *sp = z;
                }
                break;
            case ST_ASSIGN: {
                Sym *z = find(*sp, x->assign.name);
                if (!z) {
                    fprintf(stderr, "CLC semantic: unknown variable '%s'\n", x->assign.name);
                    er++;
                }
                er += exprc(x->assign.value, *sp);
                if (z && x->assign.value && x->assign.value->type != TY_VOID && z->t != x->assign.value->type && !(z->t == TY_INT && x->assign.value->type == TY_INT)) {
                    fprintf(stderr, "CLC semantic: type mismatch for '%s'\n", x->assign.name);
                    er++;
                }
                break;
            }
            case ST_PRINT:
                for (size_t j = 0; j < x->print.n; j++) er += exprc(x->print.args[j], *sp);
                break;
            case ST_INPUT:
                if (!find(*sp, x->input.name)) {
                    fprintf(stderr, "CLC semantic: unknown input variable '%s'\n", x->input.name);
                    er++;
                }
                break;
            case ST_IF:
                for (IfBranch *q = x->iff.branches; q; q = q->next) {
                    er += exprc(q->cond, *sp);
                    er += stmts(&q->body, sp);
                }
                er += stmts(&x->iff.else_b, sp);
                break;
            case ST_WHILE:
                er += exprc(x->wh.cond, *sp);
                er += stmts(&x->wh.body, sp);
                break;
            case ST_RETURN:
                if (x->ret.value) er += exprc(x->ret.value, *sp);
                break;
            case ST_WAIT_ASYNC:
                er += exprc(x->wait_async.seconds, *sp);
                if (x->wait_async.action) {
                    StmtList one = {&x->wait_async.action, 1, 1};
                    er += stmts(&one, sp);
                }
                break;
            default:
                break;
        }
    }
    return er;
}

int semantic_check(Program *p) {
    int er = 0;
    Function *mainf = NULL;
    for (size_t i = 0; i < p->nfuncs; i++) {
        if (!strcmp(p->funcs[i].name, "main")) mainf = &p->funcs[i];
    }
    if (!mainf) {
        fprintf(stderr, "CLC semantic: func main is required\n");
        return 1;
    }
    for (size_t i = 0; i < p->nfuncs; i++) {
        Sym *s = NULL;
        er += stmts(&p->funcs[i].body, &s);
        while (s) {
            Sym *n = s->next;
            free(s->n);
            free(s);
            s = n;
        }
    }
    return er;
}
