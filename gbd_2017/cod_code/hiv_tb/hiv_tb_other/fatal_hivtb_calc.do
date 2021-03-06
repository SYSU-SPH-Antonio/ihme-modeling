** Description: HIV-TB and HIV-other calculations
** Step (1): run a mixed effects regression to predict proportions of HIV-TB among all TB cases
** Step (2): calculate PAF using the predicted proportions above and global RR
** Step (3): generate HIV death age pattern
** Step (4): calculate hivtb deaths based on high quality VR data and proportions of HIV positive TB cases
** Step (5): capping hivtb deaths if hivtb/hiv>45%
** Step (6): upload results

// Settings
			// Clear memory and set memory and variable limits
				clear all
				
			// Set to run all selected code without pausing
				set more off

			// Set graph output color scheme
				set scheme s1color

			// Define J drive (data) for cluster (UNIX) and Windows (Windows)
				if c(os) == "Unix" {
					global prefix "/FILEPATH/"
					set odbcmgr unixodbc
				}
				else if c(os) == "Windows" {
					global prefix "/FILEPATH/"
				}
			
			// Close any open log file
				cap log close
				
			// local

				

** *************************************************************************************************************************************************
// locals
local acause hiv_tb
local custom_version v1.6
local tb_model 484832_484829_lri
local hiv_male 484127
local hiv_female 484175
local hiv_model 484127_484175

// Make folders on cluster
capture mkdir "/FILEPATH/"
capture mkdir "/FILEPATH/"
capture mkdir "/FILEPATH/"
capture mkdir "/FILEPATH/"

// define filepaths
	cap mkdir "/FILEPATH/"
	cap mkdir "/FILEPATH/"
	
	local outdir "/FILEPATH/"
	local indir "/FILEPATH/"
	local tempdir "/FILEPATH/"

** **************************************************************************************************************************************************
** Step (1): run a mixed effects regression to predict proportions of HIV-TB among all TB cases
** **************************************************************************************************************************************************

// get direct coded HIV-TB before redistribution

		insheet using "`indir'/hivtb_prop.csv", comma names clear 
		/*gen year_mean=(year_start+year_end)/2	 
        gen year=round(year_mean, 1) */
		
		// drop 1 outlier from NGA
		
		drop if location_id==214 & year_id==2003
		
		keep location_id year_id data
		
		rename year_id year
		
		rename data raw_prop
		
				
		tempfile prop
		save `prop', replace
		
		/*
		preserve
		keep if location_id==44539 | location_id==44540
		collapse (sum) cases sample_size, by (location_id year)
		gen mean=cases/sample_size
		tempfile six_minor_ter
		save `six_minor_ter', replace
		restore
		
		drop if location_id==44539 | location_id==44540
		append using `six_minor_ter'
		
		rename mean raw_prop
		drop cases sample_size
		
		// drop outliers
		drop if location_id==196 & (year==2002 | year==2003)
		drop if location_id==130 & (year==2006 | year==2007)
		drop if inlist(location_id,43882,43884,43885,43886,43895,43888,43894,43895,43903,43918,43920,43922,43924,43926,43931) & year==2008
		drop if inlist(location_id,43894,43903,43911,43930,43921,43939) & year==2009
		drop if location_id==6 & year==2006
		drop if location_id==11
		tempfile prop
		save `prop', replace		
	    */

      // get iso3
	  
	  use "`tempdir'/iso3.dta", clear
	  replace location_name="USA Georgia" if location_id==533
	  replace location_name="MEX Distrito Federal" if location_id==4651
	  duplicates drop location_name, force
	  tempfile iso3
	  save `iso3', replace
	  
      // get population

		clear all
		adopath + "/FILEPATH/"
		get_population, location_id("-1") year_id("-1") sex_id("1 2") age_group_id("-1") location_set_version_id(319) clear
		rename population mean_pop
		tempfile pop_all
		save `pop_all', replace
		
		keep if age_group_id==22
        tempfile pop
		save `pop', replace
		
	 // get the covariate
	 
		clear all
		adopath + "/FILEPATH/"
		get_covariate_estimates, covariate_id(1240)
		keep if sex_id==3
		save "`indir'/adult_hiv_death_rate.dta", replace

        duplicates drop 
	
	    gen ln_rate=ln(mean_value)
	  
	    keep location_id year_id ln_rate
	
	    gen year=year_id
		merge 1:m location_id year using `prop', keepusing(raw_prop) nogen 
				
		gen logit_prop_tbhiv=logit(raw_prop)
		
		merge m:1 location_id using "`tempdir'/iso3.dta", keepusing(iso3) keep(3)nogen
		
		tempfile tmp_reg_dta
	    save `tmp_reg_dta', replace
        save "`outdir'/tmp_reg_dta", replace
		
** *****************************
// Predict Fraction TB-HIV in TB
** *****************************

		use `tmp_reg_dta', clear
		drop if year<1980	
		
		merge m:1 location_id using "/FILEPATH/", keepusing(super_region_id region_id) keep(3)nogen
		
		log using "`outdir'/hivtb_prop_log_`custom_version'.smcl", replace
	
		//  regression 
			xtmixed logit_prop_tbhiv ln_rate || super_region_id: || region_id: || location_id: 
		
	    cap log close 		
		** store location_id

		/*
			preserve
				predict u_location_id, reffects
				keep location_id u*
				duplicates drop 
				outsheet using "`outdir'\Country_RE_HIVTB_prop_reg.csv", delim(",") replace 
			restore
		*/
	
	predict sr_RE reg_RE iso_RE, reffects
	preserve
	collapse (mean) iso_RE, by(iso3 region_id super_region_id)
	rename iso_RE iso_RE_new
	tempfile iso_RE
	save `iso_RE', replace
	
	restore 
 	preserve
	collapse (mean) reg_RE, by(region_id super_region_id)
	rename reg_RE reg_RE_new
	tempfile region_RE
	save `region_RE', replace
	
	restore 
	preserve
	collapse(mean) sr_RE, by(super_region_id)
	rename sr_RE sr_RE_new
	tempfile SR_RE
	save `SR_RE', replace
	restore
	
	merge m:1 iso3 using `iso_RE', keepusing(iso_RE_new) nogen
	merge m:1 region_id using `region_RE', keepusing(reg_RE_new) nogen
	merge m:1 super_region_id using `SR_RE', keepusing(sr_RE_new) nogen
	
		tempfile all
		save `all', replace 
		
				
		use `iso_RE', clear /* add Eth=179, Iran=142, NZL=72, NOR=90, RUS=62 */
		preserve
		keep if iso3=="CHN"
		local iso_RE_CHN=iso_RE
		restore
		
		preserve
		keep if iso3=="MEX"
		local iso_RE_MEX=iso_RE
		restore
		
		preserve
		keep if iso3=="GBR"
		local iso_RE_GBR=iso_RE
		restore
		
		preserve
		keep if iso3=="USA"
		local iso_RE_USA=iso_RE
		restore
		
		preserve
		keep if iso3=="BRA"
		local iso_RE_BRA=iso_RE
		restore
				
		preserve
		keep if iso3=="JPN"
		local iso_RE_JPN=iso_RE
		restore
		
	
	    preserve
		keep if iso3=="SWE"
		local iso_RE_SWE=iso_RE
		restore
		
			
		preserve
		keep if iso3=="ETH"
		local iso_RE_ETH=iso_RE
	  	restore
		
		preserve
		keep if iso3=="IRN"
		local iso_RE_IRN=iso_RE
	   	restore
		
		preserve
		keep if iso3=="NZL"
		local iso_RE_NZL=iso_RE
	   	restore
		
		preserve
		keep if iso3=="NOR"
		local iso_RE_NOR=iso_RE
	    restore
		
		preserve
		keep if iso3=="RUS"
		local iso_RE_RUS=iso_RE
	   	restore
		
		preserve
		keep if iso3=="IDN"
		local iso_RE_IDN=iso_RE
		restore
		
    use `all', clear
    
	/* merge m:1 super_region using `super_RE', nogen	*/
		
	// missing subnational random effects and SEs are replaced with country random effects and SEs
	replace iso_RE=`iso_RE_CHN' if regexm(iso3,"CHN_")
	replace iso_RE=`iso_RE_GBR' if regexm(iso3,"GBR_")
	replace iso_RE=`iso_RE_MEX' if regexm(iso3,"MEX_")
	replace iso_RE=`iso_RE_USA' if regexm(iso3,"USA_")
	replace iso_RE=`iso_RE_BRA' if regexm(iso3,"BRA_")
	replace iso_RE=`iso_RE_JPN' if regexm(iso3,"JPN_")
	replace iso_RE=`iso_RE_SWE' if regexm(iso3,"SWE_")
	replace iso_RE=`iso_RE_IDN' if regexm(iso3,"IDN_") 
	replace iso_RE=`iso_RE_ETH' if regexm(iso3,"ETH_")
	replace iso_RE=`iso_RE_IRN' if regexm(iso3,"IRN_")
	replace iso_RE=`iso_RE_NZL' if regexm(iso3,"NZL_")
	replace iso_RE=`iso_RE_NOR' if regexm(iso3,"NOR_")
	replace iso_RE=`iso_RE_RUS' if regexm(iso3,"RUS_")

	// missing country random effects are replaced with the average random effect at the global level (i.e., 0)
	replace iso_RE=0 if iso_RE==.
		
	/*
	// countries with missing standard errors are replaced with global standard deviation of the country random effects
	// run _diparm  to get global sd of random effects /* need to use lns1_1_1. xtmixed estimates the ln_sigma, the inverse function is exp(). The derivative of exp() is just exp() */
	_diparm lns1_1_1, f(exp(@)) d(exp(@))
	gen global_sd=`r(est)'
	
	replace iso_RE_se = global_sd if missing(iso_RE_se)
	
	*/
	
	replace reg_RE=reg_RE_new if reg_RE==.
	
	replace sr_RE=sr_RE_new if sr_RE==.
	
	
		// create draws from the covariance matrix to get parameter uncertainty
		
			matrix m = e(b)'
			matrix m = m[1..(rowsof(m)-4),1]
			local covars: rownames m
			local num_covars: word count `covars'
			local betas
			forvalues j = 1/`num_covars' {
				local this_covar: word `j' of `covars'
				local betas `betas' b_`this_covar'
			}
			matrix C = e(V)
			matrix C = C[1..(colsof(C)-4), 1..(rowsof(C)-4)]
			drawnorm `betas', means(m) cov(C)
			** just save 1,000 betas... 
			preserve
				qui keep b*
				qui drop if _n>1000
				qui gen id=_n
				qui tempfile tmp_betas
				save `tmp_betas', replace 
			restore
			qui drop b_*
			** drop duplicates
			qui duplicates drop
			qui gen id=_n
			merge 1:1 id using "`tmp_betas'", nogen 
			drop id
	
			
		// Generate 1000 estimates 
			forvalues j = 1/1000 {
				di in red "Generating Draw `j'"
				qui gen prop_tbhiv_xb_d`j'=ln_rate*b_ln_rate[`j']+b__cons[`j']+iso_RE+reg_RE+sr_RE
				qui replace prop_tbhiv_xb_d`j'=invlogit(prop_tbhiv_xb_d`j')
			}
			
		** drop duplicates
			duplicates drop 
		tempfile tmp_prop_xb
		save `tmp_prop_xb', replace 
		
     // calculate mean, upper, and lower
     egen mean_prop=rowmean(prop_tbhiv*)
	 egen lower_prop=rowpctile(prop_tbhiv*), p(2.5)
	 egen upper_prop=rowpctile(prop_tbhiv*), p(97.5)
	 drop prop_tbhiv*

     save "`outdir'/Prop_tbhiv_mean_ui_`custom_version'.dta", replace
	 
 
** *****************************
// Graph predictions... prop tbhiv/tb
** *****************************
// Initialize pdfmaker

	set scheme s1color
	set printcolor asis
	capture confirm file "/FILEPATH/"
	if _rc == 0 {
		do "/FILEPATH/"
	}
	else {
		do "/FILEPATH/"
	}
	
	
	use "`outdir'/Prop_tbhiv_mean_ui_`custom_version'.dta", clear
	duplicates drop location_id year, force
	tempfile prop
	save `prop', replace
	
	use "`outdir'/tmp_reg_dta", clear
	duplicates drop location_id year, force
	tempfile reg
	save `reg', replace
	
	    use `prop', clear
		merge m:1 location_id year using `reg', nogen 
		merge m:1 location_id using "`tempdir'/iso3.dta", keepusing(iso3) keep(3)nogen
		gen pred_prop=mean_prop
		gen pred_prop_lower=lower_prop
		gen pred_prop_upper=upper_prop
		drop if year<1980	
		drop if (location_id>=4841 & location_id<=4875) | location_id==44538
		
		pdfstart using "`outdir'/Prop_tbhiv_scatter_`custom_version'.pdf"
			sort iso3 year
			levelsof iso3 , local(isos)
			foreach i of local isos {
					scatter pred_prop year if iso3=="`i'" || scatter raw_prop year if iso3=="`i'", title("`i'")    ///
					legend(order(1 "Predicted proportions" 2 "Raw proportions") col(2))
					pdfappend
			}
		pdffinish
	
** ********************************************************************************************************************************************************	
** Step (2): calculate PAF using the predicted proportions above and global RR
** ********************************************************************************************************************************************************	
// bring in 4-5 star countries
// update this line!!				 
insheet using "`indir'/hiv_tb_icd10_GBD2017.csv", comma names clear 

gen iso3=ihme_loc_id

preserve
keep if acause=="hiv_tb_other"
drop if deaths==0 | deaths==.
collapse (sum) deaths, by (acause iso3 year) 
rename deaths deaths_hivtb
keep iso3 year deaths_hivtb
tempfile hivtb
save `hivtb', replace
restore

keep if acause=="tb_other" | acause=="tb"
drop if deaths==0 | deaths==.
collapse (sum) deaths, by (iso3 year) 
rename deaths deaths_tb
keep iso3 year deaths_tb
tempfile tb
save `tb', replace

use "`outdir'/Prop_tbhiv_mean_ui_`custom_version'.dta", clear
keep iso3 year mean_prop raw_prop
tempfile prop
save `prop', replace

use `hivtb', clear
merge 1:1 iso3 year using `tb', keep(3) nogen

// drop if the number of hivtb deaths is 10 or less
drop if deaths_hivtb <=10

// calculate fractions
gen frac=deaths_hivtb/(deaths_tb+deaths_hivtb)
drop if frac>1
merge 1:1 iso3 year using `prop', keep (3) nogen

gen RR=((frac*mean_prop)-frac)/((frac*mean_prop)-mean_prop)

gen RR_2=((frac*raw_prop)-frac)/((frac*raw_prop)-raw_prop)

save "`outdir'/RR_updated_all_`custom_version'.dta", replace

// drop if RR less than 1
drop if RR<1 & RR !=.

// generate locals for mean and median RRs
sum RR, detail

gen RR_mean=`r(mean)'

gen RR_median=`r(p50)'

save "`outdir'/global_RR_updated_`custom_version'.dta", replace

// calculate PAR

use `tmp_prop_xb', clear

gen RR_mean=`r(mean)'

gen RR_median=`r(p50)'

// Rename draws
			forvalues i = 1/1000 {
				local i1 = `i' - 1
				rename prop_tbhiv_xb_d`i' prop_tbhiv_xb_d`i1'
			}


** loop through draws and adjust them... 
		forvalues j=0/999 {
			di in red "draw `j'"
			gen par_based_on_median_rr_`j'=(prop_tbhiv_xb_d`j'*RR_median)/((prop_tbhiv_xb_d`j'*RR_median)+(1-prop_tbhiv_xb_d`j'))
		}
	keep location_id year_id par_based_on_median_rr_*	
save "`outdir'/predicted_PAR_`custom_version'.dta", replace

** ****************************************************************************************************************************************************
** Step (3): generate HIV death age pattern
** ****************************************************************************************************************************************************

clear all
adopath + "/FILEPATH/"
get_model_results, gbd_team("cod") gbd_id(298) location_set_version_id(319)  model_version_id(`hiv_male') clear

tempfile tmp
save `tmp', replace 

get_model_results, gbd_team("cod") gbd_id(298) location_set_version_id(319)  model_version_id(`hiv_female') clear
append using `tmp'

save "`indir'/hiv_deaths.dta", replace


// drop aggregate locations
use "`indir'/hiv_deaths.dta", clear

keep location_id year_id sex_id age_group_id mean_death_rate

rename mean_death_rate hiv_death_rate

keep if (age_group_id>=4 & age_group_id<=20) | (age_group_id>=30 & age_group_id<=32) | age_group_id==235

save "`indir'/hiv_death_rate_age_pattern.dta", replace

** ****************************************************************************************************************************************************
** Step (4): calculate hivtb deaths based on high quality VR data and proportions of HIV positive TB cases
** ****************************************************************************************************************************************************

// run ado file for fast collapse
				
adopath+ "/FILEPATH/"

use "`outdir'/predicted_PAR_`custom_version'.dta", clear

tempfile frac
save `frac', replace

** *****************************
// Generate TB-HIV death numbers
** *****************************
use /FILEPATH/, clear
duplicates drop location_id year_id age_group_id sex_id, force
// collapse draws
// collapse(sum) draw_*, by (location_id year_id)
fastcollapse draw_*, type(sum) by(location_id year_id) 

** merge on the fraction data
merge 1:1 location_id year_id using `frac', keep(3)nogen
		
	** loop through draws and adjust them... 
		forvalues i=0/999 {
			di in red "draw `i'"
			replace draw_`i'=0 if draw_`i'==.
			gen tbhiv_d`i'=(par_based_on_median_rr_`i'/(1-par_based_on_median_rr_`i'))*draw_`i'
			drop draw_`i' 
			replace tbhiv_d`i'=0 if tbhiv_d`i'==.
		}
tempfile hivtb
save `hivtb', replace
		
save /FILEPATH/, replace

/*
// generate mean, upper, and lower 

egen mean_tbhiv=rowmean(tbhiv_d*)
egen lower_tbhiv=rowpctile(tbhiv_d*), p(2.5)
egen upper_tbhiv=rowpctile(tbhiv_d*), p(97.5)
drop tbhiv_d*
				
save "/FILEPATH/", replace 
*/


// prep pop

*********************************
clear all
		adopath + "/FILEPATH/"
		get_population, location_id("-1") year_id("-1") sex_id("1 2") age_group_id("-1") location_set_version_id(319) clear
		rename population mean_pop
		tempfile pop_all
		save `pop_all', replace

*********************************
use `pop_all', clear
drop if year_id<1980
drop if location_id==1
keep if (age_group_id>=4 & age_group_id<=20) | (age_group_id>=30 & age_group_id<=32) | age_group_id==235
drop if sex_id==3
tempfile tmp_pop
save `tmp_pop', replace

// get hiv deaths age pattern

use "`indir'/hiv_death_rate_age_pattern.dta", clear
tempfile age_pattern
save `age_pattern', replace

// prep for age split

use /FILEPATH/, clear
merge 1:m location_id year_id using `tmp_pop', keep(1 3) nogen
merge m:1 location_id year_id age_group_id sex_id using `age_pattern', keep(3)nogen

rename mean_pop sub_pop
gen rate_sub_pop=hiv_death_rate*sub_pop

preserve
collapse (sum) rate_sub_pop, by(location_id year_id) fast
rename rate_sub_pop sum_rate_sub_pop
tempfile sum
save `sum', replace

restore
merge m:1 location_id year_id using `sum', keep(3)nogen

forvalues i=0/999 {
			di in red "draw `i'"
			gen draw_`i'=rate_sub_pop*(tbhiv_d`i'/sum_rate_sub_pop)
			drop tbhiv_d`i' 
		}

keep location_id year_id age_group_id sex_id draw_*
tempfile hivtb_cyas
save `hivtb_cyas', replace
save /FILEPATH/, replace


** *****************************************************************************************************************************************
** Step (5): capping hivtb deaths if hivtb/hiv>45%
** *****************************************************************************************************************************************

// rename hiv death draws
use /FILEPATH/, clear
duplicates drop location_id year_id age_group_id sex_id, force
// rename draws
forvalues i = 0/999 {
			  rename draw_`i' hiv_`i'
			}
tempfile hiv
save `hiv', replace

// rename hivtb death draws
use /FILEPATH/, clear
duplicates drop location_id year_id age_group_id sex_id, force
/*
// rename draws
forvalues i = 0/999 {
			  rename draw_`i' hivtb_`i'
			}
*/
tempfile hivtb
save `hivtb', replace

// merge the files
			use `hiv', clear
			merge 1:1 location_id year_id age_group_id sex_id using `hivtb', keep(3) nogen 

// loop through draws and adjust them... 
		forvalues i=0/999 {
			gen frac_`i'=draw_`i'/hiv_`i'
			replace draw_`i'=hiv_`i'*0.45 if frac_`i'>0.45
			replace draw_`i'=0 if draw_`i'==.
			}
drop hiv_* frac_*
tempfile hivtb_capped
save `hivtb_capped', replace

drop measure_id

replace cause_id=299		
save /FILEPATH/, replace 

// calculate hiv_other

use `hiv', clear
merge 1:1 location_id year_id age_group_id sex_id using `hivtb_capped', keep(3) nogen
// loop through draws and subtract hiv_tb from hiv 
		forvalues i=0/999 {
			replace draw_`i'=hiv_`i'-draw_`i'
			}
replace cause_id=300		
drop measure_id	metric_id hiv_*

/*
outsheet using /FILEPATH/, comma names replace 
*/

levelsof(location_id), local(ids) clean

foreach location_id of local ids {	
		qui outsheet if location_id==`location_id' using "/FILEPATH/", comma replace
				}

** *********************************************************************************************************************************************************
** Step (6): upload results
** *********************************************************************************************************************************************************
/*
// save results for hiv_tb

do /FILEPATH/
save_results, cause_id(299) description(`acause' custom `custom_version', capped at hivtb/hiv 45 percent) mark_best(yes) in_dir(/FILEPATH/) model_version_type_id(6)
*/

// save results for hiv_other

do /FILEPATH/
save_results_cod, cause_id(300) description(hiv_other custom `custom_version') input_file_pattern({location_id}.csv) input_dir(/FILEPATH/) model_version_type_id(6) clear


