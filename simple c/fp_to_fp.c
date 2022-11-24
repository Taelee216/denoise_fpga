#include <stdio.h>
#include <stdint.h>
#include <math.h>

/// Fixed-point Format: 8.8 (16-bit)
typedef uint16_t fixed_point_t;

#define FIXED_POINT_FRACTIONAL_BITS 8

/// Converts 8.8 format -> double
double fixed_to_double(fixed_point_t input);

/// Converts double to 8.8 format
fixed_point_t double_to_fixed(double input);

inline double fixed_to_double(fixed_point_t input) {
    return ((double)input / (double)(1 << FIXED_POINT_FRACTIONAL_BITS));
}

inline fixed_point_t double_to_fixed(double input) {
    return (fixed_point_t)(round(input * (1 << FIXED_POINT_FRACTIONAL_BITS)));
}

void out_fixed(fixed_point_t f) {
	size_t size = sizeof(f);
	unsigned char * p = (unsigned char *) &f;
	p += size-1;
	int tmp[16] = {0, };
	int i = 0;
	while (size--) {
		int n;
		for (n=0; n<4; n++) {
			tmp[i++] = (*p & 128 ? 1 : 0);
			*p <<= 1;
		}
		p--;
	}
	// for (i = 0 ; i< 16 ; i++) fprintf(f_out, "%d", tmp[i]);
    for (i = 0 ; i< 16 ; i++) printf("%d", tmp[i]);
}


int main()
{
    out_fixed(double_to_fixed(3.14));
    return 0;
}
