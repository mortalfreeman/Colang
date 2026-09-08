# Универсальный Makefile для CoLang (Free Pascal + C версии)

FPC = fpc
CC = gcc

FPCFLAGS = -Mobjfpc -Scghi -O2 -gl -Fu srcpas
CFLAGS = -Wall -Wextra -O2

TARGET_FPC = clc_fpc
TARGET_C = clc_c

SRC_PAS_DIR = srcpas
SRC_C_DIR = src

all: fpc c

# Сборка новой версии на Free Pascal
fpc:
	@echo "==> Сборка компилятора на Free Pascal (srcpas)..."
	$(FPC) $(FPCFLAGS) $(SRC_PAS_DIR)/main.pas -o$(TARGET_FPC)
	@echo "Успешно собрано: ./$(TARGET_FPC)"

# Сборка старой версии на C
c:
	@echo "==> Сборка версии на C (src)..."
	@if [ -d "$(SRC_C_DIR)" ]; then \
		$(CC) $(CFLAGS) $(SRC_C_DIR)/*.c -o $(TARGET_C); \
		echo "Успешно собрано: ./$(TARGET_C)"; \
	else \
		echo "Папка $(SRC_C_DIR) не найдена."; \
	fi

# Очистка всех артефактов обеих версий
clean:
	@echo "==> Очистка временных файлов..."
	rm -f $(TARGET_FPC) $(TARGET_C) output.asm
	rm -f $(SRC_PAS_DIR)/*.o $(SRC_PAS_DIR)/*.ppu $(SRC_PAS_DIR)/*.~*
	rm -f $(SRC_C_DIR)/*.o
	@echo "Очистка завершена."

# Тестирование FPC-версии
test: fpc
	@if [ -f "examples/hello.cl" ]; then \
		./$(TARGET_FPC) examples/hello.cl; \
	else \
		echo "Тестовый файл examples/hello.cl не найден."; \
	fi

.PHONY: all fpc c clean test
