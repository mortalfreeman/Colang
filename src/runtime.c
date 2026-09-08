#include <stdio.h>
#include <string.h>
#include <unistd.h>

// Вывод обычной строки без форматирования
void __clc_print_raw(const char *s) {
    if (s) {
        printf("%s", s);
        fflush(stdout);
    }
}

// Вывод форматированного числа
void __clc_print_fmt_int(const char *fmt, long long val) {
    if (fmt) {
        printf(fmt, val);
        fflush(stdout);
    }
}

// Вывод форматированного текста
void __clc_print_fmt_txt(const char *fmt, const char *val) {
    if (fmt) {
        printf(fmt, val ? val : "");
        fflush(stdout);
    }
}

// Ввод текста от пользователя (itaker)
void __clc_input_text(char *buf, size_t size) {
    if (!buf || size == 0) return;
    if (fgets(buf, (int)size, stdin)) {
        size_t len = strlen(buf);
        if (len > 0 && buf[len - 1] == '\n') {
            buf[len - 1] = '\0';
        }
    }
}

// Зануление текстового буфера при создании переменной типу txt
void __clc_zero_text(char *buf, size_t size) {
    if (buf && size > 0) {
        memset(buf, 0, size);
    }
}

// Копирование строк (для оператора присваивания let)
void __clc_strcpy(char *dest, const char *src) {
    if (dest && src) {
        strcpy(dest, src);
    }
}

// Ассинхронная/синхронная пауза (wait)
void __clc_wait_async(long long seconds) {
    if (seconds > 0) {
        sleep((unsigned int)seconds);
    }
}
