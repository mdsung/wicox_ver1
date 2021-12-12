# wicox_program_v1
- WICOX는 다기관 연구를 위해서 고안된 방법론임
- 알고리즘 저자 : JI AE PARK

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
- 각 stage를 순차적으로 실행하되, input 폴더에 필요한 파일들이 있는지 꼭 확인해줘야 합니다.(아래에 기재함)
> 용어
> * global : 서버환경 - 현재는 SEV를 서버로 가정
> * local : 각 기관 자체 - SEV, NCC

### STEP 0
- 단변량 유의성 검정 단계
    - local(NCC or SEV)에서 먼저 변수들이 실제로 유의한지 검증하는 단계
    - stage 0 directory로 가서 stage_0.R를 실행 `Rscript stage_0.R`
    - input : NCC 혹은 SEV 원본 데이터
    - output : 1) 유의한 변수 리스트, 2) 수정된 데이터

### STEP 1
- 데이터 분할 및 cox 모형 생성단계
    - 환경 : local 환경
    - input : 변수 추려진 원본(csv 형태)
    - output : 1) 변수면 변형된 데이터(changed_data), 2)기관별 Z1Z2List, 3)기관별 total_model, 4)기관별 time_vector
    - 다른 기관으로 보내야할 output : total_model_{기관}.rds, {기관}_time.rds
        * 기관의 이름은 settings에 따라 H1, H2로 지정되게 되어 있습니다. H1은 SEV이며, H2는 NCC입니다.(참고: settings.R)

### STEP 2
- loss 구하는 단계
    - 환경 : local 환경
    - input : 1) total_models(모든기관), 2) Z1Z2 data(local)
    - output : loss Matrix_{기관}
    - 다른 기관으로 보내야 할 output : 기관의 loss Matrix를 server로 보내줘야 함. 현재는 SEV로 보내주시면 됩니다.

### STEP 3
- loss 취합 및 WIM weight 구하는 단계
    - 환경 : Server(현재는 SEV가 server 역할)
    - input : 1) loss Matrix(모든기관), 2) total_models(모든 기관)
    - output : WIM_standard_beta, WIM_variance_adjusted_beta
    - 다른 기관에 보내댜 할 output : 기관의 WIM_standard_beta, WIM_variance_adjusted_beta를 각 기관이 모두 공유해야 함. STEP4, STEP5의 input 폴더에 넣어줘야 함

### STEP 4
 - 각 기관별 risk list 만드는 단계
    - 환경 : local 환경
    - input : 1) WIM_variance_adjusted_beta, 2) {기관}_changed_data, 3) {기관}_time(모든 기관)
    - output : {기관}_risk_share_list
    - 다른 기관에 보내댜 할 output : risk_share_list를 server로 보내줘야 함. 
### STEP 5 
 - survival curve 추정하는 단계
    - 환경 : Server
    - input : 1) {기관}_risk_share_list(모든 기관), 2) WIM_variance_adjusted_beta
    - output : base_surv_list