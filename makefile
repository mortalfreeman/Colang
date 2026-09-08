# Универсальный Makefile для CoLang (Free Pascal + C версии)

# Компиляторы
FPC = fpc
CC = gcc

# Флаги компиляции
FPCFLAGS = -Mobjfpc -Scghi -O2 -gl
CFLAGS = -Wall -Wextra -O2

# Исполняемые файлы
TARGET_FPC = clc_fpc
TARGET_C = clc_c

# Директории
DIR_PAS = srcpas
DIR_C = src

all: fpc

# Сборка основной версии на Free Pascal (из srcpas)
fpc:
	@echo "==> Сборка компилятора на Free Pascal (экосистема srcpas)..."
	$(FPC) $(FPCFLAGS) $(DIR_PAS)/main.pas -o$(TARGET_FPC)
	@echo "Успешно собрано: ./$(TARGET_FPC)"

# Сборка версии на C (если используется папка src)
c:
	@echo "==> Сборка версии на C (из src)..."
	@if [ -d "$(DIR_C)" ] && [ -n "$$("$$(CC)" --version)" ]; then \
		$(CC) $(CFLAGS) $(DIR_C)/*.c -o $(TARGET_C); \
		echo "Успешно собрано: ./$(TARGET_C)"; \
	else \
		echo "Папка $(DIR_C) не найдена или компилятор C недоступен."; \
	fi

# Собрать сразу обе версии
both: fpc c

# Очистка всех артефактов сборки
clean:
	@echo "==> Очистка временных файлов..."
	rm -f $(TARGET_FPC) $(TARGET_C)
	rm -f $(DIR_PAS)/*.o $(DIR_PAS)/*.ppu $(DIR_PAS)/*.~*
	rm -f $(DIR_C)/*.o
	@echo "Очистка завершена."

# Запуск тестов на FPC-компиляторе
test: fpc
	@if [ -f "examples/hello.cl" ]; then \
		./$(TARGET_FPC) examples/hello.cl; \
	else \
		echo "Тестовый файл examples/hello.cl не найден."; \
	fi

.PHONY: all fpc c both clean test
