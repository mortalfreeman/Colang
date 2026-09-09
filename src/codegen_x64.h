#ifndef CODEGEN_X64_H
#define CODEGEN_X64_H

#include "ast.h"
#include "symtable.h"

void codegen_x64_generate(ASTNode* program, SymTable* symtable, const char* out_asm_path);

#endif
