#include <stdio.h>
#include <stdint.h>
#include <math.h>



FILE *f_out;


typedef uint16_t fixed_point_t;

fixed_point_t arr[1024];

double fixed8_to_double(fixed_point_t input);
fixed_point_t double_to_fixed8(double input);
double fixed12_to_double(fixed_point_t input);
fixed_point_t double_to_fixed12(double input);

inline double fixed8_to_double(fixed_point_t input) {
    return ((double)input / (double)(1 << 8));
}

inline fixed_point_t double_to_fixed8(double input) {
    return (fixed_point_t)(round(input * (1 << 8)));
}

inline double fixed12_to_double(fixed_point_t input) {
    return ((double)input / (double)(1 << 12));
}

inline fixed_point_t double_to_fixed12(double input) {
    return (fixed_point_t)(round(input * (1 << 12)));
}

void out_fixed(fixed_point_t f) {
	size_t size = sizeof(f);
	unsigned char * p = (unsigned char *) &f;
	p += size-1;
	int tmp[32] = {0, };
	int i = 0;
	while (size--) {
		int n;
		for (n=0; n<8; n++) {
			tmp[i++] = (*p & 128 ? 1 : 0);
			*p <<= 1;
		}
		p--;
	}
	// for (i = 0 ; i< 16 ; i++) fprintf(f_out, "%d", tmp[i]);
    for (i = 0 ; i < 16 ; i++) fprintf(f_out, "%d", tmp[i]);
}


int main() {

	int size;
	double tanh[1024];
	for (int i = 0; i < 1024; i++) {
		arr[i] = i;
	}
	
/*
	float three[1024], tanh[1024];
	f_out	= fopen("1023.mem", "w");
	for (int i = 0; i < 1024; i++) {
		out_fixed(double_to_fixed(i));
		fprintf(f_out, ",\n");
	}
	*/
	
	for (int i = 0; i < 1024; i++) {
		tanh[i] = tanhf(fixed8_to_double(arr[i]));
		printf("%lf\n", tanh[i]);
	}

	f_out	= fopen("tanh_fixed_8_8.mem", "w");
	size    = sizeof(tanh) / sizeof(tanh[0]);
	for (int i = 0; i < size; i++) {
		// fprintf(f_out, "assign\tinput_dense_bias_array[%5d] = 32'b", i);
		out_fixed(double_to_fixed8(tanh[i]));
		fprintf(f_out, "\n");
		// fprintf(f_out, ";\n");
	}

	fclose(f_out);

    return 0;
}
