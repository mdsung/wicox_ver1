# load library
source("../settings.R")

# setwd("stage4")
####################################### stage 4 ############################################
# survival estimation
# local environment
# input : 1) WIM_variance_adjusted_beta, 2) local changed data, 3) time vector(모든 기관)
# output : risk share list

# 경로 설정
stage4_path <- here("stage4/")
input_path <- here(stage4_path, "input/")
output_path <- here(stage4_path, "output/")

# read times
timeVectorList <- load_files(pattern = "_time", path = input_path, as_list = T)
timeVectorList %>% length()

central_time <- timeVectorList %>%
    do.call(rbind, .) %>%
    arrange(time)
grouped <- central_time %>% group_by(time)
central_time2 <- summarise(grouped,
    n = n(),
    event_total = sum(n_events, na.rm = T)
)

WIM_beta <- load_files(pattern = "WIM_standard_beta", path = input_path, as_list = F)

get_H_risk_list <- function(original_data, LossWIMparaVAR, name) {
    
    # 먼저 time별로 순서대로 arrange해줌
    original_data <- original_data %>% arrange(by=time)

    timeY <- original_data %>% select(c(time, Y))
    Xdata <- original_data %>%
        select(-c(time, Y)) %>%
        data.matrix()
    n_I <- nrow(LossWIMparaVAR)
    name <- name

    get_row <- function(matrx, i) {
        return(matrx[i, ])
    }

    # make list of each parameters
    lossParameterList <- lapply(c(1:n_I), get_row, matrx = LossWIMparaVAR)

    # get row and original data and do matrix * vector multiplication
    getH_risk_table <- function(Xdata, row_of_parameter) {
        risk_vector <- exp(Xdata %*% row_of_parameter) %>% as.vector()
        # make exp_sum_vector
        sum_of_vector <- function(vector, i) {
            lenOfVector <- vector %>% length()
            return(sum(vector[i:lenOfVector]))
        }
        n_S <- Xdata %>% nrow()
        exp_sum_vector <- lapply(c(1:n_S), FUN = sum_of_vector, vector = risk_vector) %>% unlist()
        result <- cbind(timeY, risk_vector, exp_sum_vector) # %>% arrange(by = time)
        names(result)[3:4] <- c(paste0(name, "_exp_lp"), paste0(name, "_exp_sum"))
        return(result)
    }
    lapply(lossParameterList, FUN = getH_risk_table, Xdata = Xdata)
}

# 각 기관에서의 local data 이용
load_files("_changed", input_path, as_list = F)

# 여기서 기관별로 이름 다 바꿔야 하지 않을까?
# 나는 그냥 이런 식으로 changed_data를 객체에 저장해주기로 했다.
t <- ls()
changed_data <- get(t[grep("_changed", t)])

riskList <- get_H_risk_list(changed_data, WIM_beta, name)



get_H3_risk <- function(riskTableList, name) {
    get_H_risk_2 <- function(riskTable, name) {
        result <- riskTable %>%
            select(c(time, paste0(name, "_exp_sum"))) %>%
            distinct(time, .keep_all = T)
        return(result)
    }

    result <- lapply(riskTableList, get_H_risk_2, name = name)

    fullJoinandArrange <- function(riskTableList_modified) {
        full_join(central_time2, riskTableList_modified, by = "time") %>% arrange(by = desc(time))
    }

    lapply(result, fullJoinandArrange)
}

risk_3 <- get_H3_risk(riskList, name)


make_exp2_sum <- function(data, name) {
    data <- data %>% as.data.frame()
    exp_sum_col <- paste0(name, "_exp_sum")
    exp_sum <- data[[exp_sum_col]]

    exp_sum[1] <- ifelse(is.na(exp_sum[1]), 0, exp_sum[1])
    exp_sum <- exp_sum %>% na.locf(fromLast = F)
    new_column <- paste0(name, "_exp_sum2")
    data[[new_column]] <- exp_sum

    return(data)
}

risk_3_exp2_list <- lapply(risk_3, make_exp2_sum, name = name)

make_risk_share <- function(risk_3_exp2, name) {
    drop_this_column <- paste0(name, "_exp_sum")
    data <- risk_3_exp2 %>%
        filter(!is.na(n)) %>%
        arrange(by = time) %>%
        select(-c(drop_this_column))
    return(data)
}

risk_share_list <- lapply(risk_3_exp2_list, make_risk_share, name)


saveRDS(risk_share_list, file = glue(output_path, "{name}_standard_risk_share_list.rds"))

print("====================================================================================================================")
print("stage 4 is finished successfully. 단계 4이 성공적으로 종료되었습니다")
print(glue("output폴더에 {name}_risk_share_list.rds가 있는지 확인해주시고, stage 5의 input폴더로 복사해주십시오."))
print(glue("output폴더에 {name}_risk_share_list.rds가 있는지 확인해주시고, 이메일로 보내주십시오"))
print("====================================================================================================================")
