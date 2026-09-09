#ifndef SYMTABLE_H
#ifndef SYMTABLE_H
#define SYMTABLE_H

typedef enum {
    VT_INT,
    VT_FLT,
    VT_TXT,
    VT_UNKNOWN
} VarType;

typedef struct Symbol {
    char name[64];
    VarType var_type;
    int size;
    int stack_offset;
    struct Symbol* next;
} Symbol;

typedef struct Scope {
    Symbol* symbol_head;
    struct Scope* parent;
} Scope;

typedef struct {
    Scope* current_scope;
    int total_stack_offset;
} SymTable;

SymTable* symtable_create(void);
void symtable_destroy(SymTable* table);
void symtable_enter_scope(SymTable* table);
void symtable_leave_scope(SymTable* table);
Symbol* symtable_add_symbol(SymTable* table, const char* name, VarType type, int size);
Symbol* symtable_lookup(SymTable* table, const char* name);

#endif
