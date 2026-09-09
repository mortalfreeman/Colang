#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symtable.h"

SymTable* symtable_create(void) {
    SymTable* table = (SymTable*)malloc(sizeof(SymTable));
    table->current_scope = NULL;
    table->total_stack_offset = 0;
    symtable_enter_scope(table); // Глобальный скоуп
    return table;
}

void symtable_destroy(SymTable* table) {
    while (table->current_scope != NULL) {
        symtable_leave_scope(table);
    }
    free(table);
}

void symtable_enter_scope(SymTable* table) {
    Scope* new_scope = (Scope*)malloc(sizeof(Scope));
    new_scope->symbol_head = NULL;
    new_scope->parent = table->current_scope;
    table->current_scope = new_scope;
}

void symtable_leave_scope(SymTable* table) {
    if (table->current_scope == NULL) return;

    Scope* old_scope = table->current_scope;
    Symbol* curr = old_scope->symbol_head;
    while (curr != NULL) {
        Symbol* tmp = curr;
        curr = curr->next;
        free(tmp);
    }

    table->current_scope = old_scope->parent;
    free(old_scope);
}

Symbol* symtable_add_symbol(SymTable* table, const char* name, VarType type, int size) {
    if (symtable_lookup(table, name) != NULL) {
        fprintf(stderr, "Semantic Error: Variable '%s' already declared in this scope.\n", name);
        return NULL;
    }

    Symbol* sym = (Symbol*)malloc(sizeof(Symbol));
    strncpy(sym->name, name, 63);
    sym->var_type = type;
    sym->size = size;

    table->total_stack_offset += size;
    sym->stack_offset = -table->total_stack_offset;

    sym->next = table->current_scope->symbol_head;
    table->current_scope->symbol_head = sym;

    return sym;
}

Symbol* symtable_lookup(SymTable* table, const char* name) {
    Scope* scope = table->current_scope;
    while (scope != NULL) {
        Symbol* curr = scope->symbol_head;
        while (curr != NULL) {
            if (strcmp(curr->name, name) == 0) {
                return curr;
            }
            curr = curr->next;
        }
        scope = scope->parent;
    }
    return NULL;
}
