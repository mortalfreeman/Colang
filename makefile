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
CFLAGS   := -O2 -Wall -Wextra -Isrc
NASMFLAGS:= -f elf64

# Выходные исполняемые файлы компилятора
BIN_FPC  := clc_fpc
BIN_C    := clc_c

# Списки файлов исходного кода
SRCS_PAS := $(wildcard srcpas/*.pas)
SRCS_C   := $(wildcard src/*.c)

# ------------------------------------------------------------------------------
# Главные цели (Targets)
# ------------------------------------------------------------------------------
.PHONY: all fpc c test_fpc test_c test gitignore clean help

# По умолчанию собираем обе версии компилятора
all: fpc c

# ------------------------------------------------------------------------------
# 1. Сборка Free Pascal версии (srcpas/)
# ------------------------------------------------------------------------------
fpc: $(BIN_FPC)

$(BIN_FPC): $(SRCS_PAS)
	@echo "==> [BUILD] Компиляция clc_fpc (Free Pascal)..."
	$(FPC) $(FPCFLAGS) -o$(BIN_FPC) srcpas/main.pas

# ------------------------------------------------------------------------------
# 2. Сборка C версии (src/)
# ------------------------------------------------------------------------------
c: $(BIN_C)

$(BIN_C): $(SRCS_C)
	@echo "==> [BUILD] Компиляция clc_c (C Edition)..."
	$(CC) $(CFLAGS) $(SRCS_C) -o $(BIN_C)

# ------------------------------------------------------------------------------
# 3. Полный пайплайн тестирования: CoLang (.cl) -> NASM (.asm) -> Binary
# ------------------------------------------------------------------------------
test_fpc: fpc
	@echo "==> [TEST] Прогон через clc_fpc..."
	./$(BIN_FPC) examples/hello.cl -o output.asm -v
	$(NASM) $(NASMFLAGS) output.asm -o output.o
	$(CC) -no-pie output.o -o hello_app
	@echo "==> [RUN] Запуск скомпилированной программы:"
	@./hello_app

test_c: c
	@echo "==> [TEST] Прогон через clc_c..."
	./$(BIN_C) examples/hello.cl -o output.asm -v
	$(NASM) $(NASMFLAGS) output.asm -o output.o
	$(CC) -no-pie output.o -o hello_app
	@echo "==> [RUN] Запуск скомпилированной программы:"
	@./hello_app

test: test_fpc test_c

# ------------------------------------------------------------------------------
# 4. Автоматическое создание / обновление .gitignore
# ------------------------------------------------------------------------------
gitignore:
	@echo "==> [GIT] Генерация .gitignore..."
	@echo "# Free Pascal temporary files" > .gitignore
	@echo "*.ppu" >> .gitignore
	@echo "*.o" >> .gitignore
	@echo "*.a" >> .gitignore
	@echo "*.or" >> .gitignore
	@echo "*.res" >> .gitignore
	@echo "*.rsj" >> .gitignore
	@echo "*.lps" >> .gitignore
	@echo "*.bak" >> .gitignore
	@echo "*.stat" >> .gitignore
	@echo "" >> .gitignore
	@echo "# Build artifacts & executables" >> .gitignore
	@echo "$(BIN_FPC)" >> .gitignore
	@echo "$(BIN_C)" >> .gitignore
	@echo "output.asm" >> .gitignore
	@echo "output.o" >> .gitignore
	@echo "hello_app" >> .gitignore
	@echo "==> [GIT] Готово! .gitignore обновлен."

# ------------------------------------------------------------------------------
# 5. Очистка проекта от временных файлов и сборки
# ------------------------------------------------------------------------------
clean:
	@echo "==> [CLEAN] Зачистка артефактов компиляции..."
	$(RM) $(BIN_FPC) $(BIN_C)
	$(RM) srcpas/*.o srcpas/*.ppu srcpas/*.bak
	$(RM) src/*.o src/*.bak
	$(RM) output.asm output.o hello_app
	@echo "==> Проект полностью очищен!"

# ------------------------------------------------------------------------------
# Справка по командам
# ------------------------------------------------------------------------------
help:
	@echo "CoLang Compiler v0.2 Makefile"
	@echo "Использование:"
	@echo "  make          - Собрать оба компилятора (clc_fpc и clc_c)"
	@echo "  make fpc      - Собрать только Free Pascal компилятор"
	@echo "  make c        - Собрать только C компилятор"
	@echo "  make test     - Протестировать работу обоих компиляторов на examples/hello.cl"
	@echo "  make gitignore- Создать/обновить файл .gitignore"
	@echo "  make clean    - Удалить все бинарники, .ppu, .o и временные файлы"
