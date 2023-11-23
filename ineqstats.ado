// This program computes distributional statistics
// for each country and year specified
// Authors: Mauricio De Rosa, Ignacio Flores, Marc Morgan (2022)

program ineqstats
	version 11 
	syntax name [, EDAD(numlist max=2) ///
		EXTension(string) SVYPath(string) SMOOTHtop ///
		TYPe(string) BFM BCKTavgs ///
		MRATes(numlist) MTHResholds(numlist) UNIt(string)] ///
		DEComposition(string) TIme(numlist max=2) weight(string) ///
		EXPort(string) AReas(string)
		
	*-----------------------------------------------------------------------
	*PART 0: Check inputs
	*-----------------------------------------------------------------------
	
	//Prepare table to display some info
	local linew = 20 + strlen( "`decomposition'")
	local ctr = round(`linew'/2 - 9)
	forvalues x = 1/`ctr' {
		local spc "`spc' "
	}
	display as text "{hline `linew'}"
	display as text "`spc'INEQSTATS Settings"
	display as text "{hline `linew'}"
	
	//areas 
	di as text "Areas (" wordcount("`areas'") "):" _continue 
	di as result " `areas'"
	
	//Check time  
	if ("`time'" != "") {
		if (wordcount("`time'") == 1) {
			display as error "Option time() incorrectly specified:" ///
				" Must contain both the first and last values" ///
				" Default is 2000 and 2017 respectively."
			exit 198
		}
		local first_period: word 1 of `time'
		local last_period: word 2 of `time'
		di as text "Period: " _continue 
		di as result "`first_period'" _continue
		di as text "-" _continue 
		di as result "`last_period'"
	}
	else {
		local first_period = 2000
		local last_period = 2020
				di as text "Period: " _continue 
		di as result "`first_period'" _continue
		di as text "-" _continue 
		di as result "`last_period'" _continue 
		di as text " (default)"
	}
	
	//Weights
	if ("`weight'" == "") {
		local weight "_fep"
	} 
	di as text "Weight: " _continue 
	di as result "`weight'" _continue 
	
	if ("`weight'" == "") {
		di as text " (default)"
	} 
	else di as text " "
	
	//Unit 
	di as text "Unit: " _continue
	di as result "`unit'"
	
	//Decomposition
	if ("`decomposition'" != "") {
		di as text "Decomposing by: " _continue 
		di as result "`decomposition'"
	}
	else{
		display as error "Please  specify the components of total income"
		exit 1
	}
	
	//Type of survey
	if ("`type'" == "") {
		local `type' "clean"
		di as text "Survey type: " _continue 
		di as result "`type' " _continue
		di as text "(default)"
	}
	else {
		di as text "Survey type: " _continue
		di as result "`type'"
	}
	
	di as text "edad/age: " _continue
	di as result "`edad'"
	
	//Check if export is specified when using summarize
	if ("`namelist'" == "summarize"  & "`export'" == "") {
		display as error "If you use the summarize option without " ///
			"specifying an export path, data will be lost"
		exit 1 
	}
	
	//Decompositions and extensions 
	foreach w in `decomposition' {
		local decomp_suffix "`decomp_suffix' `w'`extension'"
		local decomp_c "`decomp_c' `w'`extension'_c"
		local decomp_g "`decomp_g' `w'`extension'_g"
	}
	
	//Check tax information (if any) ----
	
	*count full or empty opts 
	local taxempt = 0 
	local taxfill = 0
	foreach o in mrates mthresholds {
		*count full or empty 
		if "``o''" == "" local taxempt = 1 + `taxempt' 
		if "``o''" != "" local taxfill = 1 + `taxfill' 	
	}

	*Allow all-full or all-empty only 
	if `taxfill' == 2 | `taxempt' == 2 {
		if `taxempt' == 2 {
			*no tax-options specified: close table 
			display as text "{hline `linew'}"
		}
		*full: check consistency 
		if `taxfill' == 2 {
			if wordcount("`mrates'") == wordcount("`mthresholds'") {
				*tax scheme defined, display parameters before closing table
				di as text " "
				di as text 	 "Tax schedule in " _continue 
				local nrates = wordcount("`mrates'")
				di as result "`nrates'" _continue
				di as text " brackets"
				forvalues x = 1/`nrates' {
					di as text "- bckt `x': lower thr" _continue
					local thr`x': word `x' of `mthresholds'
					local rat`x': word `x' of `mrates'
					di as result " `thr`x''" _continue
					di as text "; rate: " _continue
					di as result "`rat`x''" _continue
					di as text "%"
					*check if thresholds are increasing 
					if `x' > 1 {
						local xmin1 = `x' - 1
						cap assert `thr`x'' > `thr`xmin1'' 
						if _rc == 0 {
							*all good 
						}
						else {
							di as error "tax thresholds must be increasing"
							exit 1
						}
					}
				}
				
				display as text "{hline `linew'}"
			}
			else {
				di as error "Marginal tax options incorreclty specified. " ///
					"the number of thresholds (" wordcount("`mthresholds'") ///
					") and tax rates (" wordcount("`mrates'") ") " ///
					"should be the same"
				exit 1
			}
		}
	}
	else {
		di as error "Marginal tax options incorreclty specified mrates()," ///
			"mthresholds() You can either specify all or none of them"  
		exit 1
	}
	
	if "`taxelasticity'" != "" {
		local taxelasticity = .5
	} 
	*---------------------------------------------------------------------------
	*PART 1: Summary statistics (build excel files & sheets)
	*---------------------------------------------------------------------------
	
	if ("`namelist'" == "summarize") {
	
		// Loopy loops
		foreach c in `areas' {
			
			*prepare matrixes 
			local nyrs = `last_period' - `first_period' + 1
			local nvarsdd  = wordcount("`decomp_suffix'") + 1
			local nvarsdd2 = `nvarsdd'*2 - 1
			mat decomp_s_`c' = J(`nyrs',`nvarsdd2',.)
			mat decomp_g_`c' = J(`nyrs',5,.)
			local iqz = 0
			
			*loop over years 
			forvalues period = `first_period'/`last_period' {
				
				local ++iqz
				
				//Argentinian exception
				*if "`step''" == "raw" local weight "_fep"
				if "`step''" == "raw" & "`c'" == "ARG" local weight "n_fep"
			
				// Open data
				clear
				qui cap use ///
					"`svypath'/`c'/bfm_norep_pre/`c'_`period'_bfm_norep_pre.dta"
	
				//drop any temporary variable that was saved mistakently
				cap drop __* 	
			
				// Only if file exists
				cap assert _N == 0
				if _rc != 0 {
					
					*check variables independently for debugging 
					foreach var in `decomp_suffix' {
						cap confirm variable `var', exact
						if _rc == 0 {
							*check if 
							sum `var', meanonly
							local m_`c'_`period'_`var' = r(mean) 
							if `m_`c'_`period'_`var'' == 0 & ///
								!strpos("`var'", "_lef") {
								local misvar_`c'_`period' ///
									"`misvar_`c'_`period'' `var'"
							} 
						}
						else di as text "  variable `var' not found"
					}
			
					//check variables
					cap confirm variable `decomp_suffix', exact
					if (_rc == 0 & "`misvar_`c'_`period''" == "") {
					
						tempvar ftile ftile_clean freq F fy cumfy L d_eq ///
							p1 p2 bckt_size cum_weight wy freq_t10 F_t10 ///
							auxinc smooth_income bckt_pop
						
						*keep only corresponding pop
						if wordcount("`edad'") == 1 {
							qui drop if edad < `edad' 
						}
						if wordcount("`edad'") == 2 {
							forvalues w = 1/2 {
								local w`w': word `w' of `edad'
							}
							qui drop if !inrange(edad, `w1', `w2')
						}
						
						//pretax vs postax 
						*qui egen pretax = rowtotal(${esn_nat_exep})
						*qui egen postax = rowtotal(${esn_pon_exep})
						
						*recast weight if necessary
						cap assert int(`weight') == `weight' 
						if _rc != 0 {
							di as text "weights contained decimals" _continue
							di as text ", integers now"
							qui replace `weight' = round(`weight')
						}
					
						// scale incomes for BFM adjusted surveys 
						if ("`BFM'" != "") {
							foreach inc in `decomp_suffix' {
								qui replace `inc' = `inc' * _factor
							}
						}
						
						// Get total income and average
						if ("`decomposition'" != "") {
							//display as text "`decomp_suffix'"
							tempname inc_`c'_`period'
							qui egen `inc_`c'_`period'' = ///
								rowtotal(`decomp_suffix')
						}
						qui sum `inc_`c'_`period'' [w=`weight']
						local avg_main = r(mean)	
						
						//write cdf down 
						qui sum	`weight', meanonly
						local poptot = r(sum)
						sort `inc_`c'_`period''
						quietly	gen `freq' = `weight' / `poptot'
						quietly	gen `F' = sum(`freq'[_n - 1])
						
						*collect inequality decomposition*
						
						qui sgini `decomp_suffix' [fw=`weight'], source
						local aqz = 0
						foreach v in `decomp_suffix' {
							local ++aqz
							local bqz = 1 + `aqz'
							local cqz = `bqz' + `nvarsdd' - 1
							mat A = r(relcontrib)
							mat B = r(coeffs)
							if `aqz' == 1 mat decomp_s_`c'[`iqz',1] = `period'
							mat decomp_s_`c'[`iqz',`bqz'] = ///
								A[1,`aqz']
							mat decomp_s_`c'[`iqz',`cqz'] = ///
								B[1,`aqz']	
						}

						mat colnames decomp_s_`c' = year `decomp_c' `decomp_g'


						
						// compute decomposition by group 
						tempvar g_1 
						qui gen `g_1' = 1 if `F' >= .99
						qui replace `g_1' = 0 if missing(`g_1')
						qui ineqdeco `inc_`c'_`period'' [fw=`weight'] , ///
							bygroup(`g_1') summarize 
						local b_theil 		= r(between_ge1) 
						local w_theil	 	= r(within_ge1)
						local top1_gini 	= r(gini_1) 
						local bot99_gini 	= r(gini_0) 
						mat decomp_g_`c' [`iqz',1] 	= `period'
						mat decomp_g_`c' [`iqz',2] 	= `b_theil'
						mat decomp_g_`c' [`iqz',3] 	= `w_theil'
						mat decomp_g_`c' [`iqz',4] 	= `top1_gini'
						mat decomp_g_`c' [`iqz',5] 	= `bot99_gini'
						mat colnames decomp_g_`c' = year b_theil w_theil ///
							t1_gini b99_gini 
						
						*marginal tax study 
						if `taxfill' == 2 {
							*loop over number of brackets   
							forvalues b = 1/`nrates' {
								
								*display progress 
								di as result "bckt `b'"
								local bplus = `b' + 1  
								
								*save min Ps
								qui sum `F' if `inc_`c'_`period'' >= `thr`b''
								local minP`b' = r(min)
								di as text " - coverage: P" ///
									round(`minP`b''*100, 0.01) _continue 
								*save max Ps 
								if `b' != `nrates' {
									qui sum `F' if ///
										`inc_`c'_`period'' >= `thr`b'' & ///
										`inc_`c'_`period'' < `thr`bplus''
								}
								else {
									qui sum `F' if ///
										`inc_`c'_`period'' >= `thr`b'' 
								}
								local maxP`b' = r(max)
								local frqP`b' = `maxP`b'' - `minP`b''
								local cov`b' = round(`frqP`b''*100, 0.01)
								di as text " - P" round(`maxP`b''*100, 0.01) ///
									" (" round(`frqP`b''*100, 0.01) ///
									"% of pop)"	
								
								*count ppl
								qui sum `weight' if ///
									inrange(`F', `minP`b'', `maxP`b'')
								local tpop`b' = r(sum) 
								di as text " - population: " ///
									round(`tpop`b'')
								*di as text " - checker: " ///
								*	round(`frqP`b'' * `poptot')
								
								*max taxable 
								if `b' != `nrates' {
									local maxtax`b' = `thr`bplus'' - `thr`b''
								}
								
								*tax base
								qui gen base`b' = ///
									`inc_`c'_`period'' - `thr`b'' if ///
									`F' >= `minP`b''
								if `b' != `nrates' {
									qui replace base`b' = `maxtax`b'' ///
										if base`b' > `maxtax`b'' & ///
										`F' >= `minP`b''
								}	
									 
								*tax duty 
								qui gen duty`b' = base`b' * (`rat`b'' / 100) 
								
								*prepare text 
								local rdminp`b': di %2.1f (`minP`b''*100)
								local bcktext `bcktext' ///
									text(`rat`nrates'' `minP`b'' ///
									"[`rat`b''%] P`rdminp`b''"  , ///
									orientation(vertical) placement(se) ///
									color(gs10))
							}
							
							*compute totals 
							local refinc = `avg_main' * `poptot'
							foreach x in duty base {
								qui egen the`x' = rowtotal(`x'*)
								qui replace the`x' = . if the`x' == 0 
								qui sum the`x' [w=`weight'], meanonly 
								local tot`x' = r(sum) 
								local rat`x' = `tot`x'' / `refinc' * 100
							}
							*compute effective tax rate 
							qui gen efftax = ///
								theduty / `inc_`c'_`period'' * 100 
								
							forvalues b = 1/`nrates' {
								local bcktlines_`c'_`period' ///
									`bcktlines_`c'_`period'' `minP`b''
							}	
							
							di as result "total" 
							di as text " - coverage: P" ///
								round(`minP1'*100,.01) " - P" ///
								round(`maxP`nrates''*100,.01) _continue
							di as text 	" (" round((1-`minP1')*100,.01) ///
								"% of pop)"
								
							*get contributions 
							local dutymill = round(`totduty'/10^6)
							di as text " - duty: `dutymill' mill."	
							forvalues b = 1/`nrates' {
								*get bracket's total income 
								qui sum `inc_`c'_`period''[w=`weight'] ///
									if inrange(`F', `minP`b'', `maxP`b''), ///
									meanonly
								local suminc`b' = r(sum) 
								*get their duty and base 
								foreach x in duty base {
									qui sum the`x' [w=`weight'] if ///
									inrange(`F', `minP`b'', `maxP`b''), ///
									meanonly 
									local `x'`b' = r(sum) 
								}
								
								*prepare fstline 
								local space "       "
								local fstline "`space'`fstline'`space'tramo`b'"
								
								*estimate avg etr
								local etr`b' = `duty`b'' / `suminc`b'' * 100
								local etr`b'rd: di %3.2f `etr`b''
								local etrtxt "`etrtxt'`space'`etr`b'rd'%"
									  
								*estimate tax incidence 
								local incid`b' = `duty`b'' / `totduty' * 100
								local incid`b'rd: di %2.1f `incid`b''
								local incidtxt "`incidtxt'`space'`incid`b'rd'%"
								
								*estimate average
								local space2 "   "
								local avg`b' = ///
									round((`suminc`b''/`tpop`b'')/10*6)
								local avg`b': di %-12.0gc `avg`b''	
								local avgtxt "`avgtxt'`space2'`avg`b''"
									
							}
								
							*prepare display of average etr
							local avgrat: di %3.2f `ratduty'
							local avgetr text(`ratduty' `minP1' ///
								"Promedio: `avgrat'%", ///
								placement(ne) color(maroon)) ///
								text(`ratduty' `minP1' ///
								"(recaudo: `dutymill' mill.)", ///
								placement(se) color(maroon))
							local poptotmill = round(`poptot' / 10^6, 0.1)	
							
							*graph mechanical 
							graph twoway  ///
								(line efftax `F', lcolor(maroon) ///
								lwidth(thick)) ///
								(function y = `ratduty', range(`minP1' 1) ///
								lcolor(maroon) lpattern(dot)) ///
								if !missing(efftax), ///
								xline(`bcktlines_`c'_`period'', ///
								lcolor(black) lpattern(dot)) ///
								`bcktext' `avgetr' ///
								note("{it:`space'  `fstline'}" ///
								"Tasas efectivas:`etrtxt'" ///
								"Parte carga fisc:`incidtxt'" ///
								"Base prom, mill:`avgtxt'" " " ///
								"{bf:Pob. total `poptotmill' millones}") ///
								ytit("Tasa efectiva de tributación (%)") ///
								xtit("Percentil") ylab(, angle(horizontal)) ///
								scheme(s1color) subtitle(,fcolor(white) ///
								lcolor(bluishgray)) scale(1.2) ///
								graphregion(color(white)) ///
								plotregion(lcolor(bluishgray))  ///
								legend(off) 
							tempfile tf 	
							qui graph export `tf`v'', as(png)
							qui putexcel set "`export'", ///
								sheet("fig_etr", replace) modify
							qui putexcel A1 = image(`tf`v'')	
					
						}
						
						//increase resolution of top 1%
						qui expand `weight' + 1 if `F' >= 0.99, gen(checker)
						qui keep if checker == 1 | `F' < 0.99
						qui replace `weight' = 1 if checker == 1
						qui sort `inc_`c'_`period''
						quietly	replace `freq' = `weight' / `poptot'
						quietly	replace `F' = sum(`freq'[_n - 1])	
					
						*check pop is the same 
						qui sum `weight', meanonly
						local newpop = r(sum)
						assert `poptot' - `newpop' == 0 
									
						*Fit Pareto to top X%
						if ("`smoothtop'" != "") {
							
							//get average income of the top X%
							local p0 = 0.95
							qui sum `inc_`c'_`period'' [w=`weight'] ///
								if `F' >= `p0' 
							local a = r(mean)
							
							*get ranks within top 10% (and save b)
							qui sum `weight' if `F' >= `p0', meanonly 
							local popt10 = r(sum)
							qui gen `freq_t10' = `weight' / `popt10' 
							qui gen `F_t10' = 1 - sum(`freq_t10'[_n-1]) ///
								if `F' >= `p0'
							
							*define b and mu (threshold of X%)
							qui gen `auxinc' = `F_t10' * `inc_`c'_`period'' 
							qui sum `auxinc' [w= `weight'], meanonly
							local b = r(mean) 
							qui sum `inc_`c'_`period'' ///
								if `F' >= `p0', meanonly 
							local mu = r(min) 
							
							*get xi and sigma 
							local xi = (`a' - 4*`b' + `mu' ) / (`a' - 2*`b')
							local sigma = (`a'-`mu') * (2*`b'-`mu') / (`a'-2*`b')
							
							*smoothen the top X% (w/o changing topavg)
							qui gen `p1' = `F' 
							qui gen `p2' = `F'[_n+1]
							qui gen `smooth_income' = ///
								`mu' + `sigma'/(`p2' - `p1')* ///
								(-((-1 + `p0')/(-1 + `p1'))^`xi' - ///
								((-1 + `p0') / (-1 + `p2'))^`xi'*(-1 + `p2') ///
								+ `p2' - `p2'*`xi' + `p1'*(-1 + ((-1 + `p0') / ///
								(-1 + `p1'))^`xi' + `xi'))/((-1 + `xi')*`xi') ///
								if _n != _N
							qui replace `smooth_income' = ///
								(`mu' *(-1 + `xi')*`xi' - `sigma'* ///
								(-1 + ((-1 + `p0')/(-1 + `p1'))^`xi' + `xi')) ///
								/((-1 + `xi')*`xi') if _n == _N
							*save correction factor 
							qui gen smooth_factor = ///
								`smooth_income' / `inc_`c'_`period'' ///
								if `F' >= `p0'
							qui replace `inc_`c'_`period'' = `smooth_income' ///
								if `F' >= `p0'	
						}
							
						*Estimate gini
						quietly	gen `fy'= `freq' * `inc_`c'_`period''
						quietly	gen `cumfy' = sum(`fy')
						qui sum `cumfy', meanonly
						local cumfy_max = r(max)
						quietly	gen `L' = `cumfy' / `cumfy_max'
						qui gen `d_eq' = (`F' - `L') * `weight' / `poptot'
						qui sum	`d_eq', meanonly
						local d_eq_tot = r(sum)
						local gini = `d_eq_tot'*2
						
						// Classify obs in 127 g-percentiles
						cap qui egen `ftile' = cut(`F'), ///
							at(0(0.01)0.99 0.991(0.001)0.999 ///
							0.9991(0.0001)0.9999 0.99991(0.00001)0.99999 1)
						
						//keep going if it works
						if _rc == 0 {
							
							*fill last obs 
							qui replace `ftile' = 0.99999 if missing(`ftile')
							
							//gather info to check consistency 
							qui sum `inc_`c'_`period'' [w = `weight'], meanonly 
							local suminc = r(sum)	
							qui sum `inc_`c'_`period'' [w = `weight'] ///
								if `F' >= 0.99, meanonly 
							local top1_check_`c'_`period' = r(sum)/`suminc' * 100
						
							// Top average 
							gsort -`F'
							qui gen `wy' = `inc_`c'_`period'' * `weight'
							cap drop topavg
							qui gen topavg = sum(`wy') / sum(`weight')
							
							*topaverages decomposition 
							foreach v in `decomposition' {
								if ("`smoothtop'" != "") {
									qui replace `v'`extension' = ///
										`v'`extension' * smooth_factor ///
										if !missing(smooth_factor)
								} 
								tempvar wy_`v'
								qui gen `wy_`v'' = `v'`extension' * `weight'
								qui gen topavg_`v' = ///
									sum(`wy_`v'') / sum(`weight')
							}
							sort `F'

							//composition 
							foreach v in `decomposition' {
								//prepare lines bracket composition 
								local list_coll`c'`period' "`list_coll`c'`period'' bckt_avg_`v'`extension' = `v'`extension'"
							}
							
							//count population 
							qui sum `weight' //if edad >= `edad'
							local adpop_`c'_`period' = r(sum)
							
							//harmonize missing and NA codes for sociodemo vars
							foreach v in categ5_p tamest_ee {
								if "`v'" == "categ5_p" local z = 6 
								if "`v'" == "tamest_ee" local z = 3 
								cap replace `v' = `z' if missing(`v')
								cap replace `v' = `z' if inlist(`v', -1, 99, 9)
								cap replace `v' = `z' if `v' == 0 & ///
									inlist("`c'", "SLV", "COL")
							}	
							
							*define labels for socioeconomic vars 
							global lab_sexo1 male 
							global lab_sexo2 female
							global lab_categ5_p1 employer 
							global lab_categ5_p2 employee  
							global lab_categ5_p3 domestic 
							global lab_categ5_p4 independ 
							global lab_categ5_p5 nonremun
							global lab_categ5_p6 no_categ			
							global lab_tamest_ee1 firmsize5less
							global lab_tamest_ee2 firmsize5more 
							global lab_tamest_ee3 firmsize_none
								
							// Collapse to 127 percentiles 
							qui collapse (min) thr = `inc_`c'_`period'' ///
								(mean) bckt_avg = `inc_`c'_`period'' ///
								`list_coll`c'`period'' ///
								(max) bckt_max = `inc_`c'_`period'' ///
								(min) `ftile_clean' = `F' ///
								bckt_min = `inc_`c'_`period'' ///
								(sum) bckt_sum_tot = `inc_`c'_`period'' ///
								(rawsum) /*pop_* inc_**/ ///
								wgts = `weight' [w = `weight'], by (`ftile')
							
							*save for later 
							tempfile collapsed_form
							qui save `collapsed_form'	
							
							if _rc == 0 {
								
								// build 127 percentiles again from scratch
								clear
								qui set obs 127
								*qui set obs 100
								qui gen `ftile_clean' = (_n - 1)/100 in 1/100
								qui replace `ftile_clean' ///
									= (99 + (_n - 100)/10)/100 in 101/109
								qui replace `ftile_clean' ///
									= (99.9 + (_n - 109)/100)/100 in 110/118
								qui replace `ftile_clean' ///
									= (99.99 + (_n - 118)/1000)/100 in 119/127
									
								*append clean cuts 	
								qui append using `collapsed_form'
								qui gsort `ftile_clean' -`ftile'
								
							
								*interpolate data 
								qui ds bckt_max bckt_min wgts ///
									`ftile_clean' `ftile' , not 
								foreach var in `r(varlist)' {
									qui mipolate `var' `ftile_clean', ///
										gen(ip_`var') linear 
									qui drop `var'
										qui rename ip_`var' `var'	
								}	
								
								*keep clean cuts 
								qui keep if missing(`ftile')
								qui drop `ftile'
								qui rename `ftile_clean' `ftile'
								qui replace `ftile' = ///
									round(`ftile' * 100000)	
								
								*get bracket population shares 
								qui gsort -`ftile' 
								qui gen `bckt_pop' = `ftile'[_n-1] - `ftile' 
								qui replace `bckt_pop' = 1 ///
									if `ftile' == 99999	
								qui gen sum_pop = sum(`bckt_pop')	
								
								foreach dv in `decomposition' {
									qui gen sh_`dv'`extension' = ///
										bckt_avg_`dv'`extension' / bckt_avg 
								}									
								
								*make bracket averages consistent with totavg
								qui sum bckt_avg [w = `bckt_pop'], meanonly
								local ipol_avg = r(mean)
								qui replace bckt_avg = ///
									bckt_avg * `avg_main' / `ipol_avg'
								qui replace thr = ///
									thr * `avg_main' / `ipol_avg'	
						
								*gen vars to enforce consistency of composition
								tempvar tot_decomp ratio_decom 
								qui egen `tot_decomp' = rowtotal(bckt_avg_*)
								qui gen `ratio_decom' = ///
									bckt_avg / `tot_decomp'		
								
								*loop over variables
								qui ds thr bckt_sum_tot sum_pop __*  ///
									  wgts `ratio_decom'  sh_*, not 
								foreach v in `r(varlist)' {
									
									*enforce consistency of components 
									local ext2 = ///
										subinstr("`v'", "bckt_avg", "", .) 
									
									if !inlist("`v'", "bckt_avg") {
										qui replace `v' = ///
											`v' * `ratio_decom' ///
										if `ratio_decom' > 0 ///
											& !missing(`ratio_decom')
									}
									
									*compute top averages	
									qui gen fy`ext2' = `v' * `bckt_pop' 
									qui gen sum_fy`ext2' = sum(fy`ext2')
									qui gen topavg`ext2' = ///
										sum_fy`ext2' / sum_pop
									
									*get general average 
									qui sum topavg`ext2' if `ftile' == 0 
									local avg`ext2' = r(sum)
									
									*get top shares 
									qui gen topsh`ext2' ///
										= topavg`ext2' / `avg`ext2'' * ///
										(sum_pop / 100000 )
									assert topsh`ext2'[127] == 1 | ///
										missing(topsh`ext2'[127]) 
									*get bracket shares 
									qui gen s`ext2' = `v' / `avg`ext2'' * ///
										(`bckt_pop'  / 100000)
									qui sum s`ext2', meanonly 
									local xyz = r(sum)
									qui assert round(`xyz'*10^5) == 10^5 ///
										if "`xyz'" != "0"
									
								}	
									
								*go back to decimals 
								qui replace `ftile' = `ftile' / 100000
								qui replace `bckt_pop' = `bckt_pop' / 100000
								
								*sort 
								sort `ftile'
								qui gen ftile = `ftile'	
								
								*clean
								qui rename topsh topshare
								
								//What share of total income by item?
								foreach v in `decomposition' {
									qui local sh_`v'_`c'_`period' = ///
										topavg_`v'[1] / topavg[1] 
								}
								
								// Total average  
								qui gen average = .
								qui replace average = `avg_main' in 1		
								
								// Inverted beta coefficient
								qui gen b = topavg/thr		
								
								// Fractile
								qui rename ftile p
								
								// Year
								qui gen year = `period' in 1
								qui gen country = "`c'" in 1	
								
								// Write Gini
								qui gen gini = `gini' in 1
								
								if "`bcktavg'" != ""{
									local addvars bckt_sum_tot bckt_sum_*
								} 
								
								// Order and save	
								order country year gini average p thr ///
									bckt_avg s  topavg topshare b topavg_* ///
									topsh* `addvars' 
								
								//save matrix for later 
								tempname mat_sum
								mkmat gini average p thr bckt_avg s topavg ///
									topshare b topavg_*, matrix(`mat_sum')
								mkmat gini average p thr bckt_avg s topavg ///
									topshare b topavg_*, matrix(_mat_sum)	
									
								//check consistency of all variables 
								assert bckt_avg >= thr	if bckt_avg > 0
								assert ///
									round(average[1] / topavg[1] * 10^5) ==10^5
								qui sum s, meanonly 
								assert round(r(sum) * 10^5) == 10^5
								
								
								//Fetch some summary stats for 1ry panel
								local b50_sh_`c'_`period' = 1 - topshare[51]
								local m40_sh_`c'_`period' = ///
									topshare[51] - topshare[91]
								local t10_sh_`c'_`period' = topshare[91]
								local t1_sh_`c'_`period' = topshare[100]
								local gini_`c'_`period' = gini[1]
								local average_`c'_`period' = average[1]
								
								*report big differences caused by interpolation  
								if (abs(`t1_sh_`c'_`period'' * ///
									100-`top1_check_`c'_`period'') > 0.1) {
									di as text "top one should be " ///
										`top1_check_`c'_`period''
									di as text "top one is: " ///
										`t1_sh_`c'_`period'' * 100
									di as result "diff in ppts: " ///
										`t1_sh_`c'_`period''* ///
										100 - `top1_check_`c'_`period''
								}
								
								//collect 2ry stats (composition)
								local it_test = 1 
								local it_test2 = 1 
								foreach v in `decomposition' {
									local b50c_`v'_`c'`period' = ///
										(1 - topsh_`v'[51]) * ///
										`sh_`v'_`c'_`period'' ///
										/ `b50_sh_`c'_`period''
									local m40c_`v'_`c'`period' = ///
										(topsh_`v'[51] - topsh_`v'[91]) * ///
										 `sh_`v'_`c'_`period'' / ///
										`m40_sh_`c'_`period''
									local t10c_`v'_`c'`period' = ///
										topsh_`v'[91] * ///
										`sh_`v'_`c'_`period'' ///
										/ `t10_sh_`c'_`period''
									local t1c_`v'_`c'`period' = ///
										topsh_`v'[100] * ///
										`sh_`v'_`c'_`period'' ///
										/ `t1_sh_`c'_`period''
										
									*check group shares by inc
									if `it_test2' == 1 {
										local test_tots2_`c'`period' ///
											`sh_`v'_`c'_`period''
									} 
									else {
										local test_tots2_`c'`period' ///
											`test_tots2_`c'`period'' ///
											+ `sh_`v'_`c'_`period''
									} 
									if `it_test2' == 1 {
										local it_test2 = 0
									} 
									
									*check sum of components by group
									foreach g in b50 m40 t10 t1 {
										if "``g'c_`v'_`c'`period''" != "." {
											if `it_test' == 1 {
												local `g'test_`c'`period' ///
													``g'c_`v'_`c'`period''	
											} 
											if `it_test' != 1 {
												local `g'test_`c'`period' ///
													``g'test_`c'`period'' ///
													+ ``g'c_`v'_`c'`period''
											} 
											if `it_test' == 1 {
												local it_test = 0 
											} 
										}
									}	
								}
								
								order country year gini average p thr ///
									bckt_avg s  topavg topshare b ///
									sh_* `addvars' 
								
								keep country year gini average p thr ///
									bckt_avg s topavg topshare b ///
									sh_* `addvars' 
								
								// Export to Excel
								if ("`export'" != "") {
									qui rename bckt_avg avg 
									qui rename topshare topsh
									local abc `unit'
									if "`unit'" == "act" local abc ind 
									qui renvars _all, presub(sh_`abc'_pre_)
									qui renvars _all, presub(sh_`abc'_pod_tot_)
									qui renvars _all, presub(sh_`abc'_pon_)
									qui renvars _all, presub(sh_`abc'_)
									qui renvars _all, presub(sh_`abc'_tax_)
									qui renvars _all, presub(tax_)
									qui renvars _all, postsub(_sca)
									qui renvars _all, postsub(_pre)
									qui renvars _all, postsub(_2)
									
									*check income composition 
									qui ds country year gini average p ///
										thr avg s topavg topsh b, not 
									local cvars `r(varlist)'	
									qui egen ccheck = rowtotal(`cvars')	
									qui replace ccheck = round(ccheck * 10^2)
									*assert ccheck == 10^2 | ccheck == 0 
									cap drop ccheck 
									qui export excel using "`export'", ///
									firstrow(variables) sheet("`c'`period'") ///
									sheetreplace keepcellfmt  	
								}
								
								di as text "ineqstats (06a): " _continue
								di as text "`c' `period' saved at $S_TIME."
								
								foreach g in b50 m40 t10 t1 {
								//do nothing 
								}
							}		
							
							else {
								display as error ///
									"There was a problem with " _continue
								display as error "`c' `period' (skipped)"
							}
						
						}
						
						else {
							display as error ///
								"There was a problem with " _continue
							display as error "`c' `period' (skipped)"
						}
					}
					
					else {
						display as error ///
						"Missing or empty variables in `c' `period' " ///
						"(`misvar_`c'_`period'') skipped"
					}
				}	
			}
		}
		
		//Summarize main info for all countries
		clear 
		local nobs = ///
			wordcount("`areas'") * (1 + `last_period' - `first_period')
		set obs `nobs'
		qui gen country = ""
		
		//Summarize primary variables 
		preserve
		
			//Generate empty vars
			foreach v in "year" "gini" "average" "adpop" "b50_sh" ///
				"m40_sh" "t10_sh" "t1_sh" {
				qui gen `v' = .
			}
			
			//Fill variables with a loop
			local iter = 1 
			foreach c in `areas' {
				forvalues period = `first_period'/`last_period'{
					qui replace country = "`c'" in `iter'
					qui replace year = `period' in `iter'
					foreach v in "gini" "average" "adpop" "b50_sh" ///
						"m40_sh" "t10_sh" "t1_sh" {
						if ("``v'_`c'_`period''" != "") {
							qui replace `v' = ``v'_`c'_`period'' ///
								in `iter'
						}
					}
				local iter = `iter' + 1
				}	
			}
			
			//Save in a sheet (country-year)
			if ("`export'" != "") {
				qui drop if missing(average)
				qui export excel using "`export'", ///
				firstrow(variables) sheet("Summary") ///
				sheetreplace keepcellfmt  	
			}
			display as text "Summary saved at $S_TIME"
		
		restore
		
		//Summarize info for composition
		
		//Empty variables
		qui gen year = . 
		foreach group in "tot" "b50" "m40" "t10" "t1" {
			foreach v in `decomposition' {
				qui gen `group'_sh_`v' = . 
			}
		}
		
		//Fill variables with locals (composition)
		local iter = 1 
		foreach c in `areas' {
			forvalues period = `first_period' / `last_period'{
				qui replace country = "`c'" in `iter'
				qui replace year = `period' in `iter'
				foreach group in "tot" "b50" "m40" "t10" "t1" {
					foreach v in `decomposition' {
						if ("`group'" != "tot" & ///
							"``group'c_`v'_`c'`period''" != "") {
							qui replace `group'_sh_`v' = ///
								``group'c_`v'_`c'`period'' ///
								in `iter'
						}		
						if ("`group'" == "tot" & ///
							"`sh_`v'_`c'_`period''" != "") {
							qui replace tot_sh_`v' = ///
							`sh_`v'_`c'_`period'' in `iter'	
						} 
					}
				}	
			local iter = `iter' + 1	
			}
		}	
		
		//Save in a sheet (country-year)
		if ("`export'" != "") {	
			*clean variable names 
			local abc `unit' 
			if "`unit'" == "act" local abc ind 
			qui reshape long tot t1 b50 m40 t10, ///
				i(country year) j(inctype) string	
			foreach bit in _sh_`abc'_pre _sh_`abc'_pod_tot _sca _pre ///
				_sh_`abc'_pon _sh_`abc'_tax sh_`abc' tax_ _2 _ {
				qui replace inctype = subinstr(inctype, "`bit'", "", .)
			} 
			qui ds country year inctype, not 
			local gps `r(varlist)'
			foreach g in `gps' {
				qui rename `g' val_`g'
			}
			qui reshape long val_, i(country year inctype) j(group) string
			qui rename val_ _sh 
			qui sort country year group inctype 
			qui order country year group 
			
			*check consistency 
			cap drop gptot 
			bysort country year group: egen gptot = total(_sh)
			cap drop if missing(_sh)
			qui replace gptot = round(gptot*10^2)
			*assert inirange(gptot, 99, 101)
			cap drop gptot 
			
			*return to wide mode 
			qui egen gpinc = concat(group inctype), punct(_)
			cap drop group inctype 
			qui reshape wide _sh, i(country year) j(gpinc) string
			qui renvars _all, presub(_sh)
			qui export excel using "`export'", ///
				firstrow(variables) sheet("Composition") ///
				sheetreplace keepcellfmt  	
		}
	}
	
	
	*export inequality decomposition 
	if ("`export'" != "") {	
		*make room  
		tempfile tfds tfdg 
		local i_tfd = 0 
		*loop over countries 
		foreach c in `areas' {
			local ++i_tfd 
			*append sginis and groups 
			foreach x in s g {
				clear
				qui svmat decomp_`x'_`c', names(col)
				qui gen country = "`c'"
				if `i_tfd' != 1 append using `tfd`x''
				qui save `tfd`x'', replace  
			}
		}
		*clean sgninis   
		qui use `tfds', clear
		local abc `unit'
		if "`unit'" == "act" local abc ind 
		foreach bit in `abc'_ pre_ pod_tot pon_ tax_ _sca _pre _2 _ {
			qui renvars _all, presub(`bit')
			qui renvars _all, postsub(`bit')
		}
		qui order country year 
		*export sginis 
		qui export excel using "`export'", ///
			firstrow(variables) sheet("sginis") ///
			sheetreplace keepcellfmt 		
			
		*export group decomposition 	
		qui use `tfdg', clear
		qui order country year 
		qui export excel using "`export'", ///
			firstrow(variables) sheet("gtheils") ///
			sheetreplace keepcellfmt 		
	}

	if ("`namelist'" != "summarize") { {
		display as error "`namelist' is not a valid subcommand"
		exit 198
	}
	
end	
