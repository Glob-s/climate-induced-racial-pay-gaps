# Climate-Induced Racial Pay Gaps (Brazil): Analysis Pipeline

This folder implements Stata pipeline that estimates dynamic treatment effects of climate disasters on establishment wage outcomes, including race-based pay gaps, using Callaway and Sant’Anna DiD (`csdid`).

## Files in this folder

- `master.do`: top-level driver that runs the pipeline.
- `00_globals.do`: environment setup, package install, panel preparation.
- `01_utils.do`: helper programs for descriptive tables and event-study exports.
- `02_reference.do`: main estimation workflow and output generation.
- `results/`: generated tables, plots, and intermediate artifacts.

## Required input data

Expected under `analysis/data/`:

- `brazil_firms_panel_2003_2017.csv`.
- `estb_variables_dec2025.csv`.

Minimum required fields across inputs:

| Variable | Description |
|---|---|
| `cnpj_cei` | Establishment identifier (or `cnpjcei`, which scripts rename). |
| `year` | Year of observation. |
| `treated` | Indicator for treatment status in the year. |
| `avg_wage_est` | Average wage at the establishment level. |
| `avg_wage_white` | Average wage for white workers. |
| `avg_wage_nonwhite` | Average wage for non-white workers. |
| `avg_wage_female` | Average wage for female workers. |
| `avg_wage_male` | Average wage for male workers. |
| `avg_wage_lowereduc` | Average wage for workers with lower education. |
| `avg_wage_highereduc` | Average wage for workers with higher education. |
| `avg_wage_disab` | Average wage for workers with disabilities. |
| `avg_wage_nondis` | Average wage for workers without disabilities. |

## How to run

From this directory, run in Stata:

- `do master.do`

Execution order is:

- `00_globals.do`
- `01_utils.do`
- `02_reference.do`

The run log is written to `callaway_did.log`.

## End-to-end pipeline

### Step 1: setup and panel construction (`00_globals.do`)

- Installs `csdid` and `drdid` if needed.
- Imports `brazil_firms_panel_2003_2017.csv` and converts `year` to numeric.
- Creates output directories (`results/`, `results/tables/`, `results/plots/`).
- Builds treatment timing variables:
- `first_hit`: first treatment year within establishment.
- `never_treated`: indicator for never-treated establishments.
- Sets `first_hit = 0` for never-treated units (required by this `csdid` design).
- Forward-fills `first_hit` within establishment over time.
- Drops observations at and after a second hit in the same establishment (first-event design).
- Saves cleaned panel as `data/panel_estab_year.dta`.

### Step 2: helper programs (`01_utils.do`)

Defines global number formats and two reusable programs:

- `_desc_table_docx`: exports descriptive statistics (Obs, Mean, SD, Min, Max) to `.docx`.
- `_es_export_with_plot`: runs `csdid`, computes event-time effects, exports one `.docx` report and one `.png` figure per outcome.

`_es_export_with_plot` also includes aggregated pre/post summaries, Wald tests by event-time blocks, and sample-size counts.

### Step 3: main estimation workflow (`02_reference.do`)

- Loads helper programs and ensures result directories exist.
- Uses event-study windows: pre `-3` to `-1`, post `0` to `+6`, short-run average `0` to `+4`.
- Imports `estb_variables_dec2025.csv` and merges it with `data/panel_estab_year.dta` on `cnpj_cei year`.
- Creates numeric `est_id` if missing (from grouped establishment IDs).
- Validates required wage variables and coerces to numeric.
- Constructs gap outcomes:
- `gap_race = avg_wage_nonwhite - avg_wage_white`.
- `gap_gender = avg_wage_female - avg_wage_male`.
- `gap_educ = avg_wage_lowereduc - avg_wage_highereduc`.
- `gap_disab = avg_wage_disab - avg_wage_nondis`.
- Defines estimation outcomes:
- `avg_wage_est`, `gap_race`, `gap_gender`, `gap_educ`, `gap_disab`.
- Exports descriptive table to `results/tables/Table1_Descriptive.docx`.
- Runs DiD/event-study for each outcome and exports per-outcome reports/figures.

### Step 4: orchestration and logging (`master.do`)

- Clears Stata state and configures runtime options.
- Runs all scripts in sequence.
- Writes completion message and closes `callaway_did.log`.

## Estimation design summary

- Method: staggered-adoption Callaway and Sant’Anna DiD via `csdid`.
- Unit: establishment-year panel.
- Treatment group timing: `first_hit`.
- Comparison groups: not-yet-treated and never-treated (`first_hit=0`).
- Inference: cluster-robust SEs at establishment (`est_id`).
- Dynamic analysis: event-time coefficients plus Wald tests for pre and post blocks.

## Main outputs

- Log file: `callaway_did.log`.
- Clean panel: `data/panel_estab_year.dta`.
- Descriptive table: `results/tables/Table1_Descriptive.docx`.
- Event-study tables: `results/tables/ES_*.docx`.
- Event-study plots: `results/plots/ES_*.png`.

## Assumptions and safeguards

- The analysis is intentionally first-event only (observations after second treatment are dropped).
- If IDs are provided as `cnpjcei`, scripts normalize to `cnpj_cei`.
- Missing required variables in `02_reference.do` stop execution with an error.
- `drdid` is installed for completeness, while core estimation is performed with `csdid`.

