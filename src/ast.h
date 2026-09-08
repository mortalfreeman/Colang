#ifndef CLC_AST_H
#define CLC_AST_H
#include <stddef.h>

// Базовые типы данных
typedef enum { TY_INT, TY_FLT, TY_TXT, TY_VOID } TypeKind;

// Виды выражений
typedef enum { EX_INT, EX_FLOAT, EX_STR, EX_VAR, EX_BINARY, EX_UNARY } ExprKind;

// Операторы
typedef enum { OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_EQ, OP_NE, OP_LT, OP_LE, OP_GT, OP_GE, OP_NEG } OpKind;

typedef struct Expr Expr;
struct Expr { 
    ExprKind kind; 
    int line; 
    TypeKind type; 
    union { 
        long long ival; 
        double fval; 
        char *sval; 
        char *var; 
        struct { OpKind op; Expr* a; Expr* b; } bin; 
        struct { OpKind op; Expr* a; } un; 
    }; 
};

// Виды инструкций
typedef enum { 
    ST_BLOCK, ST_VAR, ST_ASSIGN, ST_PRINT, ST_INPUT, 
    ST_IF, ST_WHILE, ST_BREAK, ST_CONTINUE, ST_RETURN, ST_WAIT_ASYNC 
} StmtKind;

typedef struct Stmt Stmt;

typedef struct {
    Stmt** v;
    size_t n, cap;
} StmtList;

typedef struct {
    char *name;
    size_t bytes;
    TypeKind type;
    Expr *init;
} VarDecl;

typedef struct IfBranch {
    Expr* cond;
    StmtList body;
    struct IfBranch* next;
} IfBranch;

struct Stmt {
    StmtKind kind;
    int line;
    union {
        struct { StmtList body; } block;
        VarDecl var;
        struct { char* name; Expr* value; } assign;
        struct { char* format; Expr** args; size_t n; int combine; } print;
        struct { char* format; char* name; } input;
        struct { IfBranch* branches; StmtList else_b; } iff;
        struct { Expr* cond; StmtList body; } wh;
        struct { Expr* value; char* target; } ret;
        struct { Expr* seconds; Stmt* action; } wait_async;
    };
};

typedef struct {
    char* name;
    StmtList body;
} Function;

typedef struct {
    char** uses;
    size_t nuses;
    Function* funcs;
    size_t nfuncs;
} Program;

// Функции создания узлов выражений
Expr* ex_int(long long);
Expr* ex_float(double);
Expr* ex_str(const char*);
Expr* ex_var(const char*);
Expr* ex_bin(OpKind, Expr*, Expr*);
Expr* ex_un(OpKind, Expr*);

// Функции освобождения памяти и управления списками инструкций
void expr_free(Expr*);
void stmtlist_add(StmtList*, Stmt*);
void stmt_free(Stmt*);
void program_free(Program*);

#endif
