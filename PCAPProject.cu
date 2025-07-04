#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>

__global__ void dilationKernel(unsigned char* input, unsigned char* output, int width, int height) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height) return;

    int maxVal = 0;
    for (int j = -1; j <= 1; ++j) {
        for (int i = -1; i <= 1; ++i) {
            int nx = x + i;
            int ny = y + j;
            if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
                unsigned char val = input[ny * width + nx];
                if (val > maxVal) maxVal = val;
            }
        }
    }
    output[y * width + x] = maxVal;
}

__global__ void erosionKernel(unsigned char* input, unsigned char* output, int width, int height) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height) return;

    int minVal = 255;
    for (int j = -1; j <= 1; ++j) {
        for (int i = -1; i <= 1; ++i) {
            int nx = x + i;
            int ny = y + j;
            if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
                unsigned char val = input[ny * width + nx];
                if (val < minVal) minVal = val;
            }
        }
    }
    output[y * width + x] = minVal;
}

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
    fgetc(fp); // Consume the newline after maxval

    int imgSize = (*width) * (*height);
    unsigned char* data = (unsigned char*)malloc(imgSize);
    fread(data, sizeof(unsigned char), imgSize, fp);
    fclose(fp);
    return data;
}

void savePGM(const char* filename, unsigned char* data, int width, int height) {
    FILE* fp = fopen(filename, "wb");
    fprintf(fp, "P5\n%d %d\n255\n", width, height);
    fwrite(data, sizeof(unsigned char), width * height, fp);
    fclose(fp);
}

void checkCudaError(const char* msg) {
    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) {
        fprintf(stderr, "CUDA Error (%s): %s\n", msg, cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }
}

int main() {
    const char* filename = "image.pgm";
    int width, height;
    unsigned char* h_input = loadPGM(filename, &width, &height);
    if (!h_input) return 1;

    savePGM("input_saved.pgm", h_input, width, height); // Save input to verify

    int imgSize = width * height;
    unsigned char *d_input, *d_dilated, *d_eroded;
    cudaMalloc(&d_input, imgSize);
    cudaMalloc(&d_dilated, imgSize);
    cudaMalloc(&d_eroded, imgSize);

    cudaMemcpy(d_input, h_input, imgSize, cudaMemcpyHostToDevice);

    dim3 blockSize(16, 16);
    dim3 gridSize((width + 15) / 16, (height + 15) / 16);

    dilationKernel<<<gridSize, blockSize>>>(d_input, d_dilated, width, height);
    checkCudaError("Dilation Kernel");

    erosionKernel<<<gridSize, blockSize>>>(d_input, d_eroded, width, height);
    checkCudaError("Erosion Kernel");

    cudaDeviceSynchronize();

    unsigned char* h_dilated = (unsigned char*)malloc(imgSize);
    unsigned char* h_eroded = (unsigned char*)malloc(imgSize);
    cudaMemcpy(h_dilated, d_dilated, imgSize, cudaMemcpyDeviceToHost);
    cudaMemcpy(h_eroded, d_eroded, imgSize, cudaMemcpyDeviceToHost);

    printf("Sample INPUT pixel values:\n");
    for (int i = 0; i < 10; ++i)
        printf("%d ", h_input[i]);
    printf("\n");

    printf("Sample DILATED pixel values:\n");
    for (int i = 0; i < 10; ++i)
        printf("%d ", h_dilated[i]);
    printf("\n");

    printf("Sample ERODED pixel values:\n");
    for (int i = 0; i < 10; ++i)
        printf("%d ", h_eroded[i]);
    printf("\n");

    savePGM("dilated.pgm", h_dilated, width, height);
    savePGM("eroded.pgm", h_eroded, width, height);

    cudaFree(d_input);
    cudaFree(d_dilated);
    cudaFree(d_eroded);
    free(h_input);
    free(h_dilated);
    free(h_eroded);

    printf("Done.\n");
    return 0;
}
