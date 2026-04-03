
/*******************************************************************************
  00_globals.do – Install required packages (csdid and drdid) and load the master panel dataset.
  Create treatment timing variables (first_hit and never_treated) and drop observations after a second disaster hits the same establishment
  to avoid contamination. 
  Finally, save the cleaned master panel for use in subsequent scripts.
*******************************************************************************/

version 18.0

* ---------------------------------------------------------------------------
* 0. INSTALL REQUIRED PACKAGES
* ---------------------------------------------------------------------------

cap which csdid
if _rc ssc install csdid, replace
ssc install drdid, replace

* ---------------------------------------------------------------------------
* 1. LOAD DATA AND SET UP ANALYSIS ENVIRONMENT
* ---------------------------------------------------------------------------

import delimited "data/brazil_firms_panel_2003_2017.csv", ///
	varnames(1) stringcols(1) clear

destring year, replace force

* 1.1 Create output directories -----------------------------------------------
cap mkdir results
cap mkdir results/tables 
cap mkdir results/plots 

* ---------------------------------------------------------------------------
* 2. CREATE TREATMENT TIMING VARIABLES AND DROP CONTAMINATED OBSERVATIONS
* ---------------------------------------------------------------------------

egen first_hit = min(cond(treated==1, year, .)), by(cnpj_cei)
gen  never_treated = missing(first_hit)
replace first_hit = 0 if never_treated  // CS&A requires never-treated = 0

* 2.1 Forward-fill first_hit within treated establishments to ensure all post-treatment periods are correctly labeled 
bysort cnpj_cei (year): replace first_hit = first_hit[1]

* 2.2 drop observations after a SECOND disaster hits the same establishment

bys cnpj_cei: egen second_hit_year = min(cond(treated==1 & first_hit!=0 & year>first_hit, year, .))
drop if !missing(second_hit_year) & year >= second_hit_year // keep first-event panel
order cnpj_cei year first_hit

* ---------------------------------------------------------------------------
* 3. SAVE CLEANED MASTER PANEL
* ---------------------------------------------------------------------------

save "data/panel_estab_year.dta", replace
