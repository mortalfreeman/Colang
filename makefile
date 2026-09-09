# ==============================================================================
# CoLang Compiler Dual-System Makefile (v0.2)
# Поддержка версий clc_fpc (srcpas/) и clc_c (src/)
# ==============================================================================

# Компиляторы хоста
FPC      ?= fpc
CC       ?= gcc
NASM     ?= nasm
RM       ?= rm -f

# Флаги компиляции
FPCFLAGS := -O2 -Mobjfpc -Sh -Isrcpas
CFLAGS   := -O2 -Wall -I src
NASMFLAGS:= -f elf64

# Выходные бинарники компилятора
BIN_FPC  := clc_fpc
BIN_C    := clc_c

# Модули исходников
SRCS_PAS := $(wildcard srcpas/*.pas)
SRCS_C   := $(wildcard src/*.c)

# По умолчанию собираем версию на Free Pascal
.PHONY: all fpc c clean test run_example

all: fpc

# ------------------------------------------------------------------------------
# Сборка Free Pascal версии (srcpas/)
# ------------------------------------------------------------------------------
fpc: $(BIN_FPC)

$(BIN_FPC): $(SRCS_PAS)
	@echo "[BUILD] Компиляция clc_fpc на Free Pascal..."
	$(FPC) $(FPCFLAGS) -o$(BIN_FPC) srcpas/main.pas

# ------------------------------------------------------------------------------
# Сборка C версии (src/)
# ------------------------------------------------------------------------------
c: $(BIN_C)

$(BIN_C): $(SRCS_C)
	@echo "[BUILD] Компиляция clc_c на C..."
	$(CC) $(CFLAGS) $(SRCS_C) -o $(BIN_C)

# ------------------------------------------------------------------------------
# Полный тестовый пайплайн: CoLang (.cl) -> NASM (.asm) -> Object (.o) -> Binary
# ------------------------------------------------------------------------------
run_example: $(BIN_FPC)
	@echo "[CLC] Трансляция examples/hello.cl в output.asm..."
	./$(BIN_FPC) examples/hello.cl -o output.asm -v
	@echo "[NASM] Ассемблирование output.asm..."
	$(NASM) $(NASMFLAGS) output.asm -o output.o
	@echo "[LINK] Компоновка исполняемого файла hello_app..."
	$(CC) -no-pie output.o -o hello_app
	@echo "[RUN] Запуск скомпилированной программы CoLang:"
	@./hello_app

# ------------------------------------------------------------------------------
# Очистка артефактов сборки
# ------------------------------------------------------------------------------
clean:
	@echo "[CLEAN] Удаление временных файлов и бинарников..."
	$(RM) $(BIN_FPC) $(BIN_C)
	$(RM) srcpas/*.o srcpas/*.ppu src/*.o
	$(RM) output.asm output.o hello_app
