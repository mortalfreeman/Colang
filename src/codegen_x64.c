#include "codegen_x64.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *dupstr(const char *s) {
    size_t n = strlen(s);
    char *p = malloc(n + 1);
    if (p) memcpy(p, s, n + 1);
    return p;
}

typedef struct V {
    char *n;
    TypeKind t;
    size_t off;
    size_t bytes;
    struct V *next;
} V;

typedef struct S {
    char *text;
    int id;
    struct S *next;
} S;

typedef struct {
    FILE *f;
    int label;
    int loop_depth;
    char *breaks[64];
    char *conts[64];
    V *vars;
    S *strings;
    size_t frame;
} CG;

static void q(CG *c, const char *s) {
    fprintf(c->f, "%s\n", s);
}

static char* lbl(CG *c, const char *p) {
    char *b = malloc(64);
    snprintf(b, 64, ".L%s_%d", p, c->label++);
    return b;
}

static V* vf(V *v, const char *n) {
    for (; v; v = v->next) {
        if (!strcmp(v->n, n)) return v;
    }
    return NULL;
}

static int sid(CG *c, const char *s) {
    for (S *x = c->strings; x; x = x->next) {
        if (!strcmp(x->text, s)) return x->id;
    }
    S *x = calloc(1, sizeof*x);
    x->text = dupstr(s);
    x->id = c->label++;
    x->next = c->strings;
    c->strings = x;
    return x->id;
}

static void vars(CG *c, StmtList *b) {
    for (size_t i = 0; i < b->n; i++) {
        Stmt *s = b->v[i];
        if (s->kind == ST_VAR) {
            V *v = calloc(1, sizeof*v);
            v->n = dupstr(s->var.name);
            v->t = s->var.type;
            v->bytes = s->var.bytes;
            v->off = c->frame + 8;
            c->frame += ((v->bytes + 7) / 8) * 8;
            v->next = c->vars;
            c->vars = v;
        } else if (s->kind == ST_IF) {
            for (IfBranch *x = s->iff.branches; x; x = x->next) {
                vars(c, &x->body);
            }
            vars(c, &s->iff.else_b);
        } else if (s->kind == ST_WHILE) {
            vars(c, &s->wh.body);
        }
    }
}

static int emit_expr(CG *c, Expr *e) {
    if (!e) return 0;
    if (e->kind == EX_FLOAT) {
        fprintf(stderr, "CLC x64: float code generation is not yet enabled\n");
        return -1;
    }
    if (e->kind == EX_INT) {
        fprintf(c->f, " mov rax, %lld\n push rax\n", e->ival);
        return 0;
    }
    if (e->kind == EX_VAR) {
        V *v = vf(c->vars, e->var);
        if (!v) return -1;
        if (v->t == TY_TXT) {
            fprintf(c->f, " lea rax, [rbp-%zu]\n push rax\n", v->off);
        } else {
            fprintf(c->f, " mov rax, QWORD PTR [rbp-%zu]\n push rax\n", v->off);
        }
        return 0;
    }
    if (e->kind == EX_STR) {
        int id = sid(c, e->sval);
        fprintf(c->f, " lea rax, [rel .LC_str_%d]\n push rax\n", id);
        return 0;
    }
    if (e->kind == EX_UNARY) {
        if (emit_expr(c, e->un.a)) return -1;
        q(c, " pop rax");
        if (e->un.op == OP_NEG) q(c, " neg rax");
        q(c, " push rax");
        return 0;
    }
    if (e->kind == EX_BINARY) {
        if (emit_expr(c, e->bin.a) || emit_expr(c, e->bin.b)) return -1;
        q(c, " pop rcx");
        q(c, " pop rax");
        switch (e->bin.op) {
            case OP_ADD: q(c, " add rax, rcx"); break;
            case OP_SUB: q(c, " sub rax, rcx"); break;
            case OP_MUL: q(c, " imul rax, rcx"); break;
            case OP_DIV: q(c, " cqo"); q(c, " idiv rcx"); break;
            default:
                q(c, " cmp rax, rcx");
                switch (e->bin.op) {
                    case OP_EQ: q(c, " sete al"); break;
                    case OP_NE: q(c, " setne al"); break;
                    case OP_LT: q(c, " setl al"); break;
                    case OP_LE: q(c, " setle al"); break;
                    case OP_GT: q(c, " setg al"); break;
                    case OP_GE: q(c, " setge al"); break;
                    default: break;
                }
                q(c, " movzx rax, al");
        }
        q(c, " push rax");
        return 0;
    }
    return -1;
}

static int emit_stmt(CG *c, Stmt *s) {
    switch (s->kind) {
        case ST_VAR: {
            V *v = vf(c->vars, s->var.name);
            if (s->var.type == TY_TXT) {
                fprintf(c->f, " lea rdi,[rbp-%zu]\n mov rsi,%zu\n call __clc_zero_text\n", v->off, v->bytes);
            } else {
                fprintf(c->f, " xor eax,eax\n mov QWORD PTR [rbp-%zu],rax\n", v->off);
            }
            return 0;
        }
        case ST_ASSIGN: {
            V *v = vf(c->vars, s->assign.name);
            if (emit_expr(c, s->assign.value)) return -1;
            q(c, " pop rax");
            if (v->t == TY_TXT) {
                q(c, " mov rsi,rax");
                fprintf(c->f, " lea rdi,[rbp-%zu]\n call __clc_strcpy\n", v->off);
            } else {
                fprintf(c->f, " mov QWORD PTR [rbp-%zu],rax\n", v->off);
            }
            return 0;
        }
        case ST_PRINT: {
            int id = sid(c, s->print.format);
            if (s->print.n == 0) {
                fprintf(c->f, " lea rdi,[rel .LC_str_%d]\n call __clc_print_raw\n", id);
                return 0;
            }
            for (size_t i = 0; i < s->print.n; i++) {
                if (emit_expr(c, s->print.args[i])) return -1;
                q(c, " pop rsi");
                if (s->print.args[i]->type == TY_TXT) {
                    fprintf(c->f, " lea rdi,[rel .LC_str_%d]\n call __clc_print_fmt_txt\n", id);
                } else {
                    fprintf(c->f, " lea rdi,[rel .LC_str_%d]\n call __clc_print_fmt_int\n", id);
                }
            }
            return 0;
        }
        case ST_INPUT: {
            V *v = vf(c->vars, s->input.name);
            if (!v || v->t != TY_TXT) {
                fprintf(stderr, "CLC x64: itaker currently requires a txt destination\n");
                return -1;
            }
            fprintf(c->f, " lea rdi,[rbp-%zu]\n mov rsi,%zu\n call __clc_input_text\n", v->off, v->bytes);
            return 0;
        }
        case ST_IF: {
            char *end = lbl(c, "ifend");
            for (IfBranch *b = s->iff.branches; b; b = b->next) {
                char *nxt = lbl(c, "ifnext");
                if (emit_expr(c, b->cond)) return -1;
                q(c, " pop rax");
                fprintf(c->f, " test rax,rax\n jz %s\n", nxt);
                for (size_t i = 0; i < b->body.n; i++) {
                    if (emit_stmt(c, b->body.v[i])) return -1;
                }
                fprintf(c->f, " jmp %s\n%s:\n", end, nxt);
                free(nxt);
            }
            for (size_t i = 0; i < s->iff.else_b.n; i++) {
                if (emit_stmt(c, s->iff.else_b.v[i])) return -1;
            }
            fprintf(c->f, "%s:\n", end);
            free(end);
            return 0;
        }
        case ST_WHILE: {
            char *beg = lbl(c, "while");
            char *end = lbl(c, "while_end");
            fprintf(c->f, "%s:\n", beg);
            if (emit_expr(c, s->wh.cond)) return -1;
            q(c, " pop rax");
            fprintf(c->f, " test rax,rax\n jz %s\n", end);
            c->breaks[c->loop_depth] = end;
            c->conts[c->loop_depth] = beg;
            c->loop_depth++;
            for (size_t i = 0; i < s->wh.body.n; i++) {
                if (emit_stmt(c, s->wh.body.v[i])) return -1;
            }
            c->loop_depth--;
            fprintf(c->f, " jmp %s\n%s:\n", beg, end);
            free(beg);
            free(end);
            return 0;
        }
        case ST_BREAK:
            if (c->loop_depth) fprintf(c->f, " jmp %s\n", c->breaks[c->loop_depth - 1]);
            return 0;
        case ST_CONTINUE:
            if (c->loop_depth) fprintf(c->f, " jmp %s\n", c->conts[c->loop_depth - 1]);
            return 0;
        case ST_RETURN:
            q(c, " xor eax,eax");
            q(c, " leave");
            q(c, " ret");
            return 0;
        case ST_WAIT_ASYNC:
            if (emit_expr(c, s->wait_async.seconds)) return -1;
            q(c, " pop rdi\n call __clc_wait_async");
            return s->wait_async.action ? emit_stmt(c, s->wait_async.action) : 0;
        default:
            return 0;
    }
}

int codegen_x64(Program *p, const char *out) {
    CG c = {0};
    c.f = fopen(out, "w");
    if (!c.f) {
        perror(out);
        return 1;
    }
    Function *mainf = NULL;
    for (size_t i = 0; i < p->nfuncs; i++) {
        if (!strcmp(p->funcs[i].name, "main")) mainf = &p->funcs[i];
    }
    if (!mainf) {
        fclose(c.f);
        return 1;
    }
    vars(&c, &mainf->body);
    size_t frame = ((c.frame + 15) / 16) * 16;
    if (frame < 16) frame = 16;
    q(&c, "default rel\nsection .text\nglobal main\nextern __clc_print_raw\nextern __clc_print_fmt_int\nextern __clc_print_fmt_txt\nextern __clc_input_text\nextern __clc_zero_text\nextern __clc_strcpy\nextern __clc_wait_async\nmain:");
    fprintf(c.f, " push rbp\n mov rbp,rsp\n sub rsp,%zu\n", frame);
    for (size_t i = 0; i < mainf->body.n; i++) {
        if (emit_stmt(&c, mainf->body.v[i])) {
            fclose(c.f);
            return 1;
        }
    }
    q(&c, " mov eax,0\n leave\n ret\nsection .rodata");
    for (S *x = c.strings; x; x = x->next) {
        fprintf(c.f, ".LC_str_%d: db ", x->id);
        for (size_t i = 0; i < strlen(x->text); i++) {
            unsigned char ch = (unsigned char)x->text[i];
            fprintf(c.f, "%u%s", ch, (i + 1 < strlen(x->text)) ? "," : "");
        }
        fprintf(c.f, ",0\n");
    }
    fclose(c.f);
    return 0;
}
