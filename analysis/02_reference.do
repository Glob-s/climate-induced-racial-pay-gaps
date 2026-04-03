
/*******************************************************************************
  02_reference.do – DVs: wage gap between white & non-white employees, holding job type constants
  Produces event-time tables (DOCX) and plots (PNG) for each mechanism.
  Uses Callaway–Sant'Anna (csdid) with first-hit timing and not-yet-treated controls.
  Assumes "drop after second hit" is enforced upstream in panel_estab_year.dta.
*******************************************************************************/

version 18.0
quietly {
    cap mkdir "results"
    cap mkdir "results/tables"
    cap mkdir "results/plots"
    cap mkdir "results/intermediate"
}
do "01_utils.do"

* ---------------------------------------------------------------------------
* 0. INPUTS and PARAMETERS
* ---------------------------------------------------------------------------
tempfile mechvars

local PRE_LEADS  = 3          // pre-shock window: -3,-2,-1
local POST_LAGS  = 6          // post-shock window: 0..+6
local POST_SHORT = 4          // main post-shock avg: 0..+4
local BREPS      = 200        // bootstrap reps
set seed 20250819

* Expected identifiers already in the main panel:
*   - cnpj_cei : establishment id (string). If present as cnpjcei, we rename.
*   - year     : calendar year (numeric)
*   - first_hit: first disaster year (group var for csdid)
* -----------------------------------------------------------------------------

* -----------------------------------------------------------------------------
* 1. MERGE SOURCES
*    A) estb_variables_dec2025.csv (dependent variables)
* -----------------------------------------------------------------------------

import delimited using "data/estb_variables_dec2025.csv", ///
    varnames(1) stringcols(1) clear
cap rename cnpjcei cnpj_cei
destring year, replace force
save `mechvars', replace

* Master analysis panel (already has first_hit and drop-after-second-hit enforced upstream)
use "data/panel_estab_year.dta", clear
cap rename cnpjcei cnpj_cei
destring year, replace force

merge 1:1 cnpj_cei year using `mechvars', keep(master match) nogen force

* Ensure stable numeric establishment id for csdid
cap confirm numeric variable est_id
if _rc {
    egen long est_id = group(cnpj_cei)
    label var est_id "Establishment ID (numeric)"
}


* -----------------------------------------------------------------------------
* 2. VERIFY PRESENCE OF REQUIRED VARIABLES
* -----------------------------------------------------------------------------

local reqvars avg_wage_est avg_wage_white avg_wage_nonwhite avg_wage_female avg_wage_male avg_wage_lowereduc avg_wage_highereduc avg_wage_disab avg_wage_nondis

foreach v of local reqvars {
    capture confirm variable `v'
    if _rc {
        di as error "Required variable missing: `v'"
        exit 459
    }
    destring `v', replace force
}

gen gap_race = avg_wage_nonwhite - avg_wage_white
gen gap_gender = avg_wage_female - avg_wage_male
gen gap_educ = avg_wage_lowereduc - avg_wage_highereduc
gen gap_disab = avg_wage_disab - avg_wage_nondis

* 3. Declare outcome variables: total, low-skill & high-skill contracts (white & non-white) 
local ref_outcomes avg_wage_est gap_race gap_gender gap_educ gap_disab 
misstable sum `ref_outcomes'

* -----------------------------------------------------------------------------
* 4. GENERATE .docx REPORT OF DESCRIPTIVE STATISTICS FOR DEPENDENT VARIABLES
* -----------------------------------------------------------------------------

local descriptiveVars "avg_wage_est avg_wage_white avg_wage_nonwhite avg_wage_female avg_wage_male avg_wage_lowereduc avg_wage_highereduc avg_wage_disab avg_wage_nondis gap_race gap_gender gap_educ gap_disab"

_desc_table_docx, vars(`descriptiveVars') numvars(13) title("Table 1. Descriptive statistics - baseline variables") outdoc("results/tables/Table1_Descriptive.docx")


* -----------------------------------------------------------------------------
* 5. RUN Callaway-Sant'Anna DiD ON EACH DV
* -----------------------------------------------------------------------------

foreach y of local ref_outcomes {
	_es_export_with_plot , dv(`y') title("C&S: `y'") ///
	outdoc("results/tables/ES_`y'.docx") pre(`PRE_LEADS') postshort(`POST_SHORT') postlong(`POST_LAGS')
}

