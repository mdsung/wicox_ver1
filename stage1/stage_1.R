
source('../settings.R')
setwd('stage1')
########################################### stage 1 ####################################################
# local_environment
# input : 1) 원본데이터
# output : 1) changed data, 2) Z1Z2List 3)total_model 4)time_vector

# 초기값 설정이 필요합니다.
stage1_path <- here('stage1')
data_path <- here(stage1_path,'input/')
output_path <- here(stage1_path,'output/')

# 파일 읽어오기
df <- read_csv(paste0(data_path,file_name)) 
print('df loaded')

df_changed <- namer_function(df) #y와 time을 적어주세요. ""해주시면 안됩니다.
saveRDS(df_changed, glue(output_path,'{name}_changed.rds'))
print('changed saved')

# Z1과 Z2를 만든다.
Generate.Z1.Z2 <- function(local.data, predictor, p, m)
{   
    z1.list <- list()
    z2.list <- list()

    split <- function(data, y ,p)
    {
        z1.idx <- caret::createDataPartition(y = data[[y]], p=p, list=FALSE)
        z1<- data[z1.idx,]
        z2<- data[-z1.idx,]
        return(list(z1,z2))
    }

    for(i in 1:m){
        split(local.data, predictor, p)
        result <- split(local.data, predictor, p)

        z1.list <- append(z1.list, result[1])
        z2.list <- append(z2.list, result[2])
        if(i == m) break
        i = i + 1
    }

    return(list(z1.list, z2.list))
}

Z1Z2List<- Generate.Z1.Z2(df_changed, "Y", 0.75, n_I)
saveRDS(Z1Z2List, file = paste0(output_path, "Z1Z2_", name, ".rds"))




# 모델을 만든다.
make_model <- function(z1z2list, party_name)
{
    m <- z1z2list[[1]] %>% length
    
    # 모델을 만든다. z1z2의 리스트에 있는 z1의 1~m개의 데이터를 바탕으로
    # 모델을 만든다.
    # 모델의 이름은 cox.파티이름.i이다. i는 1~m번 iteration 하면서 적용된 수
    
    for(i in 1:m){
        assign(paste0('cox','.',party_name,'.',i), 
            coxph(Surv(time, Y) ~ . ,data=z1z2list[[1]][[i]],
            ties='breslow'), envir=.GlobalEnv)
    }
}

make_model(Z1Z2List, name) # 모델이 메모리 상에 생성됨


# coefficient matrix를 만든다.
make_coefficient_matrix <- function(z1z2list, party_name)
{
    # 이 함수의 목적은 생성된 모델들의 beta와 beta의 se를 가지는 행렬을 만든다.
    
    n_I <- z1z2list[[1]] %>% length # m은 반복횟수(iteration 횟수)
    n_F <- (z1z2list[[1]][[1]] %>% names %>% length) - 2 # feature수
    
    # 각 데이터로부터의 행렬. m*2p 모양이다
    total_model <- matrix(nrow=n_I, ncol=2*n_F)
    
    # 모델 리스트(벡터)
    model_list <- c()
    for( i in 1:n_I){
            model_list[i] <- paste0('cox.',party_name,'.',i)
    }
    
    # matrix 생성
    for(i in 1:n_I){
        for(j in 1:n_F){
            
            ij <- get(model_list[i],envir=.GlobalEnv)$coefficient[[j]]
            total_model[i,j] <- ij

            ij.ce <- summary(get(paste0('cox.',party_name,'.',i), envir=.GlobalEnv))$coefficient[j,3]
            total_model[i,j+n_F]<- ij.ce
        }
    }
    
    # 데이터프레임을 반환
    return(assign(paste0('total_model_',party_name),total_model, envir=.GlobalEnv))
}

make_coefficient_matrix(Z1Z2List, name)
get(glue('total_model_{name}')) %>% saveRDS(file=here(output_path,glue('total_model_{name}.rds')))


# time vector
time_vector_function <- function(local_data)
{
    event <- local_data %>% 
                filter(Y==1) %>% 
                select(time) %>% 
                group_by(time) %>% 
                summarise(n_events=n())
    return(event)
}


assign(glue(name,'_time'), time_vector_function((df_changed))) %>% saveRDS(file=glue(output_path,name,"_time.rds"))


print("================================================================================================")
print("================================================================================================\n")
print("stage1 is finished successfully. 단계 1이 성공적으로 종료되었습니다.")
print("output 폴더에 4개의 파일이 존재하는지 확인해주십시오.")

print(glue("output 폴더에 있는 total_model_{name}.rds를 stage2의 input 폴더에 복사해주십시오."))
print(glue("output 폴더에 있는 total_model_{name}.rds를 이메일로 보내주십시오."))

print(glue("output 폴더에 있는 {name}_changed.rds를 stage2의 input 폴더에 복사해주십시오."))
print(glue("output 폴더에 있는 Z1Z2_{name}.rds를 stage2의 input 폴더에 복사해주십시오."))

print(glue("output 폴더에 있는 {name}_time.rds를 stage4의 input 폴더에 복사해주십시오."))
print(glue("output 폴더에 있는 {name}_time.rds를 이메일로 폴더에 복사해주십시오."))

print('================================================================================================')
print("================================================================================================")

print('stage2에서 시작할 경우 working directory를 stage2 폴더로 옮겨주시기 바랍니다.')

