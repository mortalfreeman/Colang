#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "parser.h"
#include "semantic.h"
#include "codegen_x64.h"

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
        fprintf(stderr, "Использование: %s <файл.cl> [исполняемый_файл]\n", argv[0]);
        return 1;
    }

    const char *src_path = argv[1];
    const char *out_exe = (argc > 2) ? argv[2] : "program";

    // Временные файлы для промежуточных этапов
    const char *asm_path = "_clc_temp.s";
    const char *obj_path = "_clc_temp.o";

    // Шаг 1. Чтение исходного кода .cl
    char *source = read_file(src_path);
    if (!source) return 1;

    // Шаг 2. Парсинг
    Parser parser;
    parser_init(&parser, source);
    Program *prog = parser_parse(&parser);

    if (parser_errors(&parser) > 0) {
        fprintf(stderr, "Компиляция прервана из-за синтаксических ошибок.\n");
        free(source);
        program_free(prog);
        return 1;
    }

    // Шаг 3. Семантический анализ
    if (semantic_check(prog) > 0) {
        fprintf(stderr, "Компиляция прервана из-за семантических ошибок.\n");
        free(source);
        program_free(prog);
        return 1;
    }

    // Шаг 4. Генерация ассемблера
    if (codegen_x64(prog, asm_path) != 0) {
        fprintf(stderr, "Ошибка при генерации машинного кода.\n");
        free(source);
        program_free(prog);
        return 1;
    }

    free(source);
    program_free(prog);

    // Шаг 5. Автоматический вызов NASM для компиляции ассемблера в объектный файл
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "nasm -f elf64 %s -o %s", asm_path, obj_path);
    if (system(cmd) != 0) {
        fprintf(stderr, "Ошибка: не удалось запустить NASM. Убедитесь, что он установлен.\n");
        unlink(asm_path);
        return 1;
    }

    // Шаг 6. Автоматический вызов GCC для сборки финального бинарника вместе с рантаймом
    snprintf(cmd, sizeof(cmd), "gcc %s src/runtime.c -o %s", obj_path, out_exe);
    if (system(cmd) != 0) {
        fprintf(stderr, "Ошибка при линковке через GCC.\n");
        unlink(asm_path);
        unlink(obj_path);
        return 1;
    }

    // Очистка временных файлов
    unlink(asm_path);
    unlink(obj_path);

    printf("Успешно! Исполняемый файл создан: %s\n", out_exe);
    return 0;
}
