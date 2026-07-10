/******************************
Title: alpha-syn SAA and genetic forms with PD progression
File: Main analysis
Programmer: Xinyuan Zhang
Modified from: Eric A. Macklin 
Date start: Feb 2025
******************************/

*** Globals ***;
%let debug    = 0        ; * Flag 0/1 whether to run debugging code ;
%let check    = 0        ; * Flag 0/1 whether to run data checks ;
%let verbose  = 1        ; * Flag 0/1 indicating whether to output detailed results ;
%let pdf      = 1        ; * Flag 0/1 whether to produce PDF output ;
%let save     = 1        ; * Flag 0/1 whether to export data sets ;
%let suffix   =          ; * Suffix for file output ;
%let today    = %sysfunc(putn(%sysfunc(inputn(&SYSDATE9,date9.)),yymmddn8.))&suffix;

filename out_pdf    "Output/output_saa_main.pdf";

%sysfunc(ifc(&pdf , %str( ods pdf file=out_pdf style=pearl; ),,));
%sysfunc(ifc(&pdf , %str( ods pdf exclude all; ),,));

*** Options ***;
options label mprint nocenter pageno=1 source source2 byline msglevel=i;
%sysfunc(ifc(&debug, options mlogic symbolgen ,,));
options leftmargin=0.5in rightmargin=0.5in topmargin=0.5in bottommargin=0.5in;
options ps=57 ls=100;
options fmtsearch=(work) nofmterr;
options extendobscounter=no;
ods noproctitle;

*** Titles and Footnotes ***;
title1 "alpha-syn SAA and genetic forms with PD progression, PPMI";
title2 "Fixed effects: continuous time * (Dx * SAA, base, age, time dx, sex, race, ethn, educ, ledd); Random effects: intercepts and slopes, heteroscedastic by Dx";
title3 "Data: Data Latest 02.12.25 - Schumacher et al. 2025.xlsx";
title4 " ";
footnote1 "Xinyuan Zhang, draft results";

%sysfunc(ifc(&pdf , ods pdf exclude none ,,));


/******************************
|                             |
|          UPDRS-III          |
|                             |
******************************/
PROC IMPORT datafile="Data/data_updrs.xlsx" out=updrs_orig dbms=xlsx replace; RUN;
PROC CONTENTS data=updrs_orig varnum; RUN;

DATA updrs_orig;
   set updrs_orig;
   VAR1 = _N_;
RUN;

proc sql feedback noprint;
  create table work.updrs as 
    select a.* 
         , (a.VAR1 - min(a.VAR1) + 1) as rep 
         , a.baseline_score - b.baseline_score as center_baseline 
         , a.age_baseline - b.age_baseline as center_agebase 
         , a.time_dx_to_baseline - b.time_dx_to_baseline as center_dxbase 
         , (a.Sex = "Female") - sex_female as center_sex 
         , (a.Race = "Other") - race_other as center_race 
         , (a.Ethnicity = "Hispanic or Latino") - ethnic_hisp as center_hisp 
         , (a.Education = "Less than 12 years") - educ_low as center_educlow 
         , (a.Education = "Greater than 16 years") - educ_high as center_educhigh 
    from (select * 
               , (VAR1 = min(VAR1)) as first 
               , (min(visit_year) ne 0) as late 
               , (input(scan(visit_year_factor, 1, " "), best.) * ifn(index(visit_year_factor,"years"), 12, 1)) as visit_month 
            from work.updrs_orig 
            group by participant_id ) a , 
         (select distinct 
                 mean(baseline_score) as baseline_score 
               , mean(age_baseline) as age_baseline 
               , mean(time_dx_to_baseline) as time_dx_to_baseline 
               , mean(Sex = "Female") as sex_female 
               , mean(Race = "Other") as race_other 
               , mean(Ethnicity = "Hispanic or Latino") as ethnic_hisp 
               , mean(Education = "Less than 12 years") as educ_low 
               , mean(Education = "Greater than 16 years") as educ_high 
            from work.updrs_orig ) b  
    group by a.participant_id, a.visit_year_factor 
    order by a.participant_id, a.VAR1;
quit;

data work.updrs;
  merge work.updrs
        work.updrs(keep=participant_id first mds_updrs_part_iii_summary_score 
                 rename=(first=drop_first mds_updrs_part_iii_summary_score=mds_updrs_part_iii_base) 
                 where=(drop_first)) ;
  by participant_id;

  if not nmiss(of mds_updrs_part_iii_summary_score mds_updrs_part_iii_base) then mds_updrs_part_iii_chg = mds_updrs_part_iii_summary_score - mds_updrs_part_iii_base;
  drop drop_:;
run;


title5 "Summary statistics by diagnostic group, SAA status, and visit";
proc sort data=work.updrs out=work.temp;
  by GroupID SAA participant_id visit_month;
run;

title6 "Dx group: #BYVAL(GroupID); SAA status: #BYVAL(SAA)";
options nobyline;
proc means data=work.temp nonobs maxdec=2 fw=6 nway 
    n nmiss mean stddev min p25 p50 p75 max;
  where rep = 1;
  by GroupID SAA;
  class visit_month;
  var mds_updrs_part_iii_summary_score mds_updrs_part_iii_chg;
run;
options byline;


title5 "Data checks";
title6 "Check correspondence between visit_year and visit_month";
proc freq data=work.updrs;
  table first * visit_month * visit_year_factor * visit_year / list missing;
run;

title6 "Check follow-up of participants missing data at visit_year = 0";
proc print data=work.updrs n;
  where late;
  var VAR1 participant_id visit_year visit_year_factor;
run;

title6 "Check levels and distribution of categorical predictors";
proc freq data=work.updrs;
  table Sex Race Ethnicity Education / list missing;
run;

title6 "Check correlations among predictors";
proc corr data=work.updrs pearson;
  var visit_year center_baseline center_agebase center_dxbase center_sex center_race center_hisp center_educlow center_educhigh LEDD;
run;
title4 " ";
title5 " ";


title5 "UPDRS-III";
title6 "Data: baseline to 7 years, only first replicate at a given visit";
proc mixed data=updrs noclprint=20;
  where 0 <= visit_month <= 84;
  where same and rep = 1;
  class GroupID(ref="SPD") SAA(ref="Positive") Sex Ethnicity Race education participant_id;
  model mds_updrs_part_iii_summary_score = visit_year|GroupID|SAA 
                             visit_year|center_baseline 
                             visit_year|center_agebase 
                             visit_year|center_dxbase 
                             visit_year|center_sex 
                             visit_year|center_race 
                             visit_year|center_hisp 
                             visit_year|center_educlow 
                             visit_year|center_educhigh 
                             LEDD / solution cl ddfm=sat;
  random intercept visit_year / subject=participant_id type=un group=GroupID;
  estimate '1|GBA     SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  1  0  0 visit_year*SAA  1  0 visit_year*GroupID*SAA  1  0   0  0   0  0 / cl;
  estimate '1|GBA     SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  1  0  0 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  1   0  0   0  0 / cl;
  estimate '2|GBA     SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA -1  1   0  0   0  0 / cl;
  estimate '1|LRRK2   SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  1  0 visit_year*SAA  1  0 visit_year*GroupID*SAA  0  0   1  0   0  0 / cl;
  estimate '1|LRRK2   SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  1  0 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  0   0  1   0  0 / cl;
  estimate '2|LRRK2   SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA  0  0  -1  1   0  0 / cl;
  estimate '1|SPD     SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  0  1 visit_year*SAA  1  0 visit_year*GroupID*SAA  0  0   0  0   1  0 / cl;
  estimate '1|SPD     SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  0  1 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  0   0  0   0  1 / cl;
  estimate '2|SPD     SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA  0  0   0  0  -1  1 / cl;
  estimate '2|Overall SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -3  3 visit_year*GroupID*SAA -1  1  -1  1  -1  1 / cl divisor=3;
  estimate '3|GBA   vs. SPD SAA-  |Slope (/yr)' visit_year 0 visit_year*GroupID  1  0 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  1  0   0  0  -1  0 / cl;
  estimate '3|GBA   vs. SPD SAA+  |Slope (/yr)' visit_year 0 visit_year*GroupID  1  0 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  1   0  0   0 -1 / cl;
  estimate '3|LRRK2 vs. SPD SAA-  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  1 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  0   1  0  -1  0 / cl;
  estimate '3|LRRK2 vs. SPD SAA+  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  1 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  0   0  1   0 -1 / cl;
  ods output ConvergenceStatus = work.cvg01;
  ods output FitStatistics     = work.fit01;
  ods output CovParms          = work.cov01;
  ods output SolutionF         = work.prm01;
  ods output Tests3            = work.ss301;
  ods output Estimates         = work.est01;
run;


title6 "Data: all available data";
proc mixed data=updrs noclprint=20;
  class GroupID(ref="SPD") SAA(ref="Positive") Sex Ethnicity Race education participant_id;
  model mds_updrs_part_iii_summary_score = visit_year|GroupID|SAA 
                             visit_year|center_baseline 
                             visit_year|center_agebase 
                             visit_year|center_dxbase 
                             visit_year|center_sex 
                             visit_year|center_race 
                             visit_year|center_hisp 
                             visit_year|center_educlow 
                             visit_year|center_educhigh 
                             LEDD / solution cl ddfm=sat;
  random intercept visit_year / subject=participant_id type=un group=GroupID;
  estimate '1|GBA     SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  1  0  0 visit_year*SAA  1  0 visit_year*GroupID*SAA  1  0   0  0   0  0 / cl;
  estimate '1|GBA     SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  1  0  0 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  1   0  0   0  0 / cl;
  estimate '2|GBA     SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA -1  1   0  0   0  0 / cl;
  estimate '1|LRRK2   SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  1  0 visit_year*SAA  1  0 visit_year*GroupID*SAA  0  0   1  0   0  0 / cl;
  estimate '1|LRRK2   SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  1  0 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  0   0  1   0  0 / cl;
  estimate '2|LRRK2   SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA  0  0  -1  1   0  0 / cl;
  estimate '1|SPD     SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  0  1 visit_year*SAA  1  0 visit_year*GroupID*SAA  0  0   0  0   1  0 / cl;
  estimate '1|SPD     SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  0  1 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  0   0  0   0  1 / cl;
  estimate '2|SPD     SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA  0  0   0  0  -1  1 / cl;
  estimate '2|Overall SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -3  3 visit_year*GroupID*SAA -1  1  -1  1  -1  1 / cl divisor=3;
  estimate '3|GBA   vs. SPD SAA-  |Slope (/yr)' visit_year 0 visit_year*GroupID  1  0 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  1  0   0  0  -1  0 / cl;
  estimate '3|GBA   vs. SPD SAA+  |Slope (/yr)' visit_year 0 visit_year*GroupID  1  0 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  1   0  0   0 -1 / cl;
  estimate '3|LRRK2 vs. SPD SAA-  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  1 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  0   1  0  -1  0 / cl;
  estimate '3|LRRK2 vs. SPD SAA+  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  1 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  0   0  1   0 -1 / cl;
  ods output ConvergenceStatus = work.cvg02;
  ods output FitStatistics     = work.fit02;
  ods output CovParms          = work.cov02;
  ods output SolutionF         = work.prm02;
  ods output Tests3            = work.ss302;
  ods output Estimates         = work.est02;
run;


DATA predicted_updrs;
   SET updrs;
   where 0 <= visit_month <= 84;
   where same and rep = 1;

   predicted_updrs_0 = 21.8273 + 
                     2.4559 * visit_year + 
                     0.8505 * center_baseline + 
                     (-0.05604) * visit_year * center_baseline + 
                     0.02297 * center_agebase + 
                     0.02150 * visit_year * center_agebase + 
                     0.2555 * center_dxbase + 
                     0.1157 * visit_year * center_dxbase + 
                     (-0.1137) * center_sex + 
                     (-0.4247) * visit_year * center_sex + 
                     (-0.3511) * center_race + 
                     0.2476 * visit_year * center_race + 
                     0.7302 * center_hisp + 
                     (-0.4449) * visit_year * center_hisp + 
                     (0.1122) * center_educlow + 
                     (-0.4381) * visit_year * center_educlow + 
                     0.5573 * center_educhigh + 
                     (-0.03561) * visit_year * center_educhigh + 
                     (-0.00271) * LEDD;

   IF GroupID = "GBA PD" and SAA = "Negative" THEN predicted_updrs = predicted_updrs_0 + (-0.4181) + 0.2165 * visit_year + 
		(-0.6876) + (-0.06708) * visit_year + 
		(-1.0355) + (-0.2026) * visit_year;
   ELSE IF GroupID = "LRRK2 PD" and SAA = "Negative" THEN predicted_updrs = predicted_updrs_0 + (-0.4740) + (-0.06766) * visit_year +
		(-0.6876) + (-0.06708) * visit_year + 
		(-0.3736) + (-0.5602) * visit_year;
   ELSE IF GroupID = "SPD" and SAA = "Negative" THEN predicted_updrs = predicted_updrs_0 + (-0.6876) + (-0.06708) * visit_year;

   ELSE IF GroupID = "GBA PD" and SAA = "Positive" THEN predicted_updrs = predicted_updrs_0 + (-0.4181) + 0.2165 * visit_year;
   ELSE IF GroupID = "LRRK2 PD" and SAA = "Positive" THEN predicted_updrs = predicted_updrs_0 + (-0.4740) + (-0.06766) * visit_year;
   ELSE IF GroupID = "SPD" and SAA = "Positive" THEN predicted_updrs = predicted_updrs_0;
   
   KEEP participant_id visit_year visit_year_factor GroupID SAA center_baseline center_agebase center_dxbase 
        center_sex center_race center_hisp center_educlow center_educhigh LEDD mds_updrs_part_iii_summary_score predicted_updrs;
RUN;
PROC EXPORT data=predicted_updrs outfile="Output/predicted_data.xlsx" dbms=xlsx replace; sheet="updrs"; RUN;


/******************************
|                             |
|           UPDRS-I           |
|                             |
******************************/
title5 "UPDRS-I";
PROC IMPORT datafile="Data/data_parti.xlsx" out=parti_orig dbms=xlsx replace; RUN;
PROC CONTENTS data=parti_orig varnum; RUN;

DATA parti_orig;
   set parti_orig;
   VAR1 = _N_;
RUN;

proc sql feedback noprint;
  create table work.parti as 
    select a.* 
         , (a.VAR1 - min(a.VAR1) + 1) as rep 
         , a.baseline_score - b.baseline_score as center_baseline 
         , a.age_baseline - b.age_baseline as center_agebase 
         , a.time_dx_to_baseline - b.time_dx_to_baseline as center_dxbase 
         , (a.Sex = "Female") - sex_female as center_sex 
         , (a.Race = "Other") - race_other as center_race 
         , (a.Ethnicity = "Hispanic or Latino") - ethnic_hisp as center_hisp 
         , (a.Education = "Less than 12 years") - educ_low as center_educlow 
         , (a.Education = "Greater than 16 years") - educ_high as center_educhigh 
    from (select * 
               , (VAR1 = min(VAR1)) as first 
               , (min(visit_year) ne 0) as late 
               , (input(scan(visit_year_factor, 1, " "), best.) * ifn(index(visit_year_factor,"years"), 12, 1)) as visit_month 
            from work.parti_orig 
            group by participant_id ) a , 
         (select distinct 
                 mean(baseline_score) as baseline_score 
               , mean(age_baseline) as age_baseline 
               , mean(time_dx_to_baseline) as time_dx_to_baseline 
               , mean(Sex = "Female") as sex_female 
               , mean(Race = "Other") as race_other 
               , mean(Ethnicity = "Hispanic or Latino") as ethnic_hisp 
               , mean(Education = "Less than 12 years") as educ_low 
               , mean(Education = "Greater than 16 years") as educ_high 
            from work.parti_orig ) b  
    group by a.participant_id, a.visit_year_factor 
    order by a.participant_id, a.VAR1;
quit;

data work.parti;
  merge work.parti
        work.parti(keep=participant_id first mds_updrs_part_i_summary_score 
                 rename=(first=drop_first mds_updrs_part_i_summary_score=mds_updrs_part_i_base) 
                 where=(drop_first)) ;
  by participant_id;

  if not nmiss(of mds_updrs_part_i_summary_score mds_updrs_part_i_base) then mds_updrs_part_i_chg = mds_updrs_part_i_summary_score - mds_updrs_part_i_base;
  drop drop_:;
run;

title6 "Data: baseline to 7 years, only first replicate at a given visit";
proc mixed data=parti noclprint=20;
  where 0 <= visit_month <= 84;
  where same and rep = 1;
  class GroupID(ref="SPD") SAA(ref="Positive") Sex Ethnicity Race education participant_id;
  model mds_updrs_part_i_summary_score = visit_year|GroupID|SAA 
                             visit_year|center_baseline 
                             visit_year|center_agebase 
                             visit_year|center_dxbase 
                             visit_year|center_sex 
                             visit_year|center_race 
                             visit_year|center_hisp 
                             visit_year|center_educlow 
                             visit_year|center_educhigh 
                             LEDD / solution cl ddfm=sat;* outp=work.prd03;
  random intercept visit_year / subject=participant_id type=un group=GroupID;
  estimate '1|GBA     SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  1  0  0 visit_year*SAA  1  0 visit_year*GroupID*SAA  1  0   0  0   0  0 / cl;
  estimate '1|GBA     SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  1  0  0 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  1   0  0   0  0 / cl;
  estimate '2|GBA     SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA -1  1   0  0   0  0 / cl;
  estimate '1|LRRK2   SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  1  0 visit_year*SAA  1  0 visit_year*GroupID*SAA  0  0   1  0   0  0 / cl;
  estimate '1|LRRK2   SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  1  0 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  0   0  1   0  0 / cl;
  estimate '2|LRRK2   SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA  0  0  -1  1   0  0 / cl;
  estimate '1|SPD     SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  0  1 visit_year*SAA  1  0 visit_year*GroupID*SAA  0  0   0  0   1  0 / cl;
  estimate '1|SPD     SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  0  1 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  0   0  0   0  1 / cl;
  estimate '2|SPD     SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA  0  0   0  0  -1  1 / cl;
  estimate '2|Overall SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -3  3 visit_year*GroupID*SAA -1  1  -1  1  -1  1 / cl divisor=3;
  estimate '3|GBA   vs. SPD SAA-  |Slope (/yr)' visit_year 0 visit_year*GroupID  1  0 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  1  0   0  0  -1  0 / cl;
  estimate '3|GBA   vs. SPD SAA+  |Slope (/yr)' visit_year 0 visit_year*GroupID  1  0 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  1   0  0   0 -1 / cl;
  estimate '3|LRRK2 vs. SPD SAA-  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  1 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  0   1  0  -1  0 / cl;
  estimate '3|LRRK2 vs. SPD SAA+  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  1 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  0   0  1   0 -1 / cl;
  ods output ConvergenceStatus = work.cvg03;
  ods output FitStatistics     = work.fit03;
  ods output CovParms          = work.cov03;
  ods output SolutionF         = work.prm03;
  ods output Tests3            = work.ss303;
  ods output Estimates         = work.est03;
run;


title6 "Data: all available data";
proc mixed data=parti noclprint=20;
  class GroupID(ref="SPD") SAA(ref="Positive") Sex Ethnicity Race education participant_id;
  model mds_updrs_part_i_summary_score = visit_year|GroupID|SAA 
                             visit_year|center_baseline 
                             visit_year|center_agebase 
                             visit_year|center_dxbase 
                             visit_year|center_sex 
                             visit_year|center_race 
                             visit_year|center_hisp 
                             visit_year|center_educlow 
                             visit_year|center_educhigh 
                             LEDD / solution cl ddfm=sat;
  random intercept visit_year / subject=participant_id type=un group=GroupID;
  estimate '1|GBA     SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  1  0  0 visit_year*SAA  1  0 visit_year*GroupID*SAA  1  0   0  0   0  0 / cl;
  estimate '1|GBA     SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  1  0  0 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  1   0  0   0  0 / cl;
  estimate '2|GBA     SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA -1  1   0  0   0  0 / cl;
  estimate '1|LRRK2   SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  1  0 visit_year*SAA  1  0 visit_year*GroupID*SAA  0  0   1  0   0  0 / cl;
  estimate '1|LRRK2   SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  1  0 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  0   0  1   0  0 / cl;
  estimate '2|LRRK2   SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA  0  0  -1  1   0  0 / cl;
  estimate '1|SPD     SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  0  1 visit_year*SAA  1  0 visit_year*GroupID*SAA  0  0   0  0   1  0 / cl;
  estimate '1|SPD     SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  0  1 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  0   0  0   0  1 / cl;
  estimate '2|SPD     SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA  0  0   0  0  -1  1 / cl;
  estimate '2|Overall SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -3  3 visit_year*GroupID*SAA -1  1  -1  1  -1  1 / cl divisor=3;
  estimate '3|GBA   vs. SPD SAA-  |Slope (/yr)' visit_year 0 visit_year*GroupID  1  0 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  1  0   0  0  -1  0 / cl;
  estimate '3|GBA   vs. SPD SAA+  |Slope (/yr)' visit_year 0 visit_year*GroupID  1  0 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  1   0  0   0 -1 / cl;
  estimate '3|LRRK2 vs. SPD SAA-  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  1 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  0   1  0  -1  0 / cl;
  estimate '3|LRRK2 vs. SPD SAA+  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  1 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  0   0  1   0 -1 / cl;
  ods output ConvergenceStatus = work.cvg04;
  ods output FitStatistics     = work.fit04;
  ods output CovParms          = work.cov04;
  ods output SolutionF         = work.prm04;
  ods output Tests3            = work.ss304;
  ods output Estimates         = work.est04;
run;


DATA predicted_parti;
   SET parti;
   where 0 <= visit_month <= 84;
   where same and rep = 1;

   predicted_parti_0 = 4.5288 + 
                     0.5365 * visit_year + 
                     0.7720 * center_baseline + 
                     (-0.02975) * visit_year * center_baseline + 
                     0.009214 * center_agebase + 
                     0.004507 * visit_year * center_agebase + 
                     0.07587 * center_dxbase + 
                     (-0.01083) * visit_year * center_dxbase + 
                     (-0.04856) * center_sex + 
                     (-0.1156) * visit_year * center_sex + 
                     (-0.2223) * center_race + 
                     0.06136 * visit_year * center_race + 
                     (-1.1050) * center_hisp + 
                     0.05079 * visit_year * center_hisp + 
                     0.3197 * center_educlow + 
                     (-0.1645) * visit_year * center_educlow + 
                     (-0.1087) * center_educhigh + 
                     (-0.05095) * visit_year * center_educhigh + 
                     0.000488 * LEDD;

   IF GroupID = "GBA PD" and SAA = "Negative" THEN predicted_parti = predicted_parti_0 + 0.1363 + (-0.02808) * visit_year + 
		(-0.06338) + 0.003159 * visit_year + 
		(-0.1136) + (-0.3247) * visit_year;
   ELSE IF GroupID = "LRRK2 PD" and SAA = "Negative" THEN predicted_parti = predicted_parti_0 + 0.3533 + (-0.1799) * visit_year +
		(-0.06338) + 0.003159 * visit_year + 
		(-0.2040) + (-0.08568) * visit_year;
   ELSE IF GroupID = "SPD" and SAA = "Negative" THEN predicted_parti = predicted_parti_0 + (-0.06338) + 0.003159 * visit_year;

   ELSE IF GroupID = "GBA PD" and SAA = "Positive" THEN predicted_parti = predicted_parti_0 + 0.1363 + (-0.02808) * visit_year;
   ELSE IF GroupID = "LRRK2 PD" and SAA = "Positive" THEN predicted_parti = predicted_parti_0 + 0.3533 + (-0.1799) * visit_year;
   ELSE IF GroupID = "SPD" and SAA = "Positive" THEN predicted_parti = predicted_parti_0;
   
   KEEP participant_id visit_year visit_year_factor GroupID SAA center_baseline center_agebase center_dxbase 
        center_sex center_race center_hisp center_educlow center_educhigh LEDD mds_updrs_part_i_summary_score predicted_parti;
RUN;
PROC EXPORT data=predicted_parti outfile="Output/predicted_data.xlsx" dbms=xlsx replace; sheet="parti"; RUN;


/******************************
|                             |
|            MoCA             |
|                             |
******************************/
title5 "MoCA";
PROC IMPORT datafile="Data/data_moca.xlsx" out=moca_orig dbms=xlsx replace; RUN;
PROC CONTENTS data=moca_orig varnum; RUN;

DATA moca_orig;
   set moca_orig;
   VAR1 = _N_;
RUN;

proc sql feedback noprint;
  create table work.moca as 
    select a.* 
         , (a.VAR1 - min(a.VAR1) + 1) as rep 
         , a.baseline_score - b.baseline_score as center_baseline 
         , a.age_baseline - b.age_baseline as center_agebase 
         , a.time_dx_to_baseline - b.time_dx_to_baseline as center_dxbase 
         , (a.Sex = "Female") - sex_female as center_sex 
         , (a.Race = "Other") - race_other as center_race 
         , (a.Ethnicity = "Hispanic or Latino") - ethnic_hisp as center_hisp 
         , (a.Education = "Less than 12 years") - educ_low as center_educlow 
         , (a.Education = "Greater than 16 years") - educ_high as center_educhigh 
    from (select * 
               , (VAR1 = min(VAR1)) as first 
               , (min(visit_year) ne 0) as late 
               , (input(scan(visit_year_factor, 1, " "), best.) * ifn(index(visit_year_factor,"years"), 12, 1)) as visit_month 
            from work.moca_orig 
            group by participant_id ) a , 
         (select distinct 
                 mean(baseline_score) as baseline_score 
               , mean(age_baseline) as age_baseline 
               , mean(time_dx_to_baseline) as time_dx_to_baseline 
               , mean(Sex = "Female") as sex_female 
               , mean(Race = "Other") as race_other 
               , mean(Ethnicity = "Hispanic or Latino") as ethnic_hisp 
               , mean(Education = "Less than 12 years") as educ_low 
               , mean(Education = "Greater than 16 years") as educ_high 
            from work.moca_orig ) b  
    group by a.participant_id, a.visit_year_factor 
    order by a.participant_id, a.VAR1;
quit;

data work.moca;
  merge work.moca
        work.moca(keep=participant_id first MoCA_score 
                 rename=(first=drop_first MoCA_score=MoCA_score_base) 
                 where=(drop_first)) ;
  by participant_id;

  if not nmiss(of MoCA_score MoCA_score_base) then MoCA_score_chg = MoCA_score - MoCA_score_base;
  drop drop_:;
run;

title6 "Data: baseline to 7 years";
proc mixed data=moca noclprint=20;
  where 0 <= visit_year <= 7;
  where same and rep = 1;
  class GroupID(ref="SPD") SAA(ref="Positive") Sex Ethnicity Race education participant_id;
  model MoCA_score = visit_year|GroupID|SAA 
                             visit_year|center_baseline 
                             visit_year|center_agebase 
                             visit_year|center_dxbase 
                             visit_year|center_sex 
                             visit_year|center_race 
                             visit_year|center_hisp 
                             visit_year|center_educlow 
                             visit_year|center_educhigh 
                             LEDD / solution cl ddfm=sat;
  random intercept visit_year / subject=participant_id type=un group=GroupID;
  estimate '1|GBA     SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  1  0  0 visit_year*SAA  1  0 visit_year*GroupID*SAA  1  0   0  0   0  0 / cl;
  estimate '1|GBA     SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  1  0  0 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  1   0  0   0  0 / cl;
  estimate '2|GBA     SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA -1  1   0  0   0  0 / cl;
  estimate '1|LRRK2   SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  1  0 visit_year*SAA  1  0 visit_year*GroupID*SAA  0  0   1  0   0  0 / cl;
  estimate '1|LRRK2   SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  1  0 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  0   0  1   0  0 / cl;
  estimate '2|LRRK2   SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA  0  0  -1  1   0  0 / cl;
  estimate '1|SPD     SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  0  1 visit_year*SAA  1  0 visit_year*GroupID*SAA  0  0   0  0   1  0 / cl;
  estimate '1|SPD     SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  0  1 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  0   0  0   0  1 / cl;
  estimate '2|SPD     SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA  0  0   0  0  -1  1 / cl;
  estimate '2|Overall SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -3  3 visit_year*GroupID*SAA -1  1  -1  1  -1  1 / cl divisor=3;
  estimate '3|GBA   vs. SPD SAA-  |Slope (/yr)' visit_year 0 visit_year*GroupID  1  0 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  1  0   0  0  -1  0 / cl;
  estimate '3|GBA   vs. SPD SAA+  |Slope (/yr)' visit_year 0 visit_year*GroupID  1  0 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  1   0  0   0 -1 / cl;
  estimate '3|LRRK2 vs. SPD SAA-  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  1 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  0   1  0  -1  0 / cl;
  estimate '3|LRRK2 vs. SPD SAA+  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  1 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  0   0  1   0 -1 / cl;
  ods output ConvergenceStatus = work.cvg05;
  ods output FitStatistics     = work.fit05;
  ods output CovParms          = work.cov05;
  ods output SolutionF         = work.prm05;
  ods output Tests3            = work.ss305;
  ods output Estimates         = work.est05;
run;


title6 "Data: all available data";
proc mixed data=moca noclprint=20;
  class GroupID(ref="SPD") SAA(ref="Positive") Sex Ethnicity Race education participant_id;
  model MoCA_score = visit_year|GroupID|SAA 
                             visit_year|center_baseline 
                             visit_year|center_agebase 
                             visit_year|center_dxbase 
                             visit_year|center_sex 
                             visit_year|center_race 
                             visit_year|center_hisp 
                             visit_year|center_educlow 
                             visit_year|center_educhigh 
                             LEDD / solution cl ddfm=sat;
  random intercept visit_year / subject=participant_id type=un group=GroupID;
  estimate '1|GBA     SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  1  0  0 visit_year*SAA  1  0 visit_year*GroupID*SAA  1  0   0  0   0  0 / cl;
  estimate '1|GBA     SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  1  0  0 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  1   0  0   0  0 / cl;
  estimate '2|GBA     SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA -1  1   0  0   0  0 / cl;
  estimate '1|LRRK2   SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  1  0 visit_year*SAA  1  0 visit_year*GroupID*SAA  0  0   1  0   0  0 / cl;
  estimate '1|LRRK2   SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  1  0 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  0   0  1   0  0 / cl;
  estimate '2|LRRK2   SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA  0  0  -1  1   0  0 / cl;
  estimate '1|SPD     SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  0  1 visit_year*SAA  1  0 visit_year*GroupID*SAA  0  0   0  0   1  0 / cl;
  estimate '1|SPD     SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  0  1 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  0   0  0   0  1 / cl;
  estimate '2|SPD     SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA  0  0   0  0  -1  1 / cl;
  estimate '2|Overall SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -3  3 visit_year*GroupID*SAA -1  1  -1  1  -1  1 / cl divisor=3;
  estimate '3|GBA   vs. SPD SAA-  |Slope (/yr)' visit_year 0 visit_year*GroupID  1  0 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  1  0   0  0  -1  0 / cl;
  estimate '3|GBA   vs. SPD SAA+  |Slope (/yr)' visit_year 0 visit_year*GroupID  1  0 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  1   0  0   0 -1 / cl;
  estimate '3|LRRK2 vs. SPD SAA-  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  1 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  0   1  0  -1  0 / cl;
  estimate '3|LRRK2 vs. SPD SAA+  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  1 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  0   0  1   0 -1 / cl;
  ods output ConvergenceStatus = work.cvg06;
  ods output FitStatistics     = work.fit06;
  ods output CovParms          = work.cov06;
  ods output SolutionF         = work.prm06;
  ods output Tests3            = work.ss306;
  ods output Estimates         = work.est06;
run;


DATA predicted_moca;
   SET moca;
   where 0 <= visit_year <= 7;
   where same and rep = 1;

   predicted_moca_0 = 26.7174 + 
                     (-0.1795) * visit_year + 
                     0.7732 * center_baseline + 
                     (-0.03199) * visit_year * center_baseline + 
                     (-0.02939) * center_agebase + 
                     (-0.01956) * visit_year * center_agebase + 
                     0.02570 * center_dxbase + 
                     (-0.00549) * visit_year * center_dxbase + 
                     0.1999 * center_sex + 
                     0.01965 * visit_year * center_sex + 
                     (-0.4078) * center_race + 
                     (-0.1951) * visit_year * center_race + 
                     (-0.3811) * center_hisp + 
                     0.05428 * visit_year * center_hisp + 
                     (-0.06306) * center_educlow + 
                     (-0.1402) * visit_year * center_educlow + 
                     0.09974 * center_educhigh + 
                     0.01146 * visit_year * center_educhigh + 
                     0.000226 * LEDD;

   IF GroupID = "GBA PD" and SAA = "Negative" THEN predicted_moca = predicted_moca_0 + (-0.1395) + (-0.1007) * visit_year + 
		0.06975 + (-0.1554) * visit_year + 
		1.1299 + 0.2415 * visit_year;
   ELSE IF GroupID = "LRRK2 PD" and SAA = "Negative" THEN predicted_moca = predicted_moca_0 + 0.08027 + 0.1266 * visit_year +
		0.06975 + (-0.1554) * visit_year + 
		0.1040 + 0.2378 * visit_year;
   ELSE IF GroupID = "SPD" and SAA = "Negative" THEN predicted_moca = predicted_moca_0 + 0.06975 + (-0.1554) * visit_year;

   ELSE IF GroupID = "GBA PD" and SAA = "Positive" THEN predicted_moca = predicted_moca_0 + (-0.1395) + (-0.1007) * visit_year;
   ELSE IF GroupID = "LRRK2 PD" and SAA = "Positive" THEN predicted_moca = predicted_moca_0 + 0.08027 + 0.1266 * visit_year;
   ELSE IF GroupID = "SPD" and SAA = "Positive" THEN predicted_moca = predicted_moca_0;
   
   KEEP participant_id visit_year visit_year_factor GroupID SAA center_baseline center_agebase center_dxbase 
        center_sex center_race center_hisp center_educlow center_educhigh LEDD MoCA_score predicted_moca;
RUN;
PROC EXPORT data=predicted_moca outfile="Output/predicted_data.xlsx" dbms=xlsx replace; sheet="moca"; RUN;


/******************************
|                             |
|           DaTSCan           |
|                             |
******************************/
PROC IMPORT datafile="Data/data_datscan.xlsx" out=datscan_orig dbms=xlsx replace; RUN;
PROC CONTENTS data=datscan_orig varnum; RUN;

DATA datscan_orig;
   set datscan_orig;
   VAR1 = _N_;
RUN;

proc sql feedback noprint;
  create table work.datscan as 
    select a.* 
         , (a.VAR1 - min(a.VAR1) + 1) as rep 
         , a.baseline_caudate - b.baseline_caudate as center_caudate 
         , a.baseline_putamen - b.baseline_putamen as center_putamen 
         , a.age_baseline - b.age_baseline as center_agebase 
         , a.time_dx_to_baseline - b.time_dx_to_baseline as center_dxbase 
         , (a.Sex = "Female") - sex_female as center_sex 
         , (a.Race = "Other") - race_other as center_race 
         , (a.Ethnicity = "Hispanic or Latino") - ethnic_hisp as center_hisp 
         , (a.Education = "Less than 12 years") - educ_low as center_educlow 
         , (a.Education = "Greater than 16 years") - educ_high as center_educhigh 
    from (select * 
               , (VAR1 = min(VAR1)) as first 
               , (min(visit_year) ne 0) as late 
               , (input(scan(visit_year_factor, 1, " "), best.) * ifn(index(visit_year_factor,"years"), 12, 1)) as visit_month 
            from work.datscan_orig 
            group by participant_id ) a , 
         (select distinct 
                 mean(baseline_caudate) as baseline_caudate 
               , mean(baseline_putamen) as baseline_putamen 
               , mean(age_baseline) as age_baseline 
               , mean(time_dx_to_baseline) as time_dx_to_baseline 
               , mean(Sex = "Female") as sex_female 
               , mean(Race = "Other") as race_other 
               , mean(Ethnicity = "Hispanic or Latino") as ethnic_hisp 
               , mean(Education = "Less than 12 years") as educ_low 
               , mean(Education = "Greater than 16 years") as educ_high 
            from work.datscan_orig ) b  
    group by a.participant_id, a.visit_year_factor 
    order by a.participant_id, a.VAR1;
quit;

data work.datscan;
  merge work.datscan
        work.datscan(keep=participant_id first sbr_caudate sbr_putamen
                 rename=(first=drop_first sbr_caudate=sbr_caudate_base sbr_putamen=sbr_putamen_base) 
                 where=(drop_first)) ;
  by participant_id;

  if not nmiss(of sbr_caudate sbr_caudate_base) then sbr_caudate_chg = sbr_caudate - sbr_caudate_base;
  if not nmiss(of sbr_putamen sbr_putamen_base) then sbr_putamen_chg = sbr_putamen - sbr_putamen_base;
  drop drop_:;
run;


title5 "Caudate";
title6 "Data: all available data (5 years)";
proc mixed data=datscan noclprint=20;
  where same and rep = 1;
  class GroupID(ref="SPD") SAA(ref="Positive") Sex Ethnicity Race education participant_id;
  model sbr_caudate = visit_year|GroupID|SAA 
                             visit_year|center_caudate  
                             visit_year|center_agebase 
                             visit_year|center_dxbase 
                             visit_year|center_sex 
                             visit_year|center_race 
                             visit_year|center_hisp 
                             visit_year|center_educlow 
                             visit_year|center_educhigh 
                             LEDD / solution cl ddfm=sat;
  random intercept visit_year / subject=participant_id type=un group=GroupID;
  estimate '1|GBA     SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  1  0  0 visit_year*SAA  1  0 visit_year*GroupID*SAA  1  0   0  0   0  0 / cl;
  estimate '1|GBA     SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  1  0  0 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  1   0  0   0  0 / cl;
  estimate '2|GBA     SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA -1  1   0  0   0  0 / cl;
  estimate '1|LRRK2   SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  1  0 visit_year*SAA  1  0 visit_year*GroupID*SAA  0  0   1  0   0  0 / cl;
  estimate '1|LRRK2   SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  1  0 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  0   0  1   0  0 / cl;
  estimate '2|LRRK2   SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA  0  0  -1  1   0  0 / cl;
  estimate '1|SPD     SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  0  1 visit_year*SAA  1  0 visit_year*GroupID*SAA  0  0   0  0   1  0 / cl;
  estimate '1|SPD     SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  0  1 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  0   0  0   0  1 / cl;
  estimate '2|SPD     SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA  0  0   0  0  -1  1 / cl;
  estimate '2|Overall SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -3  3 visit_year*GroupID*SAA -1  1  -1  1  -1  1 / cl divisor=3;
  estimate '3|GBA   vs. SPD SAA-  |Slope (/yr)' visit_year 0 visit_year*GroupID  1  0 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  1  0   0  0  -1  0 / cl;
  estimate '3|GBA   vs. SPD SAA+  |Slope (/yr)' visit_year 0 visit_year*GroupID  1  0 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  1   0  0   0 -1 / cl;
  estimate '3|LRRK2 vs. SPD SAA-  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  1 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  0   1  0  -1  0 / cl;
  estimate '3|LRRK2 vs. SPD SAA+  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  1 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  0   0  1   0 -1 / cl;
  ods output ConvergenceStatus = work.cvg07;
  ods output FitStatistics     = work.fit07;
  ods output CovParms          = work.cov07;
  ods output SolutionF         = work.prm07;
  ods output Tests3            = work.ss307;
  ods output Estimates         = work.est07;
run;

title5 "Putamen";
title6 "Data: all available data (5 years)";
proc mixed data=datscan noclprint=20;
  where same and rep = 1;
  class GroupID(ref="SPD") SAA(ref="Positive") Sex Ethnicity Race education participant_id;
  model sbr_putamen = visit_year|GroupID|SAA 
                             visit_year|center_putamen 
                             visit_year|center_agebase 
                             visit_year|center_dxbase 
                             visit_year|center_sex 
                             visit_year|center_race 
                             visit_year|center_hisp 
                             visit_year|center_educlow 
                             visit_year|center_educhigh 
                             LEDD / solution cl ddfm=sat;
  random intercept visit_year / subject=participant_id type=un group=GroupID;
  estimate '1|GBA     SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  1  0  0 visit_year*SAA  1  0 visit_year*GroupID*SAA  1  0   0  0   0  0 / cl;
  estimate '1|GBA     SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  1  0  0 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  1   0  0   0  0 / cl;
  estimate '2|GBA     SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA -1  1   0  0   0  0 / cl;
  estimate '1|LRRK2   SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  1  0 visit_year*SAA  1  0 visit_year*GroupID*SAA  0  0   1  0   0  0 / cl;
  estimate '1|LRRK2   SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  1  0 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  0   0  1   0  0 / cl;
  estimate '2|LRRK2   SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA  0  0  -1  1   0  0 / cl;
  estimate '1|SPD     SAA-        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  0  1 visit_year*SAA  1  0 visit_year*GroupID*SAA  0  0   0  0   1  0 / cl;
  estimate '1|SPD     SAA+        |Slope (/yr)' visit_year 1 visit_year*GroupID  0  0  1 visit_year*SAA  0  1 visit_year*GroupID*SAA  0  0   0  0   0  1 / cl;
  estimate '2|SPD     SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -1  1 visit_year*GroupID*SAA  0  0   0  0  -1  1 / cl;
  estimate '2|Overall SAA+ vs. -  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  0  0 visit_year*SAA -3  3 visit_year*GroupID*SAA -1  1  -1  1  -1  1 / cl divisor=3;
  estimate '3|GBA   vs. SPD SAA-  |Slope (/yr)' visit_year 0 visit_year*GroupID  1  0 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  1  0   0  0  -1  0 / cl;
  estimate '3|GBA   vs. SPD SAA+  |Slope (/yr)' visit_year 0 visit_year*GroupID  1  0 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  1   0  0   0 -1 / cl;
  estimate '3|LRRK2 vs. SPD SAA-  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  1 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  0   1  0  -1  0 / cl;
  estimate '3|LRRK2 vs. SPD SAA+  |Slope (/yr)' visit_year 0 visit_year*GroupID  0  1 -1 visit_year*SAA  0  0 visit_year*GroupID*SAA  0  0   0  1   0 -1 / cl;
  ods output ConvergenceStatus = work.cvg08;
  ods output FitStatistics     = work.fit08;
  ods output CovParms          = work.cov08;
  ods output SolutionF         = work.prm08;
  ods output Tests3            = work.ss308;
  ods output Estimates         = work.est08;
run;


DATA predicted_datscan;
	SET datscan;
	where same and rep = 1;

	/*caudate*/
   predicted_caudate_0 = 1.9269 + 
                     (-0.1255) * visit_year + 
                     0.9468 * center_caudate + 
                     (-0.07585) * visit_year * center_caudate + 
                     0.000188 * center_agebase + 
                     0.000118 * visit_year * center_agebase + 
                     0.000996 * center_dxbase + 
                     0.002828 * visit_year * center_dxbase + 
                     (-0.00557) * center_sex + 
                     (-0.00499) * visit_year * center_sex + 
                     0.02259 * center_race + 
                     (-0.00809) * visit_year * center_race + 
                     0.006087 * center_hisp + 
                     0.01652 * visit_year * center_hisp + 
                     (-0.04463) * center_educlow + 
                     0.005273 * visit_year * center_educlow + 
                     (-0.02040) * center_educhigh + 
                     0.004763 * visit_year * center_educhigh + 
                     (-0.00003) * LEDD;

   IF GroupID = "GBA PD" and SAA = "Negative" THEN predicted_caudate = predicted_caudate_0 + 0.01956 + (-0.01651) * visit_year + 
		0.03278 + 0.007197 * visit_year + 
		(-0.06150) + 0.02425 * visit_year;
   ELSE IF GroupID = "LRRK2 PD" and SAA = "Negative" THEN predicted_caudate = predicted_caudate_0 + 0.01078 + (-0.00510) * visit_year +
		0.03278 + 0.007197 * visit_year + 
		(-0.00974) + 0.01419 * visit_year;
   ELSE IF GroupID = "SPD" and SAA = "Negative" THEN predicted_caudate = predicted_caudate_0 + 0.03278 + 0.007197 * visit_year;

   ELSE IF GroupID = "GBA PD" and SAA = "Positive" THEN predicted_caudate = predicted_caudate_0 + 0.01956 + (-0.01651) * visit_year;
   ELSE IF GroupID = "LRRK2 PD" and SAA = "Positive" THEN predicted_caudate = predicted_caudate_0 + 0.01078 + (-0.00510) * visit_year;
   ELSE IF GroupID = "SPD" and SAA = "Positive" THEN predicted_caudate = predicted_caudate_0;
   
	/*putamen*/
   predicted_putamen_0 = 0.7819 + 
                     (-0.06350) * visit_year + 
                     0.9340 * center_putamen + 
                     (-0.1180) * visit_year * center_putamen + 
                     (-0.00021) * center_agebase + 
                     0.000355 * visit_year * center_agebase + 
                     0.001076 * center_dxbase + 
                     0.000932 * visit_year * center_dxbase + 
                     (-0.00666) * center_sex + 
                     (-0.00025) * visit_year * center_sex + 
                     0.008882 * center_race + 
                     (-0.00171) * visit_year * center_race + 
                     0.002028 * center_hisp + 
                     0.01383 * visit_year * center_hisp + 
                     (-0.00534) * center_educlow + 
                     (-0.00065) * visit_year * center_educlow + 
                     (-0.00609) * center_educhigh + 
                     0.003141 * visit_year * center_educhigh + 
                     0 * LEDD;

   IF GroupID = "GBA PD" and SAA = "Negative" THEN predicted_putamen = predicted_putamen_0 + 0.01472 + (-0.00386) * visit_year + 
		0.03102 + 0.01239 * visit_year + 
		(-0.04499) + (-0.00329) * visit_year;
   ELSE IF GroupID = "LRRK2 PD" and SAA = "Negative" THEN predicted_putamen = predicted_putamen_0 + 0.007312 + (-0.00471) * visit_year +
		0.03102 + 0.01239 * visit_year + 
		(-0.00611) + (-0.00675) * visit_year;
   ELSE IF GroupID = "SPD" and SAA = "Negative" THEN predicted_putamen = predicted_putamen_0 + 0.03102 + 0.01239 * visit_year;

   ELSE IF GroupID = "GBA PD" and SAA = "Positive" THEN predicted_putamen = predicted_putamen_0 + 0.01472 + (-0.00386) * visit_year;
   ELSE IF GroupID = "LRRK2 PD" and SAA = "Positive" THEN predicted_putamen = predicted_putamen_0 + 0.007312 + (-0.00471) * visit_year;
   ELSE IF GroupID = "SPD" and SAA = "Positive" THEN predicted_putamen = predicted_putamen_0;
   
   KEEP participant_id visit_year visit_year_factor GroupID SAA center_caudate center_putamen center_agebase center_dxbase 
        center_sex center_race center_hisp center_educlow center_educhigh LEDD sbr_caudate sbr_putamen predicted_caudate predicted_putamen;
RUN;
PROC EXPORT data=predicted_datscan outfile="Output/predicted_data.xlsx" dbms=xlsx replace; sheet="datscan"; RUN;


/******************************
|                             |
|           OUTPUT            |
|                             |
******************************/
title4 " ";
title5 " ";
title6 " ";
data work.cvg;
  length model 8;
  set work.cvg01-work.cvg08 indsname=_dsn_;
  model = input(reverse(substr(left(reverse(_dsn_)),1,2)), best.);
run;

data work.fit;
  length model 8;
  set work.fit01-work.fit08 indsname=_dsn_;
  model = input(reverse(substr(left(reverse(_dsn_)),1,2)), best.);

  length stat $4;
  if Descr = "-2 Res Log Likelihood" then stat = "-2LL";
  else                                    stat = scan(Descr,1," ");
run;

proc transpose data=work.fit out=work.fit(drop=_NAME_);
  by model;
  id stat;
  var Value;
run;

data work.cov;
  length model 8;
  set work.cov01-work.cov08 indsname=_dsn_;
  model = input(reverse(substr(left(reverse(_dsn_)),1,2)), best.);

  length Parm $24;
  Parm = catx(" ", scan(Group,2," "), CovParm);
run;

proc transpose data=work.cov out=work.cov(drop=_NAME_);
  by model;
  id Parm;
  var Estimate;
run;

data work.prm;
  length model 8;
  set work.prm01-work.prm08 indsname=_dsn_;
  model = input(reverse(substr(left(reverse(_dsn_)),1,2)), best.);
run;

data work.ss3;
  length model 8;
  set work.ss301-work.ss308 indsname=_dsn_;
  model = input(reverse(substr(left(reverse(_dsn_)),1,2)), best.);
  obs = _N_;
run;

data work.est;
  length model 8;
  set work.est01-work.est08 indsname=_dsn_;
  model = input(reverse(substr(left(reverse(_dsn_)),1,2)), best.);
run;

data work.ests;
  merge work.cvg 
        work.fit 
        work.est 
/*        work.obs */
        work.cov ;
  by model;

  length comp 8 trt_comp $24 vst_comp $24 type_num month 8;
  type_num = input(scan(label,1,'|'), best.);
  comp = (index(label," vs. ") > 0);
  trt_comp = scan(label,2,'|');
  vst_comp = scan(label,3,'|');
  if vst_comp ne: "Slope" then month = input(scan(vst_comp,2," "), best.);
  if type_num > 1 then pval = Probt;

  if first.model then stmt = 0;
  stmt + 1;

  length outcome $100;
  select(model);
    when (1) do;
               outcome  = "UPDRS-III, 7 years";
             end;
    when (2) do;
               outcome  = "UPDRS-III, all data";
             end;
    when (3) do;
               outcome  = "UPDRS-I, 7 years";
             end;
    when (4) do;
               outcome  = "UPDRS-I, all data";
             end;
    when (5) do;
               outcome  = "MoCA, 7 years";
             end;
    when (6) do;
               outcome  = "MoCA, all data";
             end;
    when (7) do;
               outcome  = "DaTscan Caudate";
             end;
    when (8) do;
               outcome  = "DaTscan Putamen";
             end;
  end;
run;

title5 "Outcome: #BYVAL(outcome)";
options nobyline;
proc report data=work.ests nowd headline split="@" spanrows missing;
  by model outcome;
  column model trt_comp type_num vst_comp (Estimate StdErr) ("_95% CI_" Lower Upper) pval;
  define model    / order order=internal noprint;
  define trt_comp / order order=data spacing=0 width=28 "Dx / Contrast"   style=[width=5.0cm];
  define type_num / order noprint;
  define vst_comp / order order=data width=14 "Visit / Slope"             style=[width=3.0cm];
  define Estimate / display format=8.3 "Mean or Diff"                     style=[width=2.0cm];
  define StdErr   / display format=6.3 "SE"                               style=[width=1.5cm];
  define Lower    / display format=6.3 "Lower"                            style=[width=1.5cm];
  define Upper    / display format=6.3 "Upper"                            style=[width=1.5cm];
  define pval     / display format=pvalue6.3 "P value"                    style=[width=1.5cm];
  break after type_num / skip;
run;
options byline;

%sysfunc(ifc(&pdf , ods pdf close ,,));

