CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -O2 -Isrc

# Исходные файлы компилятора
SRC = src/main.c src/lexer.c src/ast.c src/parser.c src/semantic.c src/codegen_x64.c
OBJ = $(SRC:.c=.o)
TARGET = clc

# Основная цель
all: $(TARGET) runtime.o

$(TARGET): $(OBJ)
	$(CC) $(CFLAGS) $(OBJ) -o $(TARGET)

# Компиляция рантайма в объектный файл
runtime.o: src/runtime.c
	$(CC) $(CFLAGS) -c src/runtime.c -o runtime.o

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f src/*.o runtime.o $(TARGET) output.s
