#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <stddef.h>
#include <stdio.h>
#include <stdint.h>
#include <assert.h>

typedef uint32_t word;

static const word K1 = 0x5A827999;
static const word K2 = 0X6ED9EBA1;
static const word K3 = 0x8F1BBCDC;
static const word K4 = 0xCA62C1D6;

static word circular(unsigned u, word w) {
        return (w << u) | (w >> (32 - u));
}

static void padding(const char* message, word* padded) {
    uint64_t length = strlen(message);
    unsigned char* p_length = (unsigned char*) &length;
    unsigned char* w_p = (unsigned char*) padded;
    for (size_t i = 0; i < 56; i++) {
        if (i < length) {
            w_p[i] = message[i];
            continue;
        }
        if (i == length) {
            w_p[i] = '\x80';
            continue;
        }
        w_p[i] = '\x00';
    }
    length *= 8;
    for (size_t i = 0; i < 8; i++) {
        w_p[56 + i] = p_length[7 - i];
    }
    w_p = (unsigned char*) padded;
    word result;
    unsigned char* p_result = (unsigned char*) &result;
    for (size_t i = 0; i < 16; i++) {
        for (size_t j = 0; j < 4; j++) {
            p_result[j] = w_p[3 - j];
        }
        w_p += sizeof(uint32_t);
        padded[i] = result;
    }
}

static word f(unsigned u, word b, word c, word d) {
    if (u <= 19) {
        return (b & c) | ((~b) & d);
    }
    if (u <= 39) {
        return b ^ c ^ d;
    }
    if (u <= 59) {
        return (b & c) | (b & d) | (c & d);
    }
    if (u <= 79) {
        return b ^ c ^ d;
    }
    return 0;
}

static word k(unsigned u) {
    if (u <= 19) {
        return K1;
    }
    if (u <= 39) {
        return K2;
    }
    if (u <= 59) {
        return K3;
    }
    if (u <= 79) {
        return K4;
    }
    return 0;
}

static void calculate(char* message) {
    word padded[16] = {'\0'};
    /* puts(message); */
    word temp;
    word bufferA[5] = {'\0'};
    word bufferB[5] = { 0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0 };
    word sequence[80] = {'\0'};
    padding(message, padded);
    /* unsigned char* p_padded = (unsigned char*) padded; */

    /* for (size_t i = 0; i < 64; i++) { */
    /*     if (i % 4 == 0) { */
    /*         printf(" "); */
    /*     } */
    /*     if (i % 16 == 0) { */
    /*         printf("\n"); */
    /*     } */
    /*     printf("%0.2x", p_padded[i]); */
    /* } */
    /* printf("\n"); */

    for (size_t i = 0; i < 80; i++) {
        if (i < 16) {
            sequence[i] = padded[i];
            continue;
        }
        sequence[i] = circular(1, (sequence[i - 3] ^ sequence[i - 8] ^ sequence[i - 14] ^ sequence[i - 16]));
    }

    for (size_t j = 0; j < 5; j++) {
        bufferA[j] = bufferB[j];
    }

    for (size_t i = 0; i < 80; i++) {
        temp = circular(5, bufferA[0]) + f(i, bufferA[1], bufferA[2], bufferA[3]) + bufferA[4] + sequence[i] + k(i);
        bufferA[4] = bufferA[3];
        bufferA[3] = bufferA[2];
        bufferA[2] = circular(30, bufferA[1]);
        bufferA[1] = bufferA[0];
        bufferA[0] = temp;
    }
    bufferB[0] = bufferB[0] + bufferA[0];
    bufferB[1] = bufferB[1] + bufferA[1];
    bufferB[2] = bufferB[2] + bufferA[2];
    bufferB[3] = bufferB[3] + bufferA[3];
    bufferB[4] = bufferB[4] + bufferA[4];

    /* for (size_t i = 0; i < 20; i++) { */
    /*     unsigned char* p_word = (unsigned char*) &bufferB; */
    /*     printf("%0.2x", p_word[i]); */
    /* } */
    /* puts(""); */
    unsigned char* w_p;
    for (size_t i = 0; i < 5; i++) {
        for (size_t j = 0; j < 4; j++) {
            w_p = (unsigned char*) &bufferB[i];
            printf("%0.2x", w_p[3 - j]);
        }
    }
}

int main(int argc, char** argv) {
    /* if (argc != 2) { */
    /*     fprintf(stdout, "Usage: %s <string>\n", argv[0]); */
    /*     return 1; */
    /* } */
    char buffer[56];
    if (argc == 1 || (argc == 2 && strcmp(argv[1], "-") == 0)) {
        if (read(fileno(stdin), (void*) buffer, 56) == -1) {
            fprintf(stderr, "Error while reading. ERRNO: %d\n", errno);
            return errno;
        }
        calculate(buffer);
        printf("  -\n");
    }

    if (argc > 1 && strcmp(argv[1], "-") != 0) {
        size_t i = 1;
        FILE* fp;
        while (argv[i] != NULL) {
            if (fp = fopen(argv[i], "r"), fp == NULL) {
                fprintf(stderr, "%s: %s: No such file or directory\n", argv[0], argv[i]);
                i++;
                continue;
                if (fclose(fp) == EOF) {
                    fprintf(stderr, "Error while file closing. File: %s - ERRNO: %d\n", argv[i], errno);
                    return errno;
                }
                return errno;
            }
            if (read(fileno(fp), (void*) buffer, 56) == -1) {
                fprintf(stderr, "Error while reading. ERRNO: %d\n", errno);
                return errno;
            }

            calculate(buffer);
            printf("  %s\n", argv[i]);

            if (fclose(fp) == EOF) {
                fprintf(stderr, "Error while file closing. File: %s - ERRNO: %d\n", argv[i], errno);
                return errno;
            }
            i++;
        }
    }
}
