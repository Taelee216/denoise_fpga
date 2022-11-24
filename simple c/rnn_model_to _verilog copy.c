#include <stdio.h>

float feature[42] = {
	-2.070347, 
	-0.484730, 
	0.961037, 
	.588829, 
	0.573093, 
	0.462795, 
	-0.154907, 
	-0.374600, 
	-0.340716, 
	-0.058366, 
	0.076098, 
	0.253870, 
	0.141891, 
	-0.007446, 
	-0.154058, 
	-0.070963, 
	-0.009309, 
	0.079642, 
	-0.005297, 
	-0.169790, 
	-0.144220, 
	-0.003817, 
	-2.070347, 
	-0.484730, 
	0.961037, 
	0.588829, 
	0.573093, 
	0.462795, 
	-2.070347, 
	-0.484730, 
	0.961037, 
	0.588829, 
	0.573093, 
	0.462795, 
	-1.297043, 
	-0.913535, 
	-0.018581, 
	-0.036043, 
	-0.031924, 
	-0.049120, 
	1.620000, 
	-1.250832
};

FILE *f_out;

void out_float(float f) {
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
	for (i = 0 ; i< 32 ; i++) fprintf(f_out, "%d", tmp[i]);
}

int main() {
	int size;


///////////////////////////////////////////////////////////////////////////     input_dense_bias
	f_out	= fopen("feature.mem", "w");
	size    = sizeof(feature) / sizeof(feature[0]);
	for (int i = 0; i < size; i++) {
		// fprintf(f_out, "assign\tinput_dense_bias_array[%5d] = 32'b", i);
		out_float(feature[i]);
		fprintf(f_out, "\n");
		// fprintf(f_out, ";\n");
	}
	fclose(f_out);


	return 0;
}