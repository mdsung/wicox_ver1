source('../settings.R')

setwd('stage3')
########################################## stage 3 #############################################
# central environment
# input : 1) loss Matrix(모든기관), 2) total_models(모든 기관)
# output : 1) loss_WIM_para_VAR
# 각 기관의 loss를 모은다.

# 경로 설정
stage3_path <- here("stage3/")
input_path <- here(stage3_path, "input/")
output_path <- here(stage3_path, "output/")

# 기본 변수 설정 로딩해줘야 함.

# loss matrix를 리스트 형태로 데려온다. 그리고 total loss 계산
allLossMatrices <- load_files("lossMatrix",input_path, as_list=TRUE)


turn2numeric <- lapply(allLossMatrices, function(x) mapply(x, FUN=as.numeric))
reconstructed_allLossMatrices <- lapply(turn2numeric, function(x) matrix(x, nrow=n_I, ncol=n_H))

total_loss <- Reduce('+', reconstructed_allLossMatrices)

# total model 로딩 필요
total_models <- load_files("total_model_",input_path,as_list=TRUE)

total_loss_i <- 1 / total_loss

# 여기는 standard weight에 해당함
standard_weights <- total_loss_i %>% apply(1,function(x) x/sum(x)) %>% t

# 1. standard beta calculation
each_W_mul_beta <- lapply(c(1:n_I), function(x) lapply(c(1:n_H), function(y) as.numeric(total_models[[y]][x,1:n_F] * standard_weights[x,y])))
WIM_standard_beta <- lapply(each_W_mul_beta, Reduce, f='+') %>% do.call(rbind,.)
saveRDS(WIM_standard_beta, glue(output_path,'WIM_standard_beta.rds'))


# total_models도 공유돼야 한다.
# 이제 각 변수별로 행렬을 만든다.

total_models_se <- lapply(total_models, function(x) x[,(n_F+1):ncol(x)])
inverse_variance_matrices <- lapply(total_models_se, function(x) 1/(x^2))

# 2. calculate E_kp : W_ki * inverse(Variance beta) --> variance adjusted weight

cal_ith_E_and_adjusted_weights <- function(std_weights, inverse_variance_matrix_list,i){
    ith_inverse_variances <- lapply(inverse_variance_matrix_list, function(x) x[i,])
    ith_standard_weights <- std_weights[i,]
    E <- lapply(c(1:n_H), function(x) ith_inverse_variances[[x]] * ith_standard_weights[x])
    sumE <- Reduce('+', E)

    Wp <- lapply(E, function(x) x / sumE)
    ith_WIM_beta <- lapply(c(1:n_H), 
            function(x) Wp[[x]] * total_models[[x]][i,1:n_F]) %>%
            Reduce('+',.)
    return(ith_WIM_beta)
}

all_variance_adjusted_beta <- lapply(c(1:n_I),
                              cal_ith_E_and_adjusted_weights, 
                              std_weights=standard_weights,
                              inverse_variance_matrix_list=inverse_variance_matrices
                              )
WIM_variance_adjusted_beta <- do.call(rbind, all_variance_adjusted_beta)
saveRDS(WIM_variance_adjusted_beta, glue(output_path, "WIM_variance_adjusted_beta.rds"))


# # loss WIM para VAR 계산 
# get_loss_WIM_para_VAR <- function(lossVARwt_list, total_models)
# {
#     n_F<- lossVARwt_list[[1]] %>% ncol
    
#     get_lossVARwt_x <- function(lossVARwt_list,i)
#     {
#         x_i <- lapply(lossVARwt_list, function(x) x[,i]) %>% do.call(cbind,.)
#         mul_result <- (loss_weights * x_i) %>% apply(MARGIN = 1, FUN=function(x) x/sum(x)) %>% t
#         mul_result
#     }
    
#     X_vectorList <- lapply(c(1:n_F), get_lossVARwt_x, lossVARwt_list=lossVARwt_list)
    
#     get_ith_column_total_model <- function(i){
#             lapply(total_models, function(x) x[,i]) %>% do.call(cbind,.)
#     }
#     ith_columnList <- lapply(c(1:n_F), get_ith_column_total_model)
    
#     lossVARwt <- lapply(seq_along(X_vectorList), function(x) X_vectorList[[x]] * ith_columnList[[x]])
    
#     # loss WIM para var
#     loss_WIM_para_VAR<- lapply(lossVARwt, rowSums) %>% do.call(cbind,.)
#     return(loss_WIM_para_VAR)
# }
                                                     

# loss_WIM_para_VAR <- get_loss_WIM_para_VAR(lossVARwt_list, total_models)
# loss_WIM_para_VAR

# loss_WIM_avg_VAR <- as.data.frame(matrix(ncol=3*2, nrow=n_F))

# for(x in 1:n_F){
#   loss_WIM_avg_VAR[x,1] <- mean(loss_WIM_para_VAR[,x])
#   loss_WIM_avg_VAR[x,2] <- quantile(loss_WIM_para_VAR[,x], probs=c(0.025))
#   loss_WIM_avg_VAR[x,3] <- quantile(loss_WIM_para_VAR[,x], probs=c(0.975))
  
#   loss_WIM_avg_VAR[x,4] <- exp(mean(loss_WIM_para_VAR[,x]))
#   loss_WIM_avg_VAR[x,5] <- exp(quantile(loss_WIM_para_VAR[,x], probs=c(0.025)))
#   loss_WIM_avg_VAR[x,6] <- exp(quantile(loss_WIM_para_VAR[,x], probs=c(0.975)))
  
# }
# loss_WIM_avg_VAR

# saveRDS(loss_WIM_para_VAR, file=glue(output_path,'loss_WIM_para_VAR.rds'))
# saveRDS(loss_WIM_avg_VAR, file=glue(output_path,'loss_WIM_avg_VAR.rds'))


print('==========================================================================================================================')
print('stage 3 is finished successfully. 단계 3이 성공적으로 종료되었습니다')
print(glue('output폴더에 WIM_standard_beta.rds와 WIM_variance_adjusted_beta.rds가 있는지 확인해주시고, stage 4의 input폴더로 복사해주십시오.'))
print("==========================================================================================================================")
