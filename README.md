# wicox_program_v1
- WICOX는 다기관 연구를 위해서 고안된 방법론임

## program 구성
- stage0 ~ stage5까지로 되어 있음
- 각 stage 폴더에는 stage_*.R 폴더가 존재하며 input, output 폴더가 존재함
- settings.R :
    - 폴더에 기관의 이름(NCC or SEV)을 기재하거나 설정을 바꿀 수 있는 script
- install_packages.R :
    - 필요한 패키지를 미리 설치해주는 script

## program 실행방법
### Preparation ( 준비 ) 
- 먼저 install_packages.R을 실행하여 필요한 패키지가 있는지 확인
- settings.R을 확인하여 기관이 이름이 NCC or SEV 인지 확인

### STEP 0
- 단변량 유의성 검정 단계
    - local(NCC or SEV)에서 먼저 변수들이 실제로 유의한지 검증하는 단계
    - stage 0 directory로 가서 stage_0.R를 실행 `Rscript stage_0.R`
- 각 stage를 순차적으로 실행하되, input 폴더에 필요한 파일들이 있는지 꼭 확인해줘야 합니다.(아래에 기재함)