#include <stdio.h>

void colang_print_int(int val) {
    printf("%d", val);
    fflush(stdout);
}

void colang_print_str(const char* str) {
    if (str) {
        printf("%s", str);
        fflush(stdout);
    }
}

void colang_input_int(int* var_ptr) {
    if (var_ptr) {
        if (scanf("%d", var_ptr) != 1) {
            *var_ptr = 0;
        }
    }
}
