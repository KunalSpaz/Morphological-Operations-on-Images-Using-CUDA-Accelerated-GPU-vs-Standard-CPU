#include <stdio.h>
#include <stdlib.h>

unsigned char* loadPGM(const char* filename, int* width, int* height) {
    FILE* fp = fopen(filename, "rb");
    if (!fp) {
        perror("Error opening file");
        return NULL;
    }

    char format[3];
    fscanf(fp, "%2s", format);
    if (format[0] != 'P' || format[1] != '5') {
        printf("Unsupported format: %s\n", format);
        fclose(fp);
        return NULL;
    }

    int maxval;
    fscanf(fp, "%d %d %d", width, height, &maxval);
    fgetc(fp); // Consume newline

    size_t imgSize = (size_t)(*width) * (size_t)(*height);
    unsigned char* data = (unsigned char*)malloc(imgSize);
    fread(data, sizeof(unsigned char), imgSize, fp);
    fclose(fp);
    return data;
}

void savePGM(const char* filename, unsigned char* data, int width, int height) {
    FILE* fp = fopen(filename, "wb");
    fprintf(fp, "P5\n%d %d\n255\n", width, height);
    fwrite(data, sizeof(unsigned char), (size_t)width * (size_t)height, fp);
    fclose(fp);
}

void dilation(unsigned char* input, unsigned char* output, int width, int height) {
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            int maxVal = 0;
            for (int j = -1; j <= 1; ++j) {
                for (int i = -1; i <= 1; ++i) {
                    int nx = x + i;
                    int ny = y + j;
                    if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
                        int idx = ny * width + nx;
                        if (input[idx] > maxVal) {
                            maxVal = input[idx];
                        }
                    }
                }
            }
            output[y * width + x] = (unsigned char)maxVal;
        }
    }
}

void erosion(unsigned char* input, unsigned char* output, int width, int height) {
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            int minVal = 255;
            for (int j = -1; j <= 1; ++j) {
                for (int i = -1; i <= 1; ++i) {
                    int nx = x + i;
                    int ny = y + j;
                    if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
                        int idx = ny * width + nx;
                        if (input[idx] < minVal) {
                            minVal = input[idx];
                        }
                    }
                }
            }
            output[y * width + x] = (unsigned char)minVal;
        }
    }
}

int main() {
    const char* filename = "image.pgm";
    int width, height;
    unsigned char* input = loadPGM(filename, &width, &height);
    if (!input) return 1;

    size_t imgSize = (size_t)width * (size_t)height;
    unsigned char* output = (unsigned char*)malloc(imgSize);

    int choice;
    printf("Choose operation:\n1. Dilation\n2. Erosion\nEnter your choice: ");
    scanf("%d", &choice);

    if (choice == 1) {
        dilation(input, output, width, height);
        savePGM("dilated.pgm", output, width, height);
        printf("Dilation completed. Saved to 'dilated.pgm'\n");
    } else if (choice == 2) {
        erosion(input, output, width, height);
        savePGM("eroded.pgm", output, width, height);
        printf("Erosion completed. Saved to 'eroded.pgm'\n");
    } else {
        printf("Invalid choice.\n");
    }

    free(input);
    free(output);
    return 0;
}