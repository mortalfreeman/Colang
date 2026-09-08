#include <stdio.h>
#include <stdlib.h>
#include "parser.h"
#include "semantic.h"
#include "codegen_x64.h"

// Вспомогательная функция для чтения исходного файла в память
static char* read_file(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) {
        perror(path);
        return NULL;
    }
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    
    char *buf = malloc(len + 1);
    if (!buf) {
        fclose(f);
        return NULL;
    }
    
    fread(buf, 1, len, f);
    buf[len] = 0;
    fclose(f);
    return buf;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "Использование: %s <исходный_файл.co> [выходной_файл.s]\n", argv[0]);
        return 1;
    }

    const char *src_path = argv[1];
    const char *out_path = (argc > 2) ? argv[2] : "output.s";

    // Шаг 1. Чтение исходного кода
    char *source = read_file(src_path);
    if (!source) return 1;

    // Шаг 2. Лексический и синтаксический анализ (Парсер -> AST)
    Parser parser;
    parser_init(&parser, source);
    Program *prog = parser_parse(&parser);

    if (parser_errors(&parser) > 0) {
        fprintf(stderr, "Компиляция прервана из-за синтаксических ошибок.\n");
        free(source);
        program_free(prog);
        return 1;
    }

    // Шаг 3. Семантический анализ (проверка типов и переменных)
    if (semantic_check(prog) > 0) {
        fprintf(stderr, "Компиляция прервана из-за семантических ошибок.\n");
        free(source);
        program_free(prog);
        return 1;
    }

    // Шаг 4. Генерация кода на ассемблере x86_64 (NASM)
    if (codegen_x64(prog, out_path) != 0) {
        fprintf(stderr, "Ошибка при генерации машинного кода.\n");
        free(source);
        program_free(prog);
        return 1;
    }

    printf("Успешно! Код скомпилирован в файл: %s\n", out_path);

    // Очистка памяти
    free(source);
    program_free(prog);
    return 0;
}
