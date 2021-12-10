require(repr)
require(reshape)
require(survival)
require(zoo)
require(glue)
require(caret)
require(tidyverse)
require(here)

name <- switch("NCC", #여기에 해당하는 기관의 이름을 적어주시면 됩니다. 예시 : "SEV"
    "SEV" = "H1",
    "NCC" = "H2",
    "SMC" = "H3",
    "SNH" = "H4",
    "AMC" = "H5"
)
file_name <- "forSurv2.csv" # 기관에서 생산된 WICOX 시작 전 가장 초기 raw file. stage1 input에서 사용된다.
n_F <- 4 # 생존기간, 생존여부를 제외한 feature의 수
n_I <- 200 # iteration 숫자. 현재는 200번으로 통일합니다.
n_H <- 2 # 참여 기관수
WICOX_directory <- here('../')

# 변수 이름을 ""에 기록해주십시오
time = "OVRL_SRVL_DTRN_DCNT"
y=  "BSPT_SRV"

# print settings
print(glue("the name of the institution is {name}"))
print(glue("number of features is {n_F}"))
print(glue("number of institution is {n_H}"))
print(glue("number of iteration is {n_I}"))



# functions

namer_function <- function(local_data) {
    df <- local_data
    df_Y <- df %>% select(time = {{ time }}, Y = {{ y }})
    df_X <- df %>% select(-c({{ time }}, {{ y }}))

    # rename X's
    colnames(df_X) <- 1:dim(df_X)[2] %>% purrr::map_chr(~ glue("x{.}"))
    changed_data <- bind_cols(df_Y, df_X)

    return(changed_data)
}


load_files <- function(pattern, path, as_list=FALSE) {

    # as list true일 경우 2개 이상의 데이터를 한번에 리스트로 불러온다.
    fileLists <- list.files(path)
    files <- fileLists[grep(pattern, fileLists)]
    print(glue("files are {files}"))
    full_path <- files %>% map_chr(~ glue(path, .))
    mapply(function(x, y) assign(str_sub(y, length(y), -5), readRDS(x), envir = globalenv()), full_path, files)

    if (as_list == TRUE) {
        wanted_list <- list()
        allVariables <- ls(.GlobalEnv)
        wanted_names <- allVariables[grep(pattern, allVariables)]
        print(wanted_names)
        print(glue("length of this list is : {length(wanted_names)}"))

        for (f in 1:length(wanted_names)) {
            wanted_list[[f]] <- get(wanted_names[[f]])
        }
        return(wanted_list)
    }else{

    return(readRDS(full_path))
    }
}