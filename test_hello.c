#include <stdio.h>
#include <stdlib.h>

int main() {
    printf("Hello from XiangShan emu!\n");
    printf("Performing simple computation...\n");
    
    int sum = 0;
    for (int i = 1; i <= 1000; i++) {
        sum += i;
    }
    
    printf("Sum of 1 to 1000: %d\n", sum);
    printf("Test completed successfully!\n");
    
    return 0;
}
