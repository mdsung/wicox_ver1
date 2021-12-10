import pandas as pd
import pickle
from pathlib import Path 
from copy import deepcopy
import re

curdir = Path.cwd()
pardir = curdir.parent
import os, sys
os.sys.path.append(pardir.as_posix())

from pydp.utils import *
# from argparse import 

# save as pickle files
input_path = Path('input/')
output_path = Path('output/')


# 문서들을 읽어오는 코드
mnty = pd.read_csv(input_path.joinpath('15130_CLRC_PTH_MNTY_20211007.csv'),sep='\t',encoding='euc-kr')
bspt = pd.read_csv(input_path.joinpath('15010_CLRC_PT_BSNF_20211007.xlsx'),engine='openpyxl')
cea = pd.read_csv(input_path.joinpath('15070_CLRC_EX_DIAG_20211007.xlsx'), engine='openpyxl')
bpth = pd.read_csv(input_path('15120_CLRC_PTH_BPSY_20211007.csv'),sep='\t',encoding='euc-kr')
mlpt = pd.read_csv(input_path('15140_CLRC_PTH_MLCR_20211007.csv'),sep='\t',encoding='euc-kr')
oprt = pd.read_csv(input_path('15160_CLRC_OPRT_NFRM_20211007.csv'),sep='\t',encoding='euc-kr')
trtm = pd.read_csv(input_path('15180_CLRC_TRTM_CASB_20211007.csv'),sep='\t',encodign='euc-kr')

# 순서대로 딕셔너리에 넣어준다.
all_files = {0: mnty, 1: bspt, 2: cea, 3: bpth, 4: mlpt, 5: oprt, 6: trtm}


########################################################## 필요한 변수만 선정 ##########################################################
def parse_data(idx):
    name = list(all_files.keys())[idx]
    original_df = all_files[name]
    
    info = dict(
        {0 : ['PT_SBST_NO', 'IMPT_HM1E_RSLT_CD','IMPT_HS2E_RSLT_CD','IMPT_HS6E_RSLT_CD','IMPT_HP2E_RSLT_CD'],
        1 : ['PT_SBST_NO','BSPT_SEX_CD','BSPT_FRST_DIAG_CD','BSPT_DEAD_YMD','BSPT_FRST_DIAG_NM','BSPT_IDGN_AGE','OVRL_SRVL_DTRN_DCNT','BSPT_STAG_CLSF_CD','BSPT_STAG_VL','BSPT_T_STAG_VL','BSPT_N_STAG_VL','BSPT_M_STAG_VL'],
        2 : ['PT_SBST_NO','CEXM_YMD','CEXM_NM','CEXM_RSLT_CONT'],
        3 : ['PT_SBST_NO','BPTH_ACPT_YMD','BPTH_SITE_CONT','BPTH_BPSY_RSLT_CONT'],
        4 : ['PT_SBST_NO','MLPT_ACPT_YMD','MLPT_MSIE_RSLT_CD','MLPT_KE2E_RSLT_CD','MLPT_KRES_RSLT_CD','MLPT_NREX_RSLT_CD','MLPT_BRME_RSLT_CD'],
        5 : ['PT_SBST_NO','OPRT_CLCN_OPRT_KIND_CD','OPRT_CURA_RSCT_CD'],
        6 : ['PT_SBST_NO','CSTR_STRT_YMD','CSTR_REGN_CD','CSTR_NT','CSTR_PRPS_CD','CSTR_CYCL_VL']}
    )
    need_cols = info[idx]
    print(name)
    return original_df[need_cols]


## seed data 만들기. with bspt 데이터. 딕셔너리 id는 1.
# 일단 seed 데이터를 만들고 이 seed에 다른 컬럼들을 붙이는 형식으로 해보자.
seed_data = deepcopy(parse_data(1))

seed_data['BSPT_SRV'] = seed_data.BSPT_DEAD_YMD.apply(lambda x : 0 if np.isnan(x) else 1)
seed_data.drop(columns=['BSPT_FRST_DIAG_NM','BSPT_DEAD_YMD'], inplace=True)

srv_cols = ['OVRL_SRVL_DTRN_DCNT','BSPT_SRV']
srv_data = deepcopy(seed_data[srv_cols])

# change this to 1 year survival
msk1 = ((srv_data['OVRL_SRVL_DTRN_DCNT'] > 365) & (srv_data['BSPT_SRV'] == 1))
msk2 = ((srv_data['OVRL_SRVL_DTRN_DCNT'] > 365) & (srv_data['BSPT_SRV'] == 0))

srv_data.loc[msk1, "BSPT_SRV" ] = 0
srv_data.loc[msk1, "OVRL_SRVL_DTRN_DCNT"] = 365
srv_data.loc[msk2, "OVRL_SRVL_DTRN_DCNT"] = 365

columns = seed_data.columns.to_list()
columns = list(set(columns) - set(srv_cols))

#순서 배치
not_srv_variables = deepcopy(seed_data[columns])
bspt = pd.concat([not_srv_variables,srv_data], axis=1)
col1 = bspt.columns.to_list()[2]
col2 = bspt.columns.to_list()
del col2[2]
col2.insert(0, col1)
bspt = bspt[col2]
categories = ['BSPT_SEX_CD','BSPT_FRST_DIAG_CD']
bspt[categories] = bspt[categories].astype('category')


import re
bspt.BSPT_FRST_DIAG_CD = [re.findall(r'C\d{2}', w)[0] for w in bspt.BSPT_FRST_DIAG_CD]
# bspt.drop(columns = 'BSPT_STAG_CLSF_CD', inplace=True)

bspt.BSPT_SEX_CD = bspt.BSPT_SEX_CD.apply(lambda x : 1 if x == 'M' else 0)
dummies = pd.get_dummies(bspt.BSPT_FRST_DIAG_CD)

bspt = bspt.drop(columns = "BSPT_FRST_DIAG_CD")
bspt = pd.concat([bspt, dummies] , axis=1)


# 1. PTH mnty는 그냥 갖다가 붙여도 될 듯.
mnty = deepcopy(parse_data(0))
mnty.drop(columns=['IMPT_HS6E_RSLT_CD','IMPT_HP2E_RSLT_CD'],inplace=True)

# baseData는 밑에 셀에서 생성됨.
mnty = baseData.merge(mnty, on='PT_SBST_NO', how='left').drop(columns='BSPT_FRST_DIAG_YMD')

mnty['IMPT_HM1E_RSLT_CD'] = mnty['IMPT_HM1E_RSLT_CD'].apply(lambda x : 1 if x == 1 else 0 )
mnty['IMPT_HS2E_RSLT_CD'] = mnty['IMPT_HS2E_RSLT_CD'].apply(lambda x : 1 if x == 1 else 0 )

mnty[['IMPT_HM1E_RSLT_CD','IMPT_HS2E_RSLT_CD']] = mnty[['IMPT_HM1E_RSLT_CD','IMPT_HS2E_RSLT_CD']].astype('category')
mnty


## 2. cea
df = deepcopy(parse_data(2))
df = df.drop(columns='CEXM_NM').rename(columns={'CEXM_RSLT_CONT':'CEA'})

df.CEXM_YMD = pd.to_datetime(df.CEXM_YMD, format='%Y%m%d')

baseData = deepcopy(all_files['15010_CLRC_PT_BSNF_20211007'])
baseData = baseData[['PT_SBST_NO','BSPT_FRST_DIAG_YMD']]

baseData['BSPT_FRST_DIAG_YMD'] = pd.to_datetime(baseData['BSPT_FRST_DIAG_YMD'], format='%Y%m%d')

df = df.merge(baseData, on='PT_SBST_NO')

df.eval('DIFF = abs(BSPT_FRST_DIAG_YMD - CEXM_YMD)', inplace=True)
minimum = df.groupby(by=['PT_SBST_NO','BSPT_FRST_DIAG_YMD'], as_index=False).min()
minimum = minimum.merge(df, on=['PT_SBST_NO','BSPT_FRST_DIAG_YMD','CEXM_YMD'], how='left')

cea_info = minimum.drop(columns=['DIFF_y','BSPT_FRST_DIAG_YMD']).rename(columns={'DIFF_x':'DIFF_CEA'})
cea_info = cea_info.sort_values(by=['PT_SBST_NO','CEA'])

cea_lst = []
for _, rows in cea_info.iterrows():
    try : 
        rows.CEA = float(rows.CEA)

    except : 
        rows.CEA = (lambda x : float(x[1:])+1 if x[0] == '>' \
            else float(x[1:]) - float(x[1:])*(.1))(rows.CEA)
    cea_lst.append(rows)
cea_info = pd.DataFrame(cea_lst)

cea_info = cea_info.drop_duplicates(['PT_SBST_NO','CEXM_YMD','DIFF_CEA'], keep='last')
cea_info = cea_info.reset_index(drop=True)
cea_info.drop(columns='CEXM_YMD',inplace=True)

cea_info.DIFF_CEA = cea_info.DIFF_CEA.dt.days
cea_info = cea_info[['PT_SBST_NO','CEA']]

cea_info = baseData.merge(cea_info, how='left')
cea_info = cea_info[['PT_SBST_NO','CEA']]

cea_info.CEA = cea_info.CEA.apply(lambda x : 0 if np.isnan(x) else x)


## 3 bpth는 그대로 사용

bpth = deepcopy(parse_data(3))

bpth['BPTH_RSLT']= list(map(int,~bpth['BPTH_BPSY_RSLT_CONT'].isna()))
bpth = bpth[['PT_SBST_NO','BPTH_RSLT']]
bpth.BPTH_RSLT = bpth.BPTH_RSLT.astype('category')

bpth = baseData.merge(bpth, on='PT_SBST_NO', how='left').drop(columns='BSPT_FRST_DIAG_YMD')


## 4 mlpt. 중복된 행이 있어서 파싱작업 진행.
mlpt = deepcopy(parse_data(4))

mlpt.drop(columns=['MLPT_KE2E_RSLT_CD','MLPT_BRME_RSLT_CD'], inplace=True)
mlpt.MLPT_ACPT_YMD = pd.to_datetime(mlpt.MLPT_ACPT_YMD,format='%Y%m%d')

merged = baseData.merge(mlpt, on='PT_SBST_NO', how='left')

dup_msk = merged.duplicated(['PT_SBST_NO','BSPT_FRST_DIAG_YMD'],keep=False)
mergeDup = merged[dup_msk].sort_values(by='PT_SBST_NO')

mergeDup = mergeDup.eval('DIFF = abs(BSPT_FRST_DIAG_YMD- MLPT_ACPT_YMD)').sort_values(by=['PT_SBST_NO','DIFF'])
mergeDup.drop_duplicates('PT_SBST_NO', keep='first',inplace=True)
mergeDup.drop(columns='DIFF', inplace=True)

mergeNoDup = merged[~dup_msk]

final_mlpt = pd.concat([mergeDup,mergeNoDup])
# 4는 이대로 사용하면 될 듯
final_mlpt.drop(columns=['BSPT_FRST_DIAG_YMD','MLPT_ACPT_YMD'], inplace=True)

# mlpt는 kres mutation은 binary화

# mutation 정보 없으면 그냥 없다고 넣는다..
def mlpt_encoder(value):
    if np.isnan(value) :
        return 0
    elif value == 1 :
        return 0
    else : 
        return 1 
    
final_mlpt.MLPT_MSIE_RSLT_CD = final_mlpt.MLPT_MSIE_RSLT_CD.apply(mlpt_encoder)
final_mlpt.MLPT_KRES_RSLT_CD = final_mlpt.MLPT_KRES_RSLT_CD.apply(mlpt_encoder)
final_mlpt.MLPT_NREX_RSLT_CD = final_mlpt.MLPT_NREX_RSLT_CD.apply(mlpt_encoder)

final_mlpt[['MLPT_MSIE_RSLT_CD','MLPT_KRES_RSLT_CD','MLPT_NREX_RSLT_CD']] = final_mlpt[['MLPT_MSIE_RSLT_CD','MLPT_KRES_RSLT_CD','MLPT_NREX_RSLT_CD']].astype('category')


## 5는 operation data
# 이거는 수술 횟수로 해야 할 것 같은데?
# 이거는 그냥 했다 안했다 여부로

oprt= deepcopy(parse_data(5))

df = pd.DataFrame(oprt.PT_SBST_NO.drop_duplicates())
onlyIDs = baseData.drop(columns='BSPT_FRST_DIAG_YMD')
df['OPRT_CNTS'] = 1
oprt = onlyIDs.merge(df, how='left')
oprt = oprt.fillna(value=0)
oprt.OPRT_CNTS = oprt.OPRT_CNTS.astype('category')


## 6번. radiation 여부로 
trtm = deepcopy(parse_data(6))

trtm.CSTR_STRT_YMD = pd.to_datetime(trtm.CSTR_STRT_YMD, format='%Y%m%d')
trtm = pd.DataFrame(trtm['PT_SBST_NO'])
trtm['TRTN_CNT'] = 1

trtm = pd.merge(baseData['PT_SBST_NO'], trtm, how='left')
trtm = trtm.fillna(value=0)
trtm = trtm.drop_duplicates(keep='first')



########################################### 여기서부터는 위의 step의 데이터들을 다 합쳐준다 ########################################
from functools import reduce 

all_processed_list = [bspt,mnty,bpth,cea_info,final_mlpt,oprt,trtm]

all_datas = reduce(lambda df1, df2 : pd.merge(df1, df2,on='PT_SBST_NO', how='left'),all_processed_list)

all_datas = all_datas.drop(columns="PT_SBST_NO")

# 컬럼 순서 변경
cols = all_datas.columns.to_list()
cols.remove('BSPT_SRV')
cols.remove('OVRL_SRVL_DTRN_DCNT')
cols

all_datas = all_datas[['BSPT_SRV','OVRL_SRVL_DTRN_DCNT',*cols]]

all_datas = all_datas.drop_duplicates(keep='first')
all_datas = all_datas.reset_index(drop=True)

all_datas.to_csv(output_path.joinpath('forSurv.csv'), header=True, index=False,sep=',')

print('step0이 성공적으로 끝났습니다. output folder에 있는 csv 파일은 step1의 input 폴더로 옮겨주세요.')
#####################################################################################################################################
# 여기까지는 데이터를 파싱해서 저장해주는 코드
# 이제부터 wicox 알고리즘을 돌리면 된다.
