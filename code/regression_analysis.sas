* ----------------------------------------------------------------------------;
* regression_analysis.sas
*
* This program reads data used in the California School Dashboard and performs
* linear regression analyses of percent of students who are socioeconomically
* disadvantaged on distance from standard on math and ELA among high schools.
*
* Written by Stephen Lew
* ----------------------------------------------------------------------------;



* ----------------------------------------------------------------------------;
* Extract data on total enrollment and percent of students who are
* socioeconomically disadvantaged
* ----------------------------------------------------------------------------;
filename enr2024 url "https://www3.cde.ca.gov/researchfiles/cadashboard/censusenrollratesdownload2024.txt";
data work.enrollment;
    infile enr2024 dlm = '09'x dsd firstobs = 2 missover;
    input
      cds : $14.
      rtype : $1.
      schoolname : $100.
      districtname : $100.
      countyname : $100.
      studentgroup : $3.
      totalenrollment
      subgrouptotal
      rate
      reportingyear
    ;
run;
data work.enrollment;
    set work.enrollment;

    * Keep only records for schools. Drop district and state records.;
    if rtype = "S";

    * Keep the record with data on socioeconomically disadvantaged students if possible.
    * Schools that do not have any socioeconomically disadvantaged students do not
    * have such a record. For those schools, keep the first record and then set the
    * percentage of socioeconomically disadvantaged students to zero.;
    if studentgroup = "SED" then sed_record = 1;
                            else sed_record = 0;
run;

proc sort data = work.enrollment;
    by cds descending sed_record;
run;
proc sort data = work.enrollment nodupkey;
    by cds;
run;

* Data is now one record per school uniquely identified by cds;

data work.enrollment(keep = cds schoolname districtname totalenrollment sed);
    set work.enrollment(rename = (rate = sed));

    if sed_record = 0 then sed = 0;

    label cds = "County-District-School Code";
    label schoolname = "School Name";
    label districtname = "District Name";
    label totalenrollment = "Total census day enrollment for all students";
    label sed = "Enrollment rate for socioeconomically disadvantaged students";
run;



* ----------------------------------------------------------------------------;
* Extract data on distance from standard on math and ELA
* ----------------------------------------------------------------------------;
%macro extract_assessments(subj = , subjname = );
    filename &subj.2024 url "https://www3.cde.ca.gov/researchfiles/cadashboard/&subj.download2024.txt";
    data work.&subj;
        infile &subj.2024 dlm = '09'x dsd firstobs = 2 missover;
        input
          cds : $14.
          rtype : $1.
          schoolname : $100.
          districtname : $100.
          countyname : $100.
          charter_flag : $1.
          coe_flag : $1.
          dass_flag : $1.
          studentgroup : $4.
          currdenom
          currstatus
          priordenom
          priorstatus
          change
          statuslevel
          changelevel
          color
          box
          currnsizemet : $1.
          priornsizemet : $1.
          accountabilitymet : $1.
          hscutpoints : $1.
          pairshare_method : $2.
          currprate_enrolled
          currprate_tested
          currprate
          currnumPRLOSS
          currdenom_withoutPRLOSS
          currstatus_withoutPRLOSS
          priorprate_enrolled
          priorprate_tested
          priorprate
          priornumPRLOSS
          priordenom_withoutPRLOSS
          priorstatus_withoutPRLOSS
          indicator : $4.
          reportingyear
        ;
    run;
    data work.&subj(keep = cds currstatus rename = (currstatus = &subj));
        set work.&subj;

        * Keep only records for schools that have the data for all students.;
        if rtype = "S" & studentgroup = "ALL";
        * Data is now one record per school uniquely identified by cds;

        label cds = "County-District-School Code";
        label currstatus = "Average Distance From Standard (&subjname)";
    run;
%mend extract_assessments;

%extract_assessments(subj = math, subjname = Math);
%extract_assessments(subj = ela, subjname = ELA);



* ----------------------------------------------------------------------------;
* Extract a list of high schools. High schools have a record in the graduation
* rate data
* ----------------------------------------------------------------------------;
filename grad2024 url "https://www3.cde.ca.gov/researchfiles/cadashboard/graddownload2024.txt";
data work.hs;
    infile grad2024 dlm = '09'x dsd firstobs = 2 missover;
    input
      cds : $14.
      rtype : $1.
      schoolname : $100.
      districtname : $100.
      countyname : $100.
      charter_flag : $1.
      coe_flag : $1.
      dass_flag : $1.
      studentgroup : $4.
      currnumer
      currdenom
      currstatus
      priornumer
      priordenom
      priorstatus
      change
      statuslevel
      changelevel
      color
      box
      smalldenom : $1.
      fiveyrnumer
      currnsizemet : $1.
      priornsizemet : $1.
      accountabilitymet : $1.
      indicator : $4.
      reportingyear
    ;
run;
data work.hs(keep = cds);
    set work.hs;

    * Keep only records for schools. Drop district and state records.;
    if rtype = "S";

    label cds = "County-District-School Code";
run;

proc sort data = work.hs nodupkey;
    by cds;
run;
* Data is now one record per school uniquely identified by cds;



* ----------------------------------------------------------------------------;
* Integrate the data
* ----------------------------------------------------------------------------;
data work.analysis;
    merge work.hs(in = in_left) work.enrollment(in = in_right);
    by cds;
    if in_left = 1 & in_right = 1;
run;
data work.analysis;
    merge work.analysis(in=in_left) work.math;
    by cds;
    if in_left = 1;
run;
data work.analysis;
    merge work.analysis(in=in_left) work.ela;
    by cds;
    if in_left = 1;
run;



* ----------------------------------------------------------------------------;
* Linear regression analyses of percent of students who are socioeconomically
* disadvantaged on distance from standard on math and ELA among high schools. Total
* enrollment is used as the analytic weight.
* ----------------------------------------------------------------------------;
%macro reg_sed_assessments(subj = , subjname = );
    proc reg data = work.analysis;
        model &subj = sed;
        weight totalenrollment;
        output out = work.analysis
          p = &subj.predicted
          r = &subj.resid
        ;
    run;

    proc sgplot data = work.analysis;
        scatter x = sed y = &subj / markerattrs = (color = blue symbol = circle);
        series x = sed y = &subj.predicted / lineattrs = (color = red thickness = 2);
        xaxis label = "Enrollment rate for socioeconomically disadvantaged students";
        yaxis label = "Average Distance From Standard (&subjname)";
    run;
%mend reg_sed_assessments;

%reg_sed_assessments(subj = math, subjname = Math);
%reg_sed_assessments(subj = ela, subjname = ELA);

proc export data = work.analysis
    outfile = "/home/u________/regression_analysis_sas.csv"
    dbms = csv
    replace;
run;
