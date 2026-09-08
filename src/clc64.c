#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "lexer.h"
#include "parser.h"
#include "semantic.h"
#include "codegen.h"

// Функция для чтения исходного файла в память
char* read_source_file(const char* filename) {
    FILE* file = fopen(filename, "rb");
    if (!file) {
        fprintf(stderr, "Ошибка: не удалось открыть файл '%s'\n", filename);
        return NULL;
    }
    fseek(file, 0, SEEK_END);
    long length = ftell(file);
    fseek(file, 0, SEEK_SET);

    char* buffer = malloc(length + 1);
    if (!buffer) {
        fprintf(stderr, "Ошибка: не удалось выделить память\n");
        fclose(file);
        return NULL;
    }
    
    if (fread(buffer, 1, length, file) != (size_t)length) {
        fprintf(stderr, "Ошибка: сбой при чтении файла\n");
        free(buffer);
        fclose(file);
        return NULL;
    }
    
    buffer[length] = '\0';
    fclose(file);
    return buffer;
}

int main(int argc, char** argv) {
    if (argc < 2) {
        fprintf(stderr, "Использование: clc64 <файл.cl> [-o <вывод.asm>]\n");
        return 1;
    }

    const char* input_file = argv[1];
    const char* output_file = "out.asm";

    // Парсинг аргументов командной строки
    for (int i = 2; i < argc; i++) {
        if (strcmp(argv[i], "-o") == 0 && i + 1 < argc) {
            output_file = argv[++i];
        } else {
            fprintf(stderr, "Неизвестный аргумент: %s\n", argv[i]);
            return 1;
        }
    }

    // 1. Чтение файла исходного кода
    char* source_code = read_source_file(input_file);
    if (!source_code) {
        return 1;
    }

    // 2. Инициализация парсера (включает лексер внутри)
    Parser parser;
    parser_init(&parser, source_code);
    Program* program = parser_parse(&parser);
    
    int errors = parser_errors(&parser);

    // 3. Семантический анализ (проверка типов, переменных)
    if (errors == 0) {
        errors = semantic_check(program);
    }

    // 4. Генерация кода
    if (errors == 0) {
        errors = codegen_x64(program, output_file);
        if (errors == 0) {
            printf("Успешно скомпилировано в: %s\n", output_file);
        }
    }

    // 5. Очистка памяти
    if (program) {
        program_free(program);
    }
    free(source_code);

    return errors ? 1 : 0;
}
