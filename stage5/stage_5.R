
# load package
source('../settings.R')
# setwd('stage5')
#################################### STAGE 5 ################################
# central environment
# input : 1) 모든 기관의 risk_share_list, 2) WIM_variance_adjusted_beta
# output : 1) base_surv_list

# 경로 설정
stage5_path <- here("stage5/")
input_path <- here(stage5_path, "input/")
output_path <- here(stage5_path, "output/")


WIM_beta <- load_files('WIM_standard_beta',input_path,as_list=FALSE)

lst <- load_files('standard_risk_share_list', input_path, as_list=TRUE)


# 모든 기관의 risk_share_list를 머지한다.

get_total_risk_share_list <- function(risk_share_list)
{
    n_H <- risk_share_list %>% length
    first_list <- risk_share_list[[1]]
    for(i in 1:n_H){
        if(i==n_H){
            break
        }
        first_list <- mapply(merge, first_list, risk_share_list[[i+1]], SIMPLIFY=FALSE)
    }
    first_list <- lapply(first_list, arrange, by=time)
    return(first_list)
}

total_risk_share_list <- get_total_risk_share_list(lst)
total_risk_share_list



make_base_surv <- function(total_risk_share, n_H)
{
    exp_columns <- map_chr(c(1:n_H), ~ glue("H{.}_exp_sum2"))
    sumVector <- total_risk_share %>% select(exp_columns) %>% rowSums(na.rm = T)
    timeVector <- total_risk_share[["event_total"]]
    
    total_risk_share <- total_risk_share %>% mutate(haz =  timeVector / sumVector)
    total_risk_share[["cumhaz"]] <- total_risk_share[["haz"]] %>% cumsum
    print(total_risk_share)
    
    basesurv <- total_risk_share %>% select(c(V1="time",V2="haz",V3="cumhaz"))
    return(basesurv)
}


basesurv_list <- lapply(total_risk_share_list, make_base_surv, n_H=n_H)
saveRDS(basesurv_list, glue(output_path,'basesurv_list.rds'))

print("stage 5 완료되었습니다.")
print("survival calculation 진행하시면 됩니다")



################################################## 여기서부터 생존분석 들어갑니다.
############ 아래의 sample_data에 보고자 하는 수치를 입력해주세요.

# survival calculation. 생존 계산

# sample data vector
sample_data = c(80, 100, 0.0, 1.0)

# 추정된 cox weight를 받아서 샘플과 matrix multiplication 해준다.
ex_vector <- exp(WIM_beta %*% sample_data)

rslt <- lapply(c(1:n_I), function(x) exp((-1) * basesurv_list[[x]][['V3']] * ex_vector[[x]]))

basesurv_total <-matrix(nrow=nrow(basesurv_list[[1]]), ncol=(4+n_I))
#- time
basesurv_total[,1] <- basesurv_list[[1]][,1]
#-- R개 WIM para에 의한 surv



for(i in 1:n_I){
  basesurv_total[,(i+1)] <- rslt[[i]]
}
################ 설명 : Basesurv_total
################ basesurv_total[,1] 은 time-line에 대한 정보
################ basesurv_total[,2~1+n_I] 는 각 iteration에서 추정된 survival probability

for(n in 1:nrow(basesurv_total)){
  #-- mean surv
  basesurv_total[n,(n_I+2)] <- mean(basesurv_total[n,2:(1+n_I)])
  #-- lower CI
  basesurv_total[n,(n_I+3)] <- quantile(basesurv_total[n,2:(1+n_I)], probs=c(0.025))
  #-- upper CI
  basesurv_total[n,(n_I+4)] <- quantile(basesurv_total[n,2:(1+n_I)], probs=c(0.975))
}
for_survival_curv <- basesurv_total[,c(1,n_I+2, n_I+3, n_I+4)]


saveRDS(basesurv_total, glue(output_path,'basesurv_total.rds'))
saveRDS(for_survival_curv, glue(output_path,'for_survival_curv.rds'))


print('stage 5 완전히 끝남')