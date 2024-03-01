LIBNAME mylib '/home/u49823291/sasuser.v94/Projekt';

proc import out=WORK.cr_loan datafile='/home/u49823291/sasuser.v94/Projekt/cr_loan.csv' dbms=CSV replace;
   getnames=YES;
   delimiter=',';
run;

proc print data=WORK.cr_loan(obs=5);
run;

proc sql;
   select COUNT(*) as n_observations
   from WORK.cr_loan;
quit;

proc contents data=WORK.cr_loan;
run;

/* Dropping duplicates */

proc sort data=WORK.cr_loan out=WORK.cr_loan nodupkey;
   by _ALL_;
run;

title "Number of observations after removing duplicates";

proc sql;
   select COUNT(*) as n_observations
   from WORK.cr_loan;
quit;

title;

/* Univariate analysis */

/* Checking for missing values */

proc means data=WORK.cr_loan nmiss noprint;
   var _numeric_;
   output out=WORK.missing_counts n=miss_count;
run;

/* Dealing with missing data */

data WORK.cr_loan;
   set WORK.cr_loan;
   if MISSING(loan_int_rate) then DELETE;
run;

proc summary data=WORK.cr_loan nway missing;
   var person_emp_length;
   output out=WORK.emp_length_median median=emp_length_median;
run;

data work.emp_length_median;
set work.emp_length_median(keep=emp_length_median);
run;

data WORK.cr_loan;
   set WORK.cr_loan;
   if missing(person_emp_length) then person_emp_length = 4;
run;

title "Number of observations after removing missing data";

proc sql;
   select COUNT(*) as n_observations
   from WORK.cr_loan;
quit;

title;

data cr_loan(drop=emp_length_median);
   set WORK.cr_loan;
run;

/* Descriptive statistics */

proc univariate data=cr_loan;
   var _numeric_;
   cdfplot _numeric_;
run;

ods graphics on;
proc univariate data=work.cr_loan noprint;
qqplot _numeric_ /normal(mu=est sigma=est);
run;
ods graphics off;

proc freq data=WORK.cr_loan;
   tables _character_;
run;

/* Define macro for histogram generation */
%macro create_histograms(data=, out=, vars=);

    %let nvars = %sysfunc(countw(&vars));

    %do i = 1 %to &nvars;
    
        %let var = %scan(&vars, &i);

        proc sgplot data=&data;
            histogram &var;
            xaxis label="&var";
            yaxis label="Frequency";
            title "Histogram for &var";
        run;

    %end;

%mend;

%create_histograms(data=WORK.cr_loan, out=WORK.histograms, vars=loan_status person_age person_income person_emp_length loan_amnt loan_int_rate loan_percent_income cb_person_cred_hist_length);

/* Removing anomalies */
data WORK.cr_loan;
   set WORK.cr_loan;
   where person_emp_length <= 60;
run;

data WORK.cr_loan;
   set WORK.cr_loan;
   where person_age <= 100;
run;

title "Number of observations after removing anomalies";

proc sql;
   select count(*) as n_observations
   from WORK.cr_loan;
quit;

title;

/* Define macro for boxplot generation */
%macro create_boxplots(data=, out=, vars=);

    %let nvars = %sysfunc(countw(&vars));

    %do i = 1 %to &nvars;

        %let var = %scan(&vars, &i);
        
        proc sgplot data=&data;
            vbox &var / category=loan_status;
            xaxis label="&var";
            yaxis label="Value";
            title "Boxplot for &var";
        run;

    %end;

%mend;

/* Call the macro to create boxplots */
%create_boxplots(data=WORK.cr_loan, out=WORK.boxplots, vars=person_age person_income person_emp_length loan_amnt loan_int_rate loan_percent_income cb_person_cred_hist_length);


/* Define macro for countplot generation */
%macro create_countplots(data=, out=, vars=, byvar=loan_status);

    %let nvars = %sysfunc(countw(&vars));

    %do i = 1 %to &nvars;

        %let var = %scan(&vars, &i);

        proc sgplot data=&data;
            vbar &var / group=&byvar groupdisplay=cluster;
            xaxis label="&var";
            yaxis label="Count";
            title "Countplot for &var";
        run;

    %end;

%mend;

/* Call the macro to create countplots */
%create_countplots(data=WORK.cr_loan, out=WORK.countplots, vars=person_home_ownership loan_intent loan_grade cb_person_default_on_file);

/* Define macro for KDE generation*/
%macro kde_loan_status(data=, out=, vars=, byvar=loan_status);

%let nvars = %sysfunc(countw(&vars));

    %do i = 1 %to &nvars;

        %let var = %scan(&vars, &i);
        
         proc corr data=&data noprint outp=corr_out;
         var &var &byvar;
         run;
        
         data corr_value;
         set corr_out(keep=&var) end=last;
         retain correlation;
         if last then do;
            correlation = &var;
            output;
         end;
         run;
         
         data last_corr_value;
         set corr_value(drop=&var) end=last;
         if last then output;
         run;
         
         proc sgplot data=&data;
         density &var / group=&byvar;
         xaxis label="&var";
         yaxis label="Density";
         title "Density for &var";
         run;
         
         proc print data=last_corr_value noobs;
         title "Correlation between &var and target variable";
         run;
         
         title;
         
         proc hpbin data=&data numbin=5 woe;
         input &var;
         target loan_status / level=binary;
         run;
         
 %end;

%mend;

/* Call the macro to create KDE */
%kde_loan_status(data=WORK.cr_loan, out=WORK.kde, vars=person_age person_income person_emp_length loan_amnt loan_int_rate loan_percent_income cb_person_cred_hist_length);

/* Bivariate analysis - numerical variables */

proc corr data=work.cr_loan noprint
    pearson
    outp=work.tmpCorr;
run;

proc print data=work.tmpCorr;
title "Correlation table for numerical variables";
run;

title;

data work.cr_loan;
    set work.cr_loan (drop=cb_person_cred_hist_length);
run;

proc freq data=work.cr_loan;
tables person_home_ownership*loan_status / chisq;
run;

proc freq data=work.cr_loan;
tables loan_intent*loan_status / chisq;
run;

proc freq data=work.cr_loan;
tables loan_grade*loan_status / chisq;
run;

proc freq data=work.cr_loan;
tables cb_person_default_on_file*loan_status / chisq;
run;

/* Split into training and test sets */

data split_data;
set work.cr_loan;
n=ranuni(8);
proc sort data=split_data;
  by n;
  data training testing;
   set split_data nobs=nobs;
   if _n_<=.7*nobs then output training;
    else output testing;
   run;
   
data training;
set training(drop=n);
run;

data testing;
set testing(drop=n);
run;

/* Logistic regression model */

ods graphics on;

proc logistic data=training plots(only)=roc;
class person_home_ownership loan_intent loan_grade cb_person_default_on_file / param=reference ref=first;
model loan_status(event='1') = person_age person_income person_emp_length loan_amnt loan_int_rate loan_percent_income person_home_ownership loan_intent loan_grade cb_person_default_on_file /selection=backward;
output out=logistic_results predicted=predicted_train;
score data=training fitstat;
score data=testing fitstat;
run;

ods graphics off;

/*Decision tree model */

ods graphics on;

proc hpsplit data=training;
class loan_status person_home_ownership loan_intent loan_grade cb_person_default_on_file;
model loan_status(event='1') = person_home_ownership loan_intent loan_grade cb_person_default_on_file person_age person_income person_emp_length loan_amnt loan_int_rate loan_percent_income;
prune costcomplexity;
partition fraction(validate=0.3 seed=42);
output out=scored;
run;

ods graphics off;


