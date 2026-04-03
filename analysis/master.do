/*******************************************************************************
  master.do - Main driver script for C&SA DiD analysis of climate-induced racial pay gaps in Brazil.
*******************************************************************************/

clear all
set more off
// set trace on 		// helps with debugging; comment out for non-trial runs
cap set maxvar 120000      // precaution, but csdid is memory-light
log using "callaway_did.log", replace 

do 00_globals.do
do 01_utils.do
do 02_reference.do

di as txt "C&SA DiD completed"
log close
