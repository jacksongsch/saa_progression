/* Mock per-model ODS-style estimate tables standing in for the eight
   work.est01-work.est08 datasets the repo's PROC MIXED steps write. Shape
   matches the repo's Estimates output (Label, Estimate, StdErr, Probt). */
data work.est01;
  length Label $40; infile datalines dlm=';' dsd;
  input Label $ Estimate StdErr Probt;
  datalines;
SPD SAA+ vs. - Slope;0.07;0.54;0.90
Overall SAA+ vs. - Slope;0.32;0.51;0.53
;
run;
data work.est03;
  length Label $40; infile datalines dlm=';' dsd;
  input Label $ Estimate StdErr Probt;
  datalines;
SPD SAA+ vs. - Slope;0.11;0.30;0.71
Overall SAA+ vs. - Slope;0.05;0.28;0.86
;
run;
data work.est05;
  length Label $40; infile datalines dlm=';' dsd;
  input Label $ Estimate StdErr Probt;
  datalines;
SPD SAA+ vs. - Slope;-0.15;0.42;0.72
Overall SAA+ vs. - Slope;-0.09;0.33;0.79
;
run;
data work.est07;
  length Label $40; infile datalines dlm=';' dsd;
  input Label $ Estimate StdErr Probt;
  datalines;
SPD SAA+ vs. - Slope;0.020;0.011;0.07
Overall SAA+ vs. - Slope;0.015;0.009;0.10
;
run;

/* --- Verbatim pattern from analysis/saa_progression_analysis.sas (OUTPUT block):
   stack the per-model estimate tables with indsname=, recover each source
   model number from the dataset name, and label the outcome. --- */
data work.est;
  length model 8;
  set work.est01 work.est03 work.est05 work.est07 indsname=_dsn_;
  model = input(reverse(substr(left(reverse(_dsn_)),1,2)), best.);

  length outcome $100;
  select(model);
    when (1) do; outcome = "UPDRS-III, 7 years"; end;
    when (2) do; outcome = "UPDRS-III, all data"; end;
    when (3) do; outcome = "UPDRS-I, 7 years"; end;
    when (4) do; outcome = "UPDRS-I, all data"; end;
    when (5) do; outcome = "MoCA, 7 years"; end;
    when (6) do; outcome = "MoCA, all data"; end;
    when (7) do; outcome = "DaTscan Caudate"; end;
    when (8) do; outcome = "DaTscan Putamen"; end;
    otherwise;
  end;
run;

title "Stacked estimates with recovered model number and outcome label";
proc print data=work.est;
  var model outcome Label Estimate StdErr Probt;
run;
