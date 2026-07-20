/* Prepared analysis rows (participant, visit, centered covariates) — the mock
   substitute for the PPMI-derived centered dataset. center_* are the repo's
   grand-mean-centered covariates; here seeded directly so the repo's predicted
   -value model below can run standalone. */
data updrs;
  length GroupID $8 SAA $8;
  infile datalines dlm='|' dsd;
  input participant_id GroupID $ SAA $ visit_year mds_updrs_part_iii_summary_score
        center_baseline center_agebase center_dxbase center_sex center_race
        center_hisp center_educlow center_educhigh LEDD;
  visit_year_factor = catx(' ', put(visit_year*12, best.), 'months');
  datalines;
101|SPD|Positive|0|20|-1.2|0.5|-0.3|0.4|-0.1|0.0|0.0|0.0|0
101|SPD|Positive|1|23|-1.2|0.5|-0.3|0.4|-0.1|0.0|0.0|0.0|150
101|SPD|Positive|2|26|-1.2|0.5|-0.3|0.4|-0.1|0.0|0.0|0.0|300
104|LRRK2 PD|Positive|0|20|0.8|-1.5|0.9|-0.6|-0.1|0.8|0.0|0.0|0
104|LRRK2 PD|Positive|1|22|0.8|-1.5|0.9|-0.6|-0.1|0.8|0.0|0.0|140
106|GBA PD|Negative|0|25|5.0|0.2|0.1|0.4|-0.1|0.0|0.0|0.6|0
106|GBA PD|Negative|1|27|5.0|0.2|0.1|0.4|-0.1|0.0|0.0|0.6|160
;
run;

/* --- Verbatim from analysis/saa_progression_analysis.sas (UPDRS-III block):
   predicted MDS-UPDRS III from the fitted mixed-model fixed effects, with the
   Dx-by-SAA group offsets. --- */
DATA predicted_updrs;
   SET updrs;

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

title "Observed vs model-predicted MDS-UPDRS III";
proc print data=predicted_updrs;
  var participant_id GroupID SAA visit_year mds_updrs_part_iii_summary_score predicted_updrs;
run;
