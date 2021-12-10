# load package
source

#################################### STAGE 0 ################################
# local environment
# input : 1) 각 기관의 원본 데이터를 입력해줘야 함
# output : 2) parsing된 데이터(유효한 변수만 추려진 데이터)


# 경로 설정
stage0_path <- here("stage0/")
input_path <- here(stage0_path, "input/")
output_path <- here(stage0_path, "output/")

# 기존에 있던 코드. 일단 지우지 않음
# originalData <- read_csv("stage1/input/forSurv.csv")


colnames2check <- colnames(originalData)[3:ncol(originalData)]

checkVariable <- function(col) {
    fit <- coxph(Surv(OVRL_SRVL_DTRN_DCNT, BSPT_SRV) ~ get(col),
        data = originalData, ties = "breslow"
    )
    pvalue <- summary(fit)$logtest[[3]]
    coeff <- summary(fit)$coefficient[1]
    return(c(coeff, pvalue))
}

checkVariable("BSPT_SEX_CD")

# 이제 어떤 변수가 유효한지 확인하는 for문을 돌려준다.
checkMatrix <- matrix(nrow = length(colnames2check), ncol = 2)

for (i in seq_along(colnames2check)) {
    checkMatrix[i, ] <- checkVariable(colnames2check[i])
}

# 0.05보다 작은 것들만 선별
msk <- checkMatrix[, 2] < 0.05
validCols <- colnames2check[msk]

validCols

parsedData <- originalData %>% select(colnames(originalData)[1:2], validCols)
write_csv(parsedData, glue(output_path,"{name}_data.csv"))

print("====================================================================================================================")
print("stage 0 is finished successfully. 단계 0이 성공적으로 종료되었습니다")
print(glue("stage 0 output폴더에 있는 {name}_data.csv를 stage1의 input 폴더로 옮겨주시기 바랍니다."))
print("====================================================================================================================")
