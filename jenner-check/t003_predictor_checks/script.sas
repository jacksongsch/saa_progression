/* Centered-covariate prep (DATA-step form of the repo's grand-mean centering)
   so the repo's predictor-distribution and correlation checks run on the mock. */
proc sql noprint;
  select mean(age_baseline), mean(time_dx_to_baseline)
    into :m_age, :m_dx
    from updrs_orig;
quit;
proc sort data=updrs_orig out=work.updrs; by participant_id; run;
data work.updrs;
  set work.updrs;
  by participant_id;
  if first.participant_id then rep = 0;
  rep + 1;
  visit_year_n = visit_year;
  center_baseline = mds_updrs_part_iii_summary_score - baseline_score;
  center_agebase  = age_baseline - &m_age;
  center_dxbase   = time_dx_to_baseline - &m_dx;
  center_sex   = (Sex = "Female");
  center_race  = (Race = "Other");
  center_hisp  = (Ethnicity = "Hispanic or Latino");
  center_educlow  = (Education = "Less than 12 years");
  center_educhigh = (Education = "Greater than 16 years");
run;

/* --- Verbatim from analysis/saa_progression_analysis.sas (data checks):
   levels/distribution of categorical predictors and predictor correlations. --- */
title6 "Check levels and distribution of categorical predictors";
proc freq data=work.updrs;
  table Sex Race Ethnicity Education / list missing;
run;

title6 "Check correlations among predictors";
proc corr data=work.updrs pearson;
  var visit_year_n center_baseline center_agebase center_dxbase center_sex center_race center_hisp center_educlow center_educhigh LEDD;
run;
