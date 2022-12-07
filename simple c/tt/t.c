#include <math.h>
#include "opus_types.h"
#include "common.h"
#include "arch.h"
#include "tansig_table.h"
#include "rnn.h"
#include "rnn_data.h"
#include <stdio.h>

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "kiss_fft.h"
#include "common.h"
#include <math.h>
#include "rnnoise.h"
#include "pitch.h"
#include "arch.h"
#include "rnn.h"
#include "rnn_data.h"
#include "rnn_data.c"

#define FRAME_SIZE_SHIFT 2
#define FRAME_SIZE (120<<FRAME_SIZE_SHIFT)
#define WINDOW_SIZE (2*FRAME_SIZE)
#define FREQ_SIZE (FRAME_SIZE + 1)

#define PITCH_MIN_PERIOD 60
#define PITCH_MAX_PERIOD 768
#define PITCH_FRAME_SIZE 960
#define PITCH_BUF_SIZE (PITCH_MAX_PERIOD+PITCH_FRAME_SIZE)

#define SQUARE(x) ((x)*(x))

#define NB_BANDS 22

#define CEPS_MEM 8
#define NB_DELTA_CEPS 6

#define NB_FEATURES (NB_BANDS+3*NB_DELTA_CEPS+2)



/* The built-in model, used if no file is given as input */
extern const struct RNNModel rnnoise_model_orig;


static const opus_int16 eband5ms[] = {
/*	0	0.2	0.4	0.6	0.8	1	1.2	1.4	1.6	2	2.4	2.8	3.2	4	4.8	5.6	6.8	8	9.6	12	15.6	20k*/
		0,	1,	2,	3,	4,	5,	6,	7,	8,	10,	12,	14,	16,	20,	24,	28,	34,	40,	48,	60,	78,	100
};


typedef struct {
	int init;
	kiss_fft_state *kfft;
	float half_window[FRAME_SIZE];
	float dct_table[NB_BANDS*NB_BANDS];
} CommonState;

struct DenoiseState {
	float analysis_mem[FRAME_SIZE];
	float cepstral_mem[CEPS_MEM][NB_BANDS];
	int memid;
	float synthesis_mem[FRAME_SIZE];
	float pitch_buf[PITCH_BUF_SIZE];
	float pitch_enh_buf[PITCH_BUF_SIZE];
	float last_gain;
	int last_period;
	float mem_hp_x[2];
	float lastg[NB_BANDS];
	RNNState rnn;
};


int rnnoise_get_size() {
	return sizeof(DenoiseState);
}

int rnnoise_get_frame_size() {
	return FRAME_SIZE;
}

int rnnoise_init(DenoiseState *st, RNNModel *model) {
	memset(st, 0, sizeof(*st));
	if (model)
		st->rnn.model = model;
	else
		st->rnn.model = &rnnoise_model_orig;
	st->rnn.vad_gru_state = calloc(sizeof(float), st->rnn.model->vad_gru_size);
	st->rnn.noise_gru_state = calloc(sizeof(float), st->rnn.model->noise_gru_size);
	st->rnn.denoise_gru_state = calloc(sizeof(float), st->rnn.model->denoise_gru_size);
	return 0;
}

DenoiseState *rnnoise_create(RNNModel *model) {
	DenoiseState *st;
	st = malloc(rnnoise_get_size());
	rnnoise_init(st, model);
	return st;
}

void rnnoise_destroy(DenoiseState *st) {
	free(st->rnn.vad_gru_state);
	free(st->rnn.noise_gru_state);
	free(st->rnn.denoise_gru_state);
	free(st);
}


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
		if (i == 21) printf("%d: sum : %lf \n", i, sum/256);
		for (j=0;j<M;j++) {
			sum += layer->input_weights[j*stride + i]*input[j];
			if (i == 21) printf("%d: sum : %lf \n", i, sum/256);
		}
		output[i] = WEIGHTS_SCALE*sum;
		printf("output[%d] = WEIGHTS_SCALE*sum : %lf \n", i, output[i]);
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
			//printf("sum : %lf = gru->input_weights*input;    ", sum);
		}
		for (j=0;j<N;j++) {
			sum += gru->recurrent_weights[j*stride + i]*state[j];
			//printf("sum : %lf = gru->recurrent_weights*state;    ", sum);
		}
		z[i] = sigmoid_approx(WEIGHTS_SCALE*sum);
		printf("z[%d] : %lf = WEIGHTS_SCALE*sum : %lf \n", i, z[i], WEIGHTS_SCALE*sum);
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
		printf("r[%d]  : %lf \n", i, r[i]);
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
		printf("sum_before[%d] : %lf \n", i, WEIGHTS_SCALE*sum);
		if (gru->activation == ACTIVATION_SIGMOID) sum = sigmoid_approx(WEIGHTS_SCALE*sum);
		else if (gru->activation == ACTIVATION_TANH) sum = tansig_approx(WEIGHTS_SCALE*sum);
		else if (gru->activation == ACTIVATION_RELU) sum = relu(WEIGHTS_SCALE*sum);
		else *(int*)0=0;
		printf("sum_after[%d] : %lf \n", i, WEIGHTS_SCALE*sum);
		h[i] = z[i]*state[i] + (1-z[i])*sum;
		//printf("h[%d]: %lf = %lf*%lf + (1-%lf)*%lf;\n", i, h[i], z[i], state[i], z[i], sum);
	}
	for (i=0;i<N;i++) {
		state[i] = h[i];
	}
}

#define INPUT_SIZE 42

void compute_rnn(RNNState *rnn, float *gains, float *vad, const float *input) {
	int i;
	float dense_out[MAX_NEURONS];
	float noise_input[MAX_NEURONS*3];
	float denoise_input[MAX_NEURONS*3];
	
	compute_dense(rnn->model->input_dense, dense_out, input);

	for (int i = 0 ; i < 24 ; i++) printf("dense_out[%d] = %lf \n", i, dense_out[i]);

	compute_gru(rnn->model->vad_gru, rnn->vad_gru_state, dense_out);

	for (int i = 0 ; i < 24 ; i++) printf("rnn->vad_gru_state[%d] = %lf \n", i, rnn->vad_gru_state[i]);

	//compute_dense(rnn->model->vad_output, vad, rnn->vad_gru_state);
	/*
		static const DenseLayer vad_output = {
			vad_output_bias				[1],
			vad_output_weights			[24],
			int nb_inputs				24, 
			int nb_neurons				1, 
			ACTIVATION_SIGMOID
		};
	*/
	//for (i=0;i<rnn->model->input_dense_size;i++)	noise_input[i] 															= dense_out[i];
	//for (i=0;i<rnn->model->vad_gru_size;i++) 		noise_input[i+rnn->model->input_dense_size] 							= rnn->vad_gru_state[i];
	//for (i=0;i<INPUT_SIZE;i++)						noise_input[i+rnn->model->input_dense_size+rnn->model->vad_gru_size]	= input[i];
	//compute_gru(rnn->model->noise_gru, rnn->noise_gru_state, noise_input);
	/*
		static const GRULayer noise_gru = {
			noise_gru_bias				[144],
			noise_gru_weights			[12960],
			noise_gru_recurrent_weights	[6912],
			int nb_inputs				90, 
			int nb_neurons				48, 
			ACTIVATION_RELU
		};
	*/

	//for (i=0;i<rnn->model->vad_gru_size;i++) 		denoise_input[i] 														= rnn->vad_gru_state[i];
	//for (i=0;i<rnn->model->noise_gru_size;i++)		denoise_input[i+rnn->model->vad_gru_size]								= rnn->noise_gru_state[i];
	//for (i=0;i<INPUT_SIZE;i++)						denoise_input[i+rnn->model->vad_gru_size+rnn->model->noise_gru_size]	= input[i];
	//compute_gru(rnn->model->denoise_gru, rnn->denoise_gru_state, denoise_input);
	/*
		static const GRULayer denoise_gru = {
			denoise_gru_bias			[288],
			denoise_gru_weights			[32832],
			denoise_gru_recurrent_weights	[27648],
			int nb_inputs				114, 
			int nb_neurons				96, 
			ACTIVATION_RELU
		};
	*/
	//compute_dense(rnn->model->denoise_output, gains, rnn->denoise_gru_state);
	/*
		static const DenseLayer denoise_output = {
			denoise_output_bias			[22],
			denoise_output_weights		[2112],
			int nb_inputs				96, 
			int nb_neurons				22, 
			ACTIVATION_SIGMOID
		};
	*/
	// for (int i = 0 ; i < 22 ; i++) printf("gains[%d] = %lf \n", i, gains[i]);
}


int main(void) {
	DenoiseState	*st;
	st = rnnoise_create (NULL);

	float	features[NB_FEATURES] = {-2.070347, -0.484730, 0.961037, 0.588829, 0.573093, 0.462795, -0.154907, -0.374600, -0.340716, -0.058366, 0.076098, 0.253870, 0.141891, -0.007446, -0.154058, -0.070963, -0.009309, 0.079642, -0.005297, -0.169790, -0.144220, -0.003817, -2.070347, -0.484730, 0.961037, 0.588829, 0.573093, 0.462795, -2.070347, -0.484730, 0.961037, 0.588829, 0.573093, 0.462795, -1.297043, -0.913535, -0.018581, -0.036043, -0.031924, -0.049120, 1.620000, -1.250832};
	float	gain[NB_BANDS];
	float	vad_prob = 0;
	compute_rnn(&st->rnn, gain, &vad_prob, features);
	// for (int i = 0; i < 24; i++) printf("%lf\n", dense_out[i]);
	return 0;
}