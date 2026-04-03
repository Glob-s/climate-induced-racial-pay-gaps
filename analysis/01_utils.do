/*******************************************************************************
  01_utils.do - Define global number formats and helper functions for analysis.
  These include:
  - _es_export_with_plot: runs csdid for a specified DV, generates an event study plot, and exports results to a .docx report with tables of coefficients and Wald tests.
  - _desc_table_docx: generates a .docx report with descriptive statistics (N, mean, std. dev, min, max) for a specified list of variables.
  Both functions use global number formats defined at the top of the script for consistent formatting across outputs.
*******************************************************************************/

version 18.0

global NUMFMT "%9.3f"
global SEFMT  "%9.3f"
global PFMT   "%9.3f"

********************************************************************************
* --- Helper functions ---
********************************************************************************

* -----------------------------------------------------------------------------
* PROGRAM: Run csdid, generate event study plot, and export results to .docx
* OPTIONS:
* dv(string) - specify dependent variable for csdid
* title(string) - specify title of the report
* outdoc(string) - specify full path to save the .docx file
* pre(integer) - number of pre-treatment periods to include in event study (default: 3)
* postshort(integer) - number of short-run post-treatment periods to include in event study (default: 4)
* postlong(integer) - number of long-run post-treatment periods to include in event study (default: 6)
* -----------------------------------------------------------------------------

cap program drop _es_export_with_plot
program define _es_export_with_plot
    version 18.0
    syntax , DV(string) TITLE(string) OUTDOC(string) [PRE(integer 3) POSTSHORT(integer 4) POSTLONG(integer 6)]

    * Clean title to avoid non-ASCII (remove Unicode escapes)
    local clean_title = subinstr("`title'", "", "-", .)

    * Run csdid
    quietly csdid `dv', ivar(est_id) time(year) gvar(first_hit) notyet vce(cluster est_id)
    estimates store es

    * Event study plotting
    quietly estat event, window(-`pre' `postlong')
    
    preserve
        * PNG path
        local outpng = subinstr("`outdoc'","results/tables/","results/plots/",.)
        local outpng = subinstr("`outpng'",".docx",".png",.)

        csdid_plot, xtitle("Event time (years)") ytitle("ATT") title("`clean_title'")
        graph export "`outpng'", replace width(2000)

        * DOCX export
        putdocx clear
        putdocx begin, pagesize(letter) font("Arial",10)
        putdocx paragraph, style(Heading1)
        putdocx text ("`title'")
        putdocx paragraph, style(Heading2)
	
	quietly estat event, window(-`pre' `postlong')
        putdocx text ("Event-time dynamics (-`pre'..`postlong')")
	matrix table_transposed = r(table)'
        putdocx table t1 = matrix(table_transposed), rownames colnames nformat("$NUMFMT")
        putdocx paragraph, style(Heading2)
        putdocx text ("Aggregated effects (coefficients only)")
	
	quietly estat event, window(-`pre' -1)
        putdocx paragraph
        putdocx text ("Pre_avg (-`pre'..-1)  = " + strofreal(r(table)[1,1], "$NUMFMT"))
	
	quietly estat event, window(0 `postshort')
        putdocx paragraph
        putdocx text ("Post_avg (0..`postshort') = " + strofreal(r(table)[1,2], "$NUMFMT"))
	
	quietly estat event, window(0 `postlong')
        putdocx paragraph
        putdocx text ("Post_avg (0..`postlong') = " + strofreal(r(table)[1,2], "$NUMFMT"))
	
	* Wald tests
	putdocx paragraph, style(Heading2)
	putdocx text ("Wald Tests")
	
	putdocx paragraph
	putdocx text ("H0: all pre-treatment coefficients are equal to zero (-3 -1)")
	putdocx paragraph
	* Pre-treatment tests (-3 -1)
	estimates restore es
	cap quietly estat event, window(-3 -1) post
	if _rc == 0{
		local coefnames : colnames e(b)
		local tst ""
		foreach c of local coefnames {
			if strpos("`c'", "Tm"){
				local tst "`tst' (`c'=0)"
			}
		    }
		test `tst'
		putdocx table preWald = (3, 2)
		putdocx table preWald(1,1) = ("chi2"), bold
		putdocx table preWald(1,2) = (strofreal(r(chi2), "$NUMFMT"))
		putdocx table preWald(2,1) = ("df"), bold
		putdocx table preWald(2,2) = (string(r(df)))
		putdocx table preWald(3,1) = ("p"), bold
		putdocx table preWald(3,2) = (strofreal(r(p), "$NUMFMT"))
	} 
	else {
		putdocx text ("Test failed, missing/incomplete coefficients for window (-3 -1)")
	}
	
	putdocx paragraph
	putdocx text ("H0: all short-run post-treatment coefficients are equal to zero (0 2)")
	putdocx paragraph
	* Short-run post-treatment tests (0 2)
	estimates restore es
	cap quietly estat event, window(0 2) post
	if _rc == 0{
		local coefnames : colnames e(b)
		local tst ""
		foreach c of local coefnames {
			if strpos("`c'", "Tp"){
				local tst "`tst' (`c'=0)"
			}
		    }
		test `tst'
		putdocx table srWald = (3, 2)
		putdocx table srWald(1,1) = ("chi2"), bold
		putdocx table srWald(1,2) = (strofreal(r(chi2), "$NUMFMT"))
		putdocx table srWald(2,1) = ("df"), bold
		putdocx table srWald(2,2) = (string(r(df)))
		putdocx table srWald(3,1) = ("p"), bold
		putdocx table srWald(3,2) = (strofreal(r(p), "$NUMFMT"))
	} 
	else {
		putdocx text ("Test failed, missing/incomplete coefficients for window (0 2)")
	}
	
	* Medium-run post-treatment tests (3 POSTSHORT)
	putdocx paragraph
	putdocx text ("H0: all medium-run post-treatment coefficients are equal to zero (3 `postshort')")
	putdocx paragraph
	estimates restore es
	cap quietly estat event, window(3 `postshort') post
	if _rc == 0 {
		local coefnames : colnames e(b)
		local tst ""
		foreach c of local coefnames {
			if strpos("`c'", "Tp"){
				local tst "`tst' (`c'=0)"
			}
		    }
		test `tst'
		putdocx table mrWald = (3, 2)
		putdocx table mrWald(1,1) = ("chi2"), bold
		putdocx table mrWald(1,2) = (strofreal(r(chi2), "$NUMFMT"))
		putdocx table mrWald(2,1) = ("df"), bold
		putdocx table mrWald(2,2) = (string(r(df)))
		putdocx table mrWald(3,1) = ("p"), bold
		putdocx table mrWald(3,2) = (strofreal(r(p), "$NUMFMT"))
	} 
	else {
		putdocx text ("Test failed, missing/incomplete coefficients for window (3 `postshort')")
	}
	
	* Long-run post-treatment tests (5 `postlong')
	putdocx paragraph
	putdocx text ("H0: all long-run post-treatment coefficients are equal to zero (5 `postlong')")
	putdocx paragraph
	estimates restore es
	cap quietly estat event, window(5 `postlong') post
	if _rc == 0 {
		local coefnames : colnames e(b)
		local tst ""
		foreach c of local coefnames {
			if strpos("`c'", "Tp"){
				local tst "`tst' (`c'=0)"
			}
		    }
		test `tst'
		putdocx table lrWald = (3, 2)
		putdocx table lrWald(1,1) = ("chi2"), bold
		putdocx table lrWald(1,2) = (strofreal(r(chi2), "$NUMFMT"))
		putdocx table lrWald(2,1) = ("df"), bold
		putdocx table lrWald(2,2) = (string(r(df)))
		putdocx table lrWald(3,1) = ("p"), bold
		putdocx table lrWald(3,2) = (strofreal(r(p), "$NUMFMT"))
	} 
	else {
		putdocx text ("Test failed, missing/incomplete coefficients for window (5 `postlong')")
	}
	
	* Number of observations (total, per-cohort)
	count
	local N = r(N)
	
	* Mark first est_id in sample
	bys est_id: gen byte __first = (_n == 1)
	count if __first
	local E = r(N)
	
	* Number of establishments in treatment group
	count if __first & first_hit > 0
	local E_treated = r(N)
	
	* Number of establishments in comparison group
	count if __first & first_hit == 0
	local E_comp = r(N)
	
	drop __first
	
	putdocx table obs = (4, 2)
	putdocx table obs(1,1) = ("N Obs"), bold
	putdocx table obs(1,2) = ("`N'")
	putdocx table obs(2,1) = ("N Establishments"), bold
	putdocx table obs(2,2) = ("`E'")
	putdocx table obs(3,1) = ("N Treated Establishments"), bold
	putdocx table obs(3,2) = ("`E_treated'")
	putdocx table obs(4,1) = ("N Comparison Establishments"), bold
	putdocx table obs(4,2) = ("`E_comp'")
	
	putdocx paragraph, style(Heading2)
        putdocx text ("Figure saved to: `outpng'")
        putdocx save "`outdoc'", replace
	
    restore
end

* -----------------------------------------------------------------------------
* PROGRAM: descriptive statistics (N, Mean, Std.Dev, Min, Max)
* OPTIONS:
* vars() - specify varlist as a space-separated list of names e.g. vars("varA varB varC")
* numvars() - must be equal to number of variables in vars()
* title() - specify title of document
* outdoc() - specify full path to save the .docx file
* -----------------------------------------------------------------------------
cap program drop _desc_table_docx
program define _desc_table_docx
    version 18.0
    syntax , VARS(string) NUMVARS(integer) TITLE(string) OUTDOC(string)

    putdocx clear
    putdocx begin, pagesize(letter) font("Times New Roman",10)
    putdocx paragraph, style(Heading1)
    
    local nrows = `numvars' + 1
    putdocx table table1 = (`nrows', 6)
    
    putdocx table table1(1,1) = ("Variable"), bold
    putdocx table table1(1,2) = ("Obs"), bold
    putdocx table table1(1,3) = ("Mean"), bold
    putdocx table table1(1,4) = ("Std. Dev"), bold
    putdocx table table1(1,5) = ("Min"), bold
    putdocx table table1(1,6) = ("Max"), bold
    
    local i = 2
    foreach var of varlist `vars' {
    	quietly summarize `var'
	putdocx table table1(`i',1) = ("`var'")
	putdocx table table1(`i',2) = (string(r(N)))
	putdocx table table1(`i',3) = (strofreal(r(mean), "$NUMFMT"))
	putdocx table table1(`i',4) = (strofreal(r(sd), "$NUMFMT"))
	putdocx table table1(`i',5) = (strofreal(r(min), "$NUMFMT"))
	putdocx table table1(`i',6) = (strofreal(r(max), "$NUMFMT"))
	
	local ++i
    }
    putdocx paragraph
    putdocx text ("Notes: Establishment-year panel. Means and standard deviations computed over the estimation sample. ")
    putdocx save "`outdoc'", replace
end
