/* Copyright (c) 2018 Gregor Richards
 * Copyright (c) 2017 Mozilla */
/*
	 Redistribution and use in source and binary forms, with or without
	 modification, are permitted provided that the following conditions
	 are met:

	 - Redistributions of source code must retain the above copyright
	 notice, this list of conditions and the following disclaimer.

	 - Redistributions in binary form must reproduce the above copyright
	 notice, this list of conditions and the following disclaimer in the
	 documentation and/or other materials provided with the distribution.

	 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
	 ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
	 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
	 A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR
	 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
	 EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
	 PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
	 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
	 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
	 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
	 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#include <stdio.h>
#include "rnnoise.h"

#define FRAME_SIZE 480

int main(int argc, char **argv) {
	int				i;
	int				first = 1;

	float			x[FRAME_SIZE];

	FILE			*f_in, 	*f_out;

	DenoiseState	*st;
	st = rnnoise_create (NULL);

	if (argc! = 3) {
		fprintf(stderr, "usage: %s <noisy speech> <output denoised>\n", argv[0]);
		return 1;
	}

	f_in	= fopen(argv[1], "rb");
	f_out	= fopen(argv[2], "wb");

	while (true) {
		short		tmp[FRAME_SIZE];

		fread (tmp, sizeof(short), FRAME_SIZE, f_in);

		if	(feof(f_in)) {
			break;
		}

		for	(i = 0; i < FRAME_SIZE; i++) {
			x[i] = tmp[i];
		}

		rnnoise_process_frame (st, x, x);

		for	(i = 0; i < FRAME_SIZE; i++) {
			tmp[i] = x[i];
		}

		if	(!first) {
			fwrite (tmp, sizeof(short), FRAME_SIZE, f_out);
		}

		first = 0;
	}

	rnnoise_destroy (st);

	fclose (f_in);
	fclose (f_out);

	return 0;
}
