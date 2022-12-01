#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <math.h>
#include "opus_types.h"
#include "common.h"
#include "arch.h"
#include "tansig_table.h"
#include "rnn.h"
#include "rnn_data.h"
#include "rnn_data.c"
#include <stdio.h>

#define NB_BANDS 22

#define CEPS_MEM 8
#define NB_DELTA_CEPS 6

#define NB_FEATURES (NB_BANDS+3*NB_DELTA_CEPS+2)


static OPUS_INLINE float tansig_approx(float x)
{
	int i;
	float y, dy;
	float sign=1;
	/* Tests are reversed to catch NaNs */
	if (!(x<8))
		return 1;
	if (!(x>-8))
		return -1;
#ifndef FIXED_POINT
	/* Another check in case of -ffast-math */
	if (celt_isnan(x))
		return 0;
#endif
	if (x<0)
	{
		x=-x;
		sign=-1;
	}
	i = (int)floor(.5f+25*x);
	x -= .04f*i;
	y = tansig_table[i];
	dy = 1-y*y;
	y = y + x*dy*(1 - y*x);
	return sign*y;
}

static OPUS_INLINE float sigmoid_approx(float x) {
	return .5 + .5*tansig_approx(.5*x);
}

static OPUS_INLINE float relu(float x) {
	return x < 0 ? 0 : x;
}

void compute_dense(const DenseLayer *layer, float *output, const float *input) {
	int i, j;
	int N, M;
	int stride;

	M = layer->nb_inputs;
	N = layer->nb_neurons;

	stride = N;

	for ( i = 0; i < N; i++ ) {
		/* Compute update gate. */
		float sum = layer->bias[i];
		for (j=0;j<M;j++) {
			sum += layer->input_weights[j*stride + i]*input[j];
		}
		output[i] = WEIGHTS_SCALE*sum;
	}

	if (layer->activation == ACTIVATION_SIGMOID) {
		for (i=0;i<N;i++)
			output[i] = sigmoid_approx(output[i]);
	} else if (layer->activation == ACTIVATION_TANH) {
		for (i=0;i<N;i++)
			output[i] = tansig_approx(output[i]);
	} else if (layer->activation == ACTIVATION_RELU) {
		for (i=0;i<N;i++)
			output[i] = relu(output[i]);
	} else {
	  *(int*)0=0;
	}
}

void compute_gru(const GRULayer *gru, float *state, const float *input) {
	int i, j;
	int N, M;
	int stride;

	float z[MAX_NEURONS];
	float r[MAX_NEURONS];
	float h[MAX_NEURONS];

	M = gru->nb_inputs;
	N = gru->nb_neurons;

	stride = 3*N;

	for (i=0;i<N;i++) {
		/* Compute update gate. */
		float sum = gru->bias[i];
		for (j=0;j<M;j++) {
			sum += gru->input_weights[j*stride + i]*input[j];
		}
		for (j=0;j<N;j++) {
			sum += gru->recurrent_weights[j*stride + i]*state[j];
		}
		z[i] = sigmoid_approx(WEIGHTS_SCALE*sum);
	}

	for (i=0;i<N;i++) {
		/* Compute reset gate. */
		float sum = gru->bias[N + i];
		for (j=0;j<M;j++) {
			sum += gru->input_weights[N + j*stride + i]*input[j];
		}
		for (j=0;j<N;j++) {
			sum += gru->recurrent_weights[N + j*stride + i]*state[j];
		}
		r[i] = sigmoid_approx(WEIGHTS_SCALE*sum);
	}

	for (i=0;i<N;i++) {
		/* Compute output. */
		float sum = gru->bias[2*N + i];
		for (j=0;j<M;j++) {
			sum += gru->input_weights[2*N + j*stride + i]*input[j];
		}
		for (j=0;j<N;j++) {
			sum += gru->recurrent_weights[2*N + j*stride + i]*state[j]*r[j];
		}
		if (gru->activation == ACTIVATION_SIGMOID) sum = sigmoid_approx(WEIGHTS_SCALE*sum);
		else if (gru->activation == ACTIVATION_TANH) sum = tansig_approx(WEIGHTS_SCALE*sum);
		else if (gru->activation == ACTIVATION_RELU) sum = relu(WEIGHTS_SCALE*sum);
		else *(int*)0=0;
		h[i] = z[i]*state[i] + (1-z[i])*sum;
	}
	for (i=0;i<N;i++) {
		state[i] = h[i];
	}
}

#define INPUT_SIZE 42

int main(void) {
	float dense_out[MAX_NEURONS];
	float noise_input[MAX_NEURONS*3];
	float denoise_input[MAX_NEURONS*3];
	float	features[NB_FEATURES] = {-2.070347, -0.484730, 0.961037, 0.588829, 0.573093, 0.462795, -0.154907, -0.374600, -0.340716, -0.058366, 0.076098, 0.253870, 0.141891, -0.007446, -0.154058, -0.070963, -0.009309, 0.079642, -0.005297, -0.169790, -0.144220, -0.003817, -2.070347, -0.484730, 0.961037, 0.588829, 0.573093, 0.462795, -2.070347, -0.484730, 0.961037, 0.588829, 0.573093, 0.462795, -1.297043, -0.913535, -0.018581, -0.036043, -0.031924, -0.049120, 1.620000, -1.250832};
	compute_dense(&input_dense, dense_out, features);
	// for (int i = 0; i < 24; i++) printf("%lf\n", dense_out[i]);
	return 0;
}