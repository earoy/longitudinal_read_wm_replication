# import libraries
# library(plyr)
library(dplyr)
library(tidyverse)
library(itsadug)

library(lme4)
library(broom)
library(psych)
library(mgcv)
library(gratia)
library(mlVAR)
library(ggpubr)

# icc = performance::icc
rename = dplyr::rename
summarise = dplyr::summarise
select = dplyr::select
mutate = dplyr::mutate

library(rsample)

# Load Data
full_df_harm = read_csv('/home/users/ethanroy/vanderbilt_colab/data/full_df_harm.csv')

wj_combo = full_df_harm %>% 
  select(subjectID, sessionID, Age, WJ_read_w,WJ_math_sum,
         Sex, WJ_read_C, WJ_math_C, scanner2, initial_age, age_c) %>% 
  unique()

sub_df_3obs = full_df_harm %>% 
  select(subjectID,sessionID) %>% 
  unique() %>% 
  group_by(subjectID) %>% 
  mutate(nObs=n()) %>% 
  ungroup() %>% 
  select(subjectID, nObs) %>% 
  unique() %>% 
  filter(nObs >= 3)

drop_sibs = c('RC3011','RC3043','RC3069', 'LD4029', 'LD4059', 'LD4080', 'LD4081')
  
# generate 2000 bootstrap samples pulling individuals, not rows
bs <- bootstraps(data = full_df_harm %>% filter(tractID=='ARC_L') %>% nest(-subjectID), times = 2000)


boot_diff_ci = function(df,col1,col2,alpha=0.975){
  # this approach calculates the 95% CI around mean of difference in bootstrapped edges (col1 and col2)
  ci_df = df %>% 
    dplyr::mutate(diff = df[[col1]] - df[[col2]]) %>% 
    dplyr::summarise(mean_diff = mean(diff, na.rm = TRUE),
              sd_diff = sd(diff, na.rm = TRUE),
              count = n()) %>%
    dplyr::mutate(se_diff = sd_diff / sqrt(count),
           lower.ci = mean_diff - qt(alpha,df=count-1)  * se_diff,
           upper.ci = mean_diff + qt(alpha,df=count-1)  * se_diff)
  
  return(ci_df)
}

#  dataframe for storing bootstrap model output
t1_res =data.frame(from=character(),
                   to=character(),
                   lag=double(),
                   fixed=double(),
                   SE=double(),
                   P=double(),
                   ran_sd=double(),
                   cor=double(),
                   stringsAsFactors=T)


pb <- txtProgressBar(style=3)
for (i in 1:length(bs$id)) {
  
  # setTxtProgressBar(pb, i/2000)
  
  # try catch to run model on each bootstrap sample and save
  # resulting edge weights in t1_boot
  result = tryCatch({
    
    df = as.tibble(bs$splits[[i]]) %>% unnest(cols=c(data))
    
    # run mlVAR on shuffled DF
    boot_mod = mlVAR(df,
                     c('mean_dtiMD','WJ_read_w'),
           idvar="subjectID", lags = c(1),scale=T,
           estimator='lmer',temporal = 'orthogonal')
    boot_res1 = summary(boot_mod)[[1]] %>% filter(lag==1)
    cor = summary(boot_mod)[[2]][[7]]
    boot_res1 = boot_res1 %>% mutate(cor = cor)
    # t1_res = rbind(t1_res,boot_res1)
    
  }, warning = function(w){
    # run model even with warning
    
    df = as.tibble(bs$splits[[i]]) %>% unnest(cols=c(data))
    
    # run mlVAR on shuffled DF
    boot_mod = mlVAR(df,
                     c('mean_dtiMD','WJ_read_w'),
           idvar="subjectID", lags = c(1),scale=T,
           estimator='lmer',temporal = 'orthogonal')
    
    boot_res1 = summary(boot_mod)[[1]] %>% filter(lag==1)
    cor = summary(boot_mod)[[2]][[7]]
    # print(cor)
    boot_res1 = boot_res1 %>% mutate(cor = cor)
    # t1_res = rbind(t1_res,boot_res1)
    
  }, error = function(e){
    
  },finally = {
  })
  
  # boot_res1 = summary(boot_mod)[[1]] %>% filter(lag==1)
  t1_res = rbind(t1_res,result)

}

t1_res %>% write_csv('/home/users/ethanroy/vanderbilt_colab/data/mlvar_boot_arc_l.csv')
