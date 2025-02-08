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

# Get the command line arguments
args <- commandArgs(trailingOnly = TRUE)

# Check if the correct number of arguments is provided
if (length(args) != 1) {
  stop("Please provide a single integer argument.")
}

# Extract the number from the arguments
node <- as.integer(args[1])

# Check if the extracted number is valid
if (is.na(node)) {
  stop("Invalid number format. Please provide a valid integer.")
}


# Load Data
full_df_harm = read_csv('/home/users/ethanroy/vanderbilt_colab/data/full_df_harm.csv')

full_profile_harm_df = read_csv('/home/users/ethanroy/vanderbilt_colab/data/full_profile_harm_df.csv')

wj_combo = full_df_harm %>% 
  select(subjectID, sessionID, Age, WJ_read_w,WJ_math_sum,
         Sex, WJ_read_C, WJ_math_C, scanner2, initial_age, age_c) %>% 
  unique()

sub_df_3obs = full_profile_harm_df %>% 
  select(subjectID,sessionID) %>% 
  unique() %>% 
  group_by(subjectID) %>% 
  mutate(nObs=n()) %>% 
  ungroup() %>% 
  select(subjectID, nObs) %>% 
  unique() %>% 
  filter(nObs >= 3)

drop_sibs = c('RC3011','RC3043','RC3069', 'LD4029', 'LD4059', 'LD4080', 'LD4081')

arc_l_df_harm = full_profile_harm_df %>% 
  ungroup() %>% 
  filter(tractID=='ARC_L') %>% 
  filter((nodeID>19)&(nodeID<80)) %>%
  dplyr::mutate(Age = as.numeric(Age),
         subjectID = as.factor(subjectID),
         sessionID = as.factor(sessionID)) %>% 
  group_by(subjectID) %>%
  dplyr::mutate(initial_age = min(Age),
         age_c = Age - min(Age),
         mean_read = mean(WJ_reading_sum),
         mean_math = mean(WJ_math_sum),
         scanner2 = as.factor(scanner2),
         nodeID_fact = as.factor(nodeID)) %>% 
  ungroup() %>% 
  mutate(mean_read = scale(mean_read, center=T, scale=F)) %>% 
  filter(!(subjectID %in% drop_sibs))

arc_l_df_harm$event = interaction(arc_l_df_harm$subjectID,arc_l_df_harm$sessionID,drop=T)
arc_l_df_harm = arc_l_df_harm %>% mutate(start.event = if_else(nodeID==20,T,F))

# Generate Null Distribution
null_mlvar_df = data.frame()

pb <- txtProgressBar(style=3)
for(i in 1:1000){
    setTxtProgressBar(pb, i/1000)
  
    Res1 <- mlVAR(arc_l_df_harm %>% 
                    filter(nodeID==node) %>%
                    group_by(sessionID) %>% # maintain temporal structure of reading  
                    mutate(read_shuff = sample(WJ_read_w),
			   dti_shuff = sample(dti_md)),
    c('dti_shuff','read_shuff'),
               idvar="subjectID", lags = c(1),scale=T,
               estimator='lmer',temporal = 'orthogonal',
    verbose=F)
  
    sumRes = summary(Res1)
  
    null_mlvar_df = null_mlvar_df %>%
      rbind(sumRes$temporal %>%
              mutate(nodeID = node,
                     perm_no = i)) 
}

outfile_name = paste0(paste0('/scratch/users/ethanroy/longitudinal_vanderbilt_colab/mlvar_perms/mlvar_perm_read_and_wm_node_',as.character(node),'.csv'))
null_mlvar_df %>% write_csv(outfile_name)


