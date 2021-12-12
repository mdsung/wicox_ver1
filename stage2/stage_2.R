
# 기본 변수 설정 로딩해줘야 함.
# n_H, n_F, n_I, name 로딩됨
source('../settings.R') # 상위 디렉토리에 있는 settings를 불러옵니다.

# setwd('stage2')

############################################# stage 2 ########################################
# central_environment
# input : 1) total_models(모든 기관), 2) Z1Z2 data(local)
# output : loss Matrix(local)

# 경로 설정
stage2_path = here('stage2/')
input_path = here(stage2_path,'input/')
output_path = here(stage2_path,'output/')

# total_model 로드
total_models <- load_files(pattern="total_model_",path=input_path, as_list=T)

# Z1Z2 로드
Z1Z2List <- glue("Z1Z2_{name}.rds")
# load_files(pattern=Z1Z2List, path="input/", as_list=FALSE)
Z1Z2List <- readRDS(glue(input_path,Z1Z2List))
print('successfully loaded Z1Z2 list')


matrixmul <- function(vector) {
    result <- data.matrix(Z1Z2List[[2]][[1]]) %*% vector
    return(result)
}

row_list <- lapply(total_models, function(x) x[1, 1:n_F])

# 2. make loss matrix in local party
match_and_get_all_pair <- function(model_matrix, z2_list=Z1Z2List[[2]], num_it=n_I){
    "this function matches the ith model of a given institution 
     to a local ith test data
    "
    match_return_pair<- function(i){
        ith_model <- model_matrix[i, 1:n_F]
        local_ith_test_data <- z2_list[[i]]
        return(list(local_ith_test_data, ith_model))
    }
    return(lapply(c(1:num_it), match_return_pair))
}

# make every pair for every model and data
every_pairs <- lapply(total_models, match_and_get_all_pair)


# 2. define loss function 
loss_function <- function(data, beta) {
    # calculate loss. divided into two sections. Left term and the Right term
    ordered_df <- data %>% arrange(by = time)
    timeY <- ordered_df %>% select(c(time, Y))
    Xdata <- ordered_df %>% select(-c(time, Y))

    # calculate left term
    left <- exp((Xdata %>% as.matrix()) %*% beta)
    left <- timeY %>% cbind(exp = left)
    left <- left %>%
        group_by(time) %>%
        summarise(
            exp_sum = sum(exp),
            log_exp_sum = log(exp_sum),
            n = n(),
            mul_with_n = n * log_exp_sum
        )

    left_term <- left$mul_with_n %>% sum()

    # calculate right term
    death_data <- ordered_df %>% filter(Y == 1)
    timeY <- death_data %>% select(c(time, Y))
    Xdata <- death_data %>% select(-c(time, Y))

    right <- ((Xdata %>% as.matrix()) %*% beta)
    right <- timeY %>% cbind(exp_log = right)

    right_term <- right$exp_log %>% sum()

    # calculate loss
    loss <- left_term - right_term
    return(loss)
}


# 3. make loss Matrix
send_data_and_beta<- function(every_pairs_list){
    lapply(every_pairs_list, function(x) lapply(x, function(x) loss_function(x[[1]],x[[2]])))
}

allLossList <- send_data_and_beta(every_pairs)

# construct loss matrix
lossMatrix <- allLossList %>% do.call(cbind,.)


# #2. likelihood matrix 만들기
# make_matrix_function <- function(z2_list, total_model_matrix_list, i)
# {
#     # This function makes likelihood matrix
#     # 이 함수는 가능도 행렬을 만들어준다. 
#     # z2_list와 total_model_matrix_list를 인자로 받아서 i 번째에 해당하는 Z2의 데이터와 전체 모델로 결과를 산출한다. 
    
#     z2 <- z2_list[[i]] %>% filter(Y==1)
#     test_data <- z2_list[[i]] %>% select(-c("time", "Y"))
#     n_H <- total_model_matrix_list %>% length
#     timeY <- z2_list[[i]] %>% select(c("time","Y"))
#     n_F <- test_data %>% ncol
    
#     matrixmul <- function(vector){
#         result<- exp(data.matrix(test_data) %*% vector)
#         return(result)
#     }
    
#     # total_model_matrix_list에서 특정 i번째 row와 1~n_F까지의 수만 추출ㅣ
#     row_list <- lapply(total_model_matrix_list, function(x) x[i,1:n_F])

#     # make column names
#     exp_names <- map_chr(c(1:n_H), ~glue('model{.}_exp_log'))
#     log_names <- map_chr(c(1:n_H), ~ glue("model{.}_log_lp"))
#     col.names <- c(exp_names, log_names)

    
#     # test data에 대해서 row_list별로 matrix multiplication
#     exp_result <- lapply(row_list, matrixmul) %>% do.call(cbind, .)
#     log_result <- exp_result %>% log()
#     df<- cbind(exp_result, log_result) %>% as.data.frame

#     names(df) <- col.names
    
#     likelihoodMatrix <- cbind(df,timeY) %>% arrange(by=time)
#     return(likelihoodMatrix)
# }

# likelihoodMatrixList <- lapply(c(1:n_I), function(x) make_matrix_function(z2_list=Z1Z2List[[2]], total_model_matrix_list=total_models, i=x))



# name_list <- map_chr(c(1:n_I),~glue('likelihood_{name}_{.}'))
# names(likelihoodMatrixList) <- name_list


# # 3. make logsum matrix
# makeLogSumMatrix_List <- function(matrxList)
# {
    
#     # 행렬 만들어주는 함수. 
#     # logSum 행렬을 만들어준다. 
#     makelogSumMatrix <- function(matrx)
#     {
#         nrows <- matrx %>% nrow
#         cols <- (ncol(matrx) - 2) / 2
        
#         logSum <- function(mx, i)
#         {
#             # 로그 썸으로 행렬을 만들어주는 함수
            
#             rows <- nrow(mx)
            
#             newMx <- mx[i:rows,1:cols]
#             result <- newMx %>% apply(MARGIN = 2, sum) %>% log %>% as.matrix() %>% t()
#         }
        
#         df <- lapply(c(1:nrows), FUN = logSum, mx=matrx) %>% do.call(rbind, .) %>% as.data.frame()
#         ls_names <- sapply("model", FUN=paste0,c(1:cols), "_log_L_sum") %>% as.vector()
#         names(df) <- ls_names
        
#         rownames(df) <- NULL
        
#         return(df)
#     }
        

#     # L_sum1
#     result <- lapply(matrxList, makelogSumMatrix)
#     L_sum1 <- mapply(cbind, matrxList, result, SIMPLIFY=FALSE)
    
#     # L_sum2
#     n_H <- ((matrxList[[1]] %>% ncol)-2) / 2
#     ls_names <- sapply("model", FUN=paste0,c(1:n_H), "_log_L_sum") %>% as.vector()
#     L_sum2 <- lapply(L_sum1, select, append(ls_names,"time")) 

#     # L_sum3
#     L_sum3 <- lapply(L_sum2, distinct, time, .keep_all=T)
    
#     # likeli2_H dataframe
#     likeli2_H <- mapply(inner_join, matrxList, L_sum3, by="time", SIMPLIFY = FALSE)
    
#     filtered_likeli2_H <- lapply(likeli2_H, filter, Y==1)
    
#     return(filtered_likeli2_H)
# }

# logSumList <- makeLogSumMatrix_List(likelihoodMatrixList)


# # 4. loss Matrix 만드는 함수
# makeLossMatrix<- function(matrx)
# {
#     n_H <- ((matrx %>% ncol) - 2) / 3 
#     log_names <- sapply("model", FUN=paste0, c(1:n_H), "_log_lp") %>% as.vector()
#     ls_names <- sapply("model", FUN=paste0,c(1:n_H), "_log_L_sum") %>% as.vector()
    
#     result = c()
#     LSum <- matrx %>% select(ls_names)
#     LLp <- matrx %>% select(log_names)

#     result <- (LSum - LLp) %>% apply(MARGIN = 2,sum)
# #     for(i in 1:n_H){
# #         result[[i]] <- matrx %>% select(c(ls_names[[i]], log_names[[i]])) %>% apply(1, function(x) x[1] - x[2]) %>% sum
# #     }
#     return(result)
# }

# lossMatrix <- lapply(logSumList, makeLossMatrix) %>% do.call(rbind,.)
saveRDS(lossMatrix, file=glue('output/lossMatrix_{name}.rds'))


print('=============================================================================================================')
print('stage 2 is finished successfully. 단계 2가 성공적으로 종료되었습니다')
print(glue('output폴더에 lossMatrix_{name}.Rds가 있는지 확인해주시고, stage 3의 input폴더로 복사해주십시오.'))
print(glue('output폴더에 lossMatrix_{name}.Rds를 이메일로 보내주십시오'))
print("=============================================================================================================")


