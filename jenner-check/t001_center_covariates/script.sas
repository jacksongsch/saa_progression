/* Per-participant rep/first/visit_month prep in a DATA step (the mock substitute
   for the repo's per-participant setup), then the repo's grand-mean CENTERING
   computation: each covariate minus its cohort mean, via the cross join to the
   single-row means subquery b. This is the centering that feeds every model. */
proc sort data=updrs_orig out=work.pre; by participant_id; run;
data work.pre;
  set work.pre;
  by participant_id;
  if first.participant_id then rep = 0;
  rep + 1;
  first = (rep = 1);
  late  = 0;
  visit_month = input(scan(visit_year_factor, 1, " "), best.) * ifn(index(visit_year_factor,"years"), 12, 1);
run;

proc sql feedback noprint;
  create table work.updrs as
    select a.*
         , a.baseline_score - b.baseline_score as center_baseline
         , a.age_baseline - b.age_baseline as center_agebase
         , a.time_dx_to_baseline - b.time_dx_to_baseline as center_dxbase
         , (a.Sex = "Female") - sex_female as center_sex
         , (a.Race = "Other") - race_other as center_race
         , (a.Ethnicity = "Hispanic or Latino") - ethnic_hisp as center_hisp
         , (a.Education = "Less than 12 years") - educ_low as center_educlow
         , (a.Education = "Greater than 16 years") - educ_high as center_educhigh
    from work.pre a ,
         (select distinct
                 mean(baseline_score) as baseline_score
               , mean(age_baseline) as age_baseline
               , mean(time_dx_to_baseline) as time_dx_to_baseline
               , mean(Sex = "Female") as sex_female
               , mean(Race = "Other") as race_other
               , mean(Ethnicity = "Hispanic or Latino") as ethnic_hisp
               , mean(Education = "Less than 12 years") as educ_low
               , mean(Education = "Greater than 16 years") as educ_high
            from work.pre ) b
    order by a.participant_id, a.rep;
quit;

title "Grand-mean-centered covariates (first 12 rows)";
proc print data=work.updrs(obs=12);
  var participant_id GroupID SAA rep visit_month center_agebase center_dxbase center_sex center_race center_hisp;
run;
