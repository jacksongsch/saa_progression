/* Per-participant rep/visit_month prep (DATA-step form of the repo's setup),
   so the repo's by-group summary below runs on the mock UPDRS-III data. */
proc sort data=updrs_orig out=work.updrs; by participant_id; run;
data work.updrs;
  set work.updrs;
  by participant_id;
  if first.participant_id then rep = 0;
  rep + 1;
  visit_month = input(scan(visit_year_factor, 1, " "), best.) * ifn(index(visit_year_factor,"years"), 12, 1);
  mds_updrs_part_iii_chg = mds_updrs_part_iii_summary_score - baseline_score;
run;

/* --- Verbatim from analysis/saa_progression_analysis.sas (UPDRS-III block):
   summary statistics by diagnostic group, SAA status, and visit. --- */
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
