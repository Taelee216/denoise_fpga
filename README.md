# denoise FPGA

주어진 라이브러리에서 수정한 것  

+ denoise  
  + 텍스트 파일에 입력 features와 출력 gain 덤프  

+ demo  
  + 텍스트 파일 초기화

FRAME_SIZE == 480  
sampling rate == 48000
1 second == 100 frames

features & gain bands  
> #define NB_BANDS 22  
>  
> #define NB_DELTA_CEPS 6  
>  
> #define NB_FEATURES (NB_BANDS+3*NB_DELTA_CEPS+2)  
> NB_FEATURES == 22 + 3*6 + 2 == 42  

할 것  

1. C에서 사용한 rnn 코드 내용을 verilog로 변환 <- src 폴더에서 수정  
2. FPGA 보드의 입출력을 확인하여 노이즈가 제거됨을 확인  

+ 첫 실행시 autoreconf 설치 필요  
  + sudo apt-get install autoconf  
  + sudo apt-get install libtool  
  
+ ffmpeg  
  + ffmpeg -i input_wav.wav -f s16le -acodec pcm_s16le -ar 48k input_pcm.pcm  
  + ffmpeg -f s16le -acodec pcm_s16le -ar 48k -i output_pcm.pcm output_wav.wav  

+ Compile  
  + ./autogen.sh  
  + ./configure  
  + make  

  + ./autogen.sh && ./configure && make  

+ usage  
  + ./examples/rnnoise_demo ./examples/input_pcm.pcm ./examples/output_pcm.pcm  
