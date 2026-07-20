/* cap input rows for the captured run */
options obs=100;

/* Mock UPDRS-III longitudinal input standing in for PPMI Data/data_updrs.xlsx
   (source data is access-controlled and not redistributed by the repo).
   Column shape matches what saa_progression_analysis.sas reads: participant_id,
   GroupID, SAA, visit_year, visit_year_factor, demographics, baseline_score,
   LEDD, and the mds_updrs_part_iii_summary_score outcome. Value ranges follow the
   repo's published table1_demographics.csv (age ~60-68, baseline UPDRS-III ~20).
   Pipe-delimited so category labels with embedded spaces load cleanly. */
data updrs_orig;
  length participant_id 8 GroupID $8 SAA $8 Sex $6 Race $8 Ethnicity $20 Education $22
         age_baseline 8 time_dx_to_baseline 8 baseline_score 8 visit_year 8 visit_year_factor $12 LEDD 8
         mds_updrs_part_iii_summary_score 8;
  infile datalines dlm='|' dsd;
  input participant_id GroupID $ SAA $ Sex $ Race $ Ethnicity $ Education $
        age_baseline time_dx_to_baseline baseline_score visit_year visit_year_factor $ LEDD
        mds_updrs_part_iii_summary_score;
  datalines;
101|SPD|Positive|Male|White|Not Hispanic|12-16 years|62|0.3|20|0|0 months|0|20
101|SPD|Positive|Male|White|Not Hispanic|12-16 years|62|0.3|20|1|12 months|150|23
101|SPD|Positive|Male|White|Not Hispanic|12-16 years|62|0.3|20|2|24 months|300|26
101|SPD|Positive|Male|White|Not Hispanic|12-16 years|62|0.3|20|3|36 months|320|28
102|SPD|Positive|Female|White|Not Hispanic|Greater than 16 years|58|0.5|18|0|0 months|0|18
102|SPD|Positive|Female|White|Not Hispanic|Greater than 16 years|58|0.5|18|1|12 months|100|20
102|SPD|Positive|Female|White|Not Hispanic|Greater than 16 years|58|0.5|18|2|24 months|250|22
103|SPD|Negative|Male|White|Not Hispanic|12-16 years|67|0.6|19|0|0 months|0|19
103|SPD|Negative|Male|White|Not Hispanic|12-16 years|67|0.6|19|1|12 months|180|21
103|SPD|Negative|Male|White|Not Hispanic|12-16 years|67|0.6|19|2|24 months|260|24
104|LRRK2 PD|Positive|Female|White|Hispanic or Latino|12-16 years|60|1.9|20|0|0 months|0|20
104|LRRK2 PD|Positive|Female|White|Hispanic or Latino|12-16 years|60|1.9|20|1|12 months|140|22
104|LRRK2 PD|Positive|Female|White|Hispanic or Latino|12-16 years|60|1.9|20|2|24 months|240|25
105|LRRK2 PD|Negative|Female|Other|Hispanic or Latino|Less than 12 years|68|2.4|17|0|0 months|0|17
105|LRRK2 PD|Negative|Female|Other|Hispanic or Latino|Less than 12 years|68|2.4|17|1|12 months|90|19
105|LRRK2 PD|Negative|Female|Other|Hispanic or Latino|Less than 12 years|68|2.4|17|2|24 months|200|20
106|GBA PD|Positive|Male|White|Not Hispanic|Greater than 16 years|61|1.2|25|0|0 months|0|25
106|GBA PD|Positive|Male|White|Not Hispanic|Greater than 16 years|61|1.2|25|1|12 months|160|27
106|GBA PD|Positive|Male|White|Not Hispanic|Greater than 16 years|61|1.2|25|2|24 months|300|30
107|GBA PD|Negative|Male|White|Not Hispanic|12-16 years|66|1.0|20|0|0 months|0|20
107|GBA PD|Negative|Male|White|Not Hispanic|12-16 years|66|1.0|20|1|12 months|120|22
;
run;
