#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "lexer.h"
#include "ast.h"
#include "parser.h"
#include "symtable.h"
#include "errors.h"
#include "semantic.h"
#include "codegen_x64.h"

static void print_help(void) {
    printf("CoLang Compiler (clc_c) v0.2 [C Edition]\n");
    printf("Usage: clc_c <input_file.cl> [options]\n\n");
    printf("Options:\n");
    printf("  -o <file>   Specify output assembly file (default: output.asm)\n");
    printf("  -v          Enable verbose compilation output\n");
    printf("  -h, --help  Display this help message\n");
    exit(0);
}

int main(int argc, char** argv) {
    const char* input_file = NULL;
    const char* output_file = "output.asm";
    int verbose = 0;

    if (argc < 2) {
        fprintf(stderr, "Error: No input file specified.\n");
        print_help();
    }

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            print_help();
        } else if (strcmp(argv[i], "-v") == 0) {
            verbose = 1;
        } else if (strcmp(argv[i], "-o") == 0) {
            if (i + 1 < argc) {
                output_file = argv[++i];
            } else {
                report_fatal("Option -o requires an output filename argument.");
            }
        } else if (argv[i][0] == '-') {
            fprintf(stderr, "Unknown option: %s\n", argv[i]);
            exit(1);
        } else {
            input_file = argv[i];
        }
    }

    if (!input_file) {
        report_fatal("No input CoLang file (.cl) provided.");
    }

    if (verbose) {
        printf("[CLC_C] Input file:  %s\n", input_file);
        printf("[CLC_C] Output file: %s\n", output_file);
        printf("[CLC_C] Stage 1: Lexical analysis...\n");
    }

    Lexer* lexer = lexer_create(input_file);
    
    if (verbose) printf("[CLC_C] Stage 2: Parsing & AST construction...\n");
    Parser* parser = parser_create(lexer);
    ASTNode* ast = parser_parse_program(parser);

    if (get_error_count() > 0) report_fatal("Compilation halted due to syntax errors.");

    if (verbose) printf("[CLC_C] Stage 3: Semantic analysis...\n");
    SemanticAnalyzer* sem = semantic_create(input_file);
    semantic_analyze_program(sem, ast);

    if (get_error_count() > 0) report_fatal("Compilation halted due to semantic errors.");

    if (verbose) printf("[CLC_C] Stage 4: Code generation (NASM x86_64)...\n");
    codegen_x64_generate(ast, sem->symtable, output_file);

    if (verbose) {
        printf("[CLC_C] Compilation successful! Saved to %s\n", output_file);
    } else {
        printf("Assembly code successfully written to %s\n", output_file);
    }

    return 0;
}
