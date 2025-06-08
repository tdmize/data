* Author: Trenton Mize & Bianca Manago
* desctable creates descriptive statistics tables in Excel

*2018-11-12 : Now, if a var label does not exist the varname is used to label
*	the relevant row. Also, added option to use varnames instead of labels
*2018-12-02: Group option did not handle non-standard # gaps. This has been
*	fixed and max width of table increased

capture program drop desctable
*! desctable v1.0.5 Trenton Mize 2018-12-02
program define desctable, rclass
	version 14.1

	syntax varlist(min=1 fv) [if] [in], ///
		FILEname(string) ///		*  these are required options
		[STATs(string) ///	// these are optional options
		DECimals(string) listwise title(string) NOTEs(string) ///
		font(string) FONTSize(string) notesize(string) ///
		txtindent(string) SINGleborder SHEETname(string) ///
		group(varlist max=1) VARNAMEs noborder]

		
// Default to casewise handling of missing values unless listwise is specified		
if "`listwise'" == "" {	
	marksample touse, novarlist 
	}

else {
	marksample touse
	}
	
	
***********************************
// Check Options / Report Errors //	
***********************************

*Error out if if/in qualifiers specify no obs
qui count if `touse'
	local N = `r(N)'
	
	if `r(N)' == 0 {
	error 2000
	}

*Define which stats to calculaute; default is to report mean/prop and SD
if "`stats'" == "" {
	local statlist = "mean sd"
	}

else {
	local statlist = `" `stats' "'
	}	

local numstats 	: word count `statlist'	

*Error out if svy/mi stat is requested but data is not svyset/mi set
forvalues s = 1/`numstats' {

local stat 	: word `s' of `statlist'

if "`stat'" == "svymean" | "`stat'" == "svysemean" {
	qui svyset
	local svysetting = "`r(settings)'"
		
	if "`svysetting'" == ", clear" {
	di as err "{cmd:svy} statistic requested but data is not {cmd:svyset}."
	di as err "Use {cmd:svyset} to set survey design settings for data."
	exit
	}
	}

if "`stat'" == "mimean" | "`stat'" == "misemean" ///
		| "`stat'" == "misvymean" | "`stat'" == "misvysemean" {
	qui mi query
	local mistyle = r(style)
	
	if "`mistyle'" == "." {
	di as err "{cmd:mi} statistic requested but data is not {cmd:mi set}."
	di as err "Use {cmd:mi set} to set imputation settings for data."
	exit
	}
	}

*Error out if mi stat is requested and group option is specified
if "`group'" != "" {
	if "`stat'" == "mimean" | "`stat'" == "misemean" | "`stat'" == "misvymean" ///
		| "`stat'" == "misvysemean" {

	di as err "You specified both a {opt mi} statistic and the {opt group} option."
	di as err "This is reasonable, but not currently supported by {cmd:desctable}."
	di as err "If you can figure out how to program this, you can be third author."
	exit
	}
	}
}

*Explain reported N when listwise option is used
if "`listwise'" != "" {	
	di in yellow "With the {opt listwise} option, the sample size reported at the top of the table"
	di in yellow "is the # of complete observations for the variables specified"
	di in yellow "(i.e. # of obs with no missing data)." 
	}
	
*Give warning message in output if sample size varies across vars
local missvarlist " "
foreach v in `varlist' {
	fvexpand `v' 
	local numcats : word count `r(varlist)' 
	
	if `numcats' >= 2 {
		local varname = substr("`v'", 3, .)		// Strip the i. prefix
	}

	else {
		local varname = "`v'"
	}
local missvarlist " `missvarlist' `varname' "
}

qui misstable patterns `missvarlist' if `touse', asis
local missvars = r(vars) 	
local missnum = r(N_incomplete)

if `missnum' != 0 {

	if strpos("`statlist'", "mimean") |  strpos("`statlist'", "misemean") | ///
			strpos("`statlist'", "misvy") {
	
	di in yellow "Sample size reported at the top of the table is # of total observations in the data."
	di in yellow "Most statistics reported by {cmd:desctable} utilize only complete observations;"
	di in yellow "any {cmd:mi} statistic also utilizes imputed data." 
	di _newline(1)
	di in yellow "To view the # of complete, incomplete, and imputed observations use {stata mi describe:mi describe}."
	}
		
	else {
	di in yellow "Sample size reported at the top of the table is # of total observations in the data."
	di _newline(1)
	di in red "The sample size varies across variables in the table due to missing data."
	di in red "`missnum' observations have some missing data on variables in the table."
	di in red " - Variables with missing data are:"
	di in yellow `"    `missvars' "'
	di _newline(1)
	di in yellow "Use the {opt stat(n)} option to show the # of non-missing obs for each variable."
	di in yellow "Use the {opt listwise} option to exclude observations with any missing data."
	}
}
		
*Create blank excel sheet - name based on filename() specification
*	name the individual sheet if specified
if "`sheetname'" == "" {
	qui putexcel set "`filename'.xlsx", sheet("Descriptives Table") replace
	}

else {
	local nametext = `"`sheetname'"'
	qui putexcel set "`filename'.xlsx", sheet("`nametext'") replace
	}

*Set fonts/sizes for table
if "`font'" == "" {
	local fonttype = "timesnewroman"
	}

else {
	local fonttype = `" `font' "'
	}

if "`fontsize'" == "" {
	local fsize = "11"
	}

else {
	local fsize = `" `fontsize' "'
	}

if "`notesize'" == "" {
	local notefsize = "9"
	}
  
else {
	local notefsize = `" `notesize' "'
	}
	
*Set the indentation of numbers from right side of column
if "`txtindent'" == "" {
	local indent = "1"
	}

else {
	local indent = `" `txtindent' "'
	}
	
*Set the format of numbers (e.g. number of decimal places)
if "`decimals'" == "" {
	local nfmt = "#.00"
	}

if "`decimals'" == "0" {
	local nfmt = "#"
	}
	
if "`decimals'" == "1" {
	local nfmt = "#.0"
	}

if "`decimals'" == "2" {
	local nfmt = "#.00"
	}
	
if "`decimals'" == "3" {
	local nfmt = "#.000"
	}
	
if "`decimals'" == "4" {
	local nfmt = "#.0000"
	}
	
if "`decimals'" == "5" {
	local nfmt = "#.00000"
	}
	
*Formats for the numbers and labels
local nformat "nformat("`nfmt'") txtindent(`indent') right font("`fonttype'", "`fsize'")"
local fformat "nformat(#) txtindent(`indent') right font("`fonttype'", "`fsize'")"
local lformat "left font("`fonttype'", "`fsize'")"

*Option to set single line formatting for borders of table (double is default)
if "`singleborder'" == "" {
	local lineset = "double"
	}
else {
	local lineset = ""
	}	
	
	
// Determine # of rows needed in table //
local numrows = 0
			
foreach v in `varlist' {
	fvexpand `v' 
	local numcats : word count `r(varlist)' 
	
*For continuous vars	
if `numcats' == 1 {
	local numrows = `numrows' + 1
	}
	
*For binary vars
if `numcats' == 2 {
	local numrows = `numrows' + 1
	}
	
*For nominal (3+ category) vars
*NOTE: Adding an extra row for the variable label above the categories
if `numcats' >= 3 {
	local numrows = `numrows' + `numcats' + 1
	}
}	


******************************************
// Label the rows with var/value labels //				
******************************************
if "`varnames'" == "" {
	local uselabels = 1
	}
else {
	local uselabels = 0
	}	
	
local rownum = 5	// starting on Excel's 5th row so space for headings

*Count categories to determine if var is continuous, binary, or nominal	
foreach v in `varlist' {
	fvexpand `v'
	local numcats : word count `r(varlist)' 

*For continuous vars	
if `numcats' == 1 {
	
	qui ds `v', has(varlabel)
	if "`r(varlist)'" !=  "" & `uselabels' == 1 {
		local clab: variable label `v'
		}
	else {
		local clab `v' 
		}
	qui putexcel B`rownum' = "`clab'", `lformat'
	local ++rownum
	}
	

*For binary vars
if `numcats' == 2 {

	local varname = substr("`v'", 3, .)		// Strip the i. prefix
	
	qui ds `varname', has(varlabel)
	if "`r(varlist)'" !=  "" & `uselabels' == 1 {
		local blab: variable label `varname'
		}
	else {
		local blab `varname' 
		}		
	qui putexcel B`rownum' = "`blab'", `lformat'
	local 	++rownum	
	}
	
	
*For nominal (3+ category) vars
if `numcats' >= 3 {

	local varname = substr("`v'", 3, .)		// Strip the i. prefix

	*Label the overall variable
	qui ds `varname', has(varlabel)
	if "`r(varlist)'" !=  "" & `uselabels' == 1 {
		local nomlab: variable label `varname'
		}
	else {
		local nomlab `varname' 
		}		
	
	qui putexcel B`rownum' = "`nomlab'", `lformat' italic underline
	local ++ rownum		// new row so each category is below
	
	*Label each individual category
	qui levelsof `varname', local(levels)
	
	qui ds `varname', has(vallabel)
	if "`r(varlist)'" !=  "" {
		local lbe : value label `varname'
	
		foreach i of local levels {
			local c`i' : label `lbe' `i'
			qui putexcel B`rownum' = "    `c`i''", `lformat'		
		
			local ++ rownum	
		}
	}
	else {
		foreach i of local levels {
			local c`i' "`i'"
			qui putexcel B`rownum' = "    `c`i''", `lformat'	
		
			local ++ rownum	
		}	
	}	
	}
}	


**************************************
// Parse the group( ) options //				
**************************************
if "`group'" == "" {
	local groupspec = ""
	local numgroups = 1
	}

else {

	fvexpand i.`group'
	local numgroups : word count `r(varlist)' 
	local groupspec = `" & `group' == "'
	local groupname = " `group' "
	
	forvalues i = 1/`numgroups' {
		qui levelsof `group', local(groupcats)
		
		local grp`i' 		: word `i' of `groupcats'
		local grpnum`i'		: word `i' of `groupcats'
	}
}	

	
**************************************
// Calculate descriptive statistics //				
**************************************

*Create temporary DV to use in regress for estat sum	
tempvar 	y
qui gen 	`y' = runiform()

*Set column #s (letters in Excel) based on number of stats/group 	
local letters `" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L" "M" "N" "O" "P" "Q" "'
local letters `"`letters' "R" "S" "T" "U" "V" "W" "X" "Y" "Z" "'
local letters `"`letters' "AA" "AB" "AC" "AD" "AE" "AF" "AG" "AH" "AI" "AJ" "'
local letters `"`letters' "AK" "AL" "AM" "AN" "AO" "AP" "AQ" "AR" "AS" "AT" "'
local letters `"`letters' "AU" "AV" "AW" "AX" "AY" "AZ" "'
local letters `"`letters' "BA" "BB" "BC" "BD" "BE" "BF" "BG" "BH" "BI" "BJ" "'
local letters `"`letters' "BK" "BL" "BM" "BN" "BO" "BP" "BQ" "BR" "BS" "BT" "'
local letters `"`letters' "BU" "BV" "BW" "BX" "BY" "BZ" "'
local letters `"`letters' "CA" "CB" "CC" "CD" "CE" "CF" "CG" "CH" "CI" "CJ" "'
local letters `"`letters' "CK" "CL" "CM" "CN" "CO" "CP" "CQ" "CR" "CS" "CT" "'
local letters `"`letters' "CU" "CV" "CW" "CX" "CY" "CZ" "'
local letters `"`letters' "DA" "DB" "DC" "DD" "DE" "DF" "DG" "DH" "DI" "DJ" "'
local letters `"`letters' "DK" "DL" "DM" "DN" "DO" "DP" "DQ" "DR" "DS" "DT" "'
local letters `"`letters' "DU" "DV" "DW" "DX" "DY" "DZ" "'

local rownum 	= 5	// starting on Excel's 5th row so space for headings

	
// Loop through each group
forvalues k = 1/`numgroups' { 

// Loop through requested stats //
forvalues i = 1/`numstats' {

*Put next group's stats to the right of the preceeding group
local letnum 	= `i' + `numstats' * (`k' - 1)

local letter 	: word `letnum' of `letters'
local stat 		: word `i' of `statlist'

*Label the current column with nicer formatted stat name
local meancol 		= "Mean/Prop."
local sdcol 		= "SD  "
local ncol 			= "n  "
local freqcol 		= "Freq.  "
local countcol 		= "Freq.  "
local mincol 		= "Min.  "
local maxcol 		= "Max.  "
local sumcol 		= "Sum  "
local rangecol 		= "Range  "
local rcol 			= "Range  "
local variancecol 	= "Var.  "
local varcol 		= "Var.  "
local vcol 			= "Var.  "
local cvcol 		= "SD/Mean"
local semeancol 	= "SE(Mean)"
local skewnesscol 	= "Skew.  "
local skewcol 		= "Skew.  "
local kurtosiscol	= "Kurtosis"
local kurcol 		= "Kurtosis"
local kcol 			= "Kurtosis"
local mediancol 	= "Median"
local medcol 		= "Median"
local p1col 		= "1st Perc."
local p5col 		= "5th Perc."
local p10col 		= "10th Perc."
local p25col 		= "25th Perc."
local p50col 		= "50th Perc."
local p75col 		= "75th Perc."
local p90col		= "90th Perc."
local p95col 		= "95th Perc."
local p99col 		= "99th Perc."
local iqrcol 		= "IQR  "
local svymeancol 	= "Svy. Mean"
local svysemeancol	= "Svy. SE(Mean)"
local mimeancol		= "MI Mean"
local misemeancol	= "MI SE(Mean)"
local misvymeancol	= "MI Svy. Mean"
local misvysemeancol = "MI Svy. SE(Mean)"

qui putexcel `letter'4 = `" ``stat'col' "', ///
			right font("`fonttype'", "`fsize'")


*Count categories to determine if var is continuous, binary, or nominal	
foreach v in `varlist' {
	fvexpand `v'
	local numcats : word count `r(varlist)' 


*************************	
// For continuous vars //	
*************************	

if `numcats' == 1 & "`stat'" != "freq" & "`stat'" != "count" ///
		& "`stat'" != "n" & "`stat'" != "svymean" ///
		& "`stat'" != "svysemean" & "`stat'" != "mimean" ///
		& "`stat'" != "misemean" & "`stat'" != "misvymean"  ///
		& "`stat'" != "misvysemean" {
	
	qui tabstat `v' if `touse' `groupspec' `grpnum`k'', stat("`stat'") save
	mat temp = r(StatTotal)

	local statcon = temp[1,1]
	qui putexcel `letter'`rownum' = `statcon', `nformat'
	
	local ++rownum
	}

else if `numcats' == 1 & "`stat'" == "n" {
	
	qui tabstat `v' if `touse' `groupspec' `grpnum`k'', stat("`stat'") save
	mat temp = r(StatTotal)

	local ncon = temp[1,1]
	qui putexcel `letter'`rownum' = `ncon', `fformat'
	
	local ++rownum
	}
	
else if `numcats' == 1 & "`stat'" == "svymean" {
	
	qui svy: mean `v' if `touse' `groupspec' `grpnum`k''
	mat temp = r(table)

	local smeancon = temp[1,1]
	qui putexcel `letter'`rownum' = `smeancon', `nformat'
	
	local ++rownum
	}
	
else if `numcats' == 1 & "`stat'" == "svysemean" {
	
	qui svy: mean `v' if `touse' `groupspec' `grpnum`k''
	mat temp = r(table)

	local secon = temp[2,1]
	qui putexcel `letter'`rownum' = `secon', `nformat'
	
	local ++rownum
	}
		
else if `numcats' == 1 & "`stat'" == "mimean" {
	
	qui mi est: mean `v' if `touse' `groupspec' `grpnum`k''
	mat temp = r(table)

	local mimeancon = temp[1,1]
	qui putexcel `letter'`rownum' = `mimeancon', `nformat'
	
	local ++rownum
	}

else if `numcats' == 1 & "`stat'" == "misemean" {
	
	qui mi est: mean `v' if `touse' `groupspec' `grpnum`k''
	mat temp = r(table)

	local misecon = temp[2,1]
	qui putexcel `letter'`rownum' = `misecon', `nformat'
	
	local ++rownum
	}	
	
else if `numcats' == 1 & "`stat'" == "misvymean" {
	
	qui mi est: svy: mean `v' if `touse' `groupspec' `grpnum`k''
	mat temp = r(table)

	local mimeancon = temp[1,1]
	qui putexcel `letter'`rownum' = `mimeancon', `nformat'
	
	local ++rownum
	}

else if `numcats' == 1 & "`stat'" == "misvysemean" {
	
	qui mi est: svy: mean `v' if `touse' `groupspec' `grpnum`k''
	mat temp = r(table)

	local misecon = temp[2,1]
	qui putexcel `letter'`rownum' = `misecon', `nformat'
	
	local ++rownum
	}	
	
	
*********************	
// For binary vars //
*********************	

else if `numcats' == 2 & "`stat'" == "mean" {
	
	local varname = substr("`v'", 3, .)		// Strip the i. prefix
	
	*Calculate proportion (note: need this instead of tabstat in case
	* binary var is not coded 0/1)
	qui reg `y' i.`varname' if `touse' `groupspec' `grpnum`k''
	qui estat sum
	mat temp = r(stats)
	
	local propbin = temp[2,1]
	qui putexcel `letter'`rownum' = `propbin', `nformat'
	
	local 	++rownum	
	}

else if `numcats' == 2 & "`stat'" == "n" {
	
	local varname = substr("`v'", 3, .)		// Strip the i. prefix
	
	*Calculate n
	qui tabstat `varname' if `touse' `groupspec' `grpnum`k'', stat("`stat'") save
	mat temp = r(StatTotal)

	local nbin = temp[1,1]
	qui putexcel `letter'`rownum' = `nbin', `fformat'
	
	local 	++rownum	
	}	
	
else if `numcats' == 2 & "`stat'" == "svymean" {
	
	local varname = substr("`v'", 3, .)		// Strip the i. prefix
	
	qui svy: mean `varname' if `touse' `groupspec' `grpnum`k''
	mat temp = r(table)

	local spropbin = temp[1,1]
	qui putexcel `letter'`rownum' = `spropbin', `nformat'
	
	local 	++rownum	
	}	
	
else if `numcats' == 2 & "`stat'" == "mimean" {
	
	local varname = substr("`v'", 3, .)		// Strip the i. prefix
	
	qui mi est: mean `varname' if `touse' `groupspec' `grpnum`k''
	mat temp = r(table)

	local mipropbin = temp[1,1]
	qui putexcel `letter'`rownum' = `mipropbin', `nformat'
	
	local 	++rownum	
	}	
	
else if `numcats' == 2 & "`stat'" == "misvymean" {
	
	local varname = substr("`v'", 3, .)		// Strip the i. prefix
	
	qui mi est: svy: mean `varname' if `touse' `groupspec' `grpnum`k''
	mat temp = r(table)

	local mipropbin = temp[1,1]
	qui putexcel `letter'`rownum' = `mipropbin', `nformat'
	
	local 	++rownum	
	}	


************************************	
// For nominal (3+ category) vars //
************************************
	
else if `numcats' >= 3 & "`stat'" == "mean" {

	local ++ rownum		// new row so each category is below
	local varname = substr("`v'", 3, .)		// Strip the i. prefix
	
	*Calculate frequencies
	qui tab `varname' `groupname' if `touse', matcell(freq)
			
	*Loop through all categories for frequencies / total n for group
	forvalues i = 1/`numcats' {
	
	*Calculate total n for that group
	qui tabstat `varname' if `touse' `groupspec' `grpnum`k'', stat(n) save
	mat tempn = r(StatTotal)
	local groupn = tempn[1,1]
	
	local freqnom = freq[`i',`k']
	
	local propcat = `freqnom' / `groupn'

	if `freqnom' == 0 {
		local propcat = "."
		}
	
	qui putexcel `letter'`rownum' = `propcat', `nformat'
	
	local ++ rownum
	}
	}	

else if `numcats' >= 3 & "`stat'" == "svymean" {
	
	local ++ rownum		// new row so each category is below
	local varname = substr("`v'", 3, .)		// Strip the i. prefix
	
	qui svy: tab `varname' `groupname' if `touse', col
	mat freq = e(Prop)
	
	*Calculate column total
	local coltot = 0
	forvalues i = 1/`numcats' {
		local coltot = freq[`i',`k'] + `coltot' 
		}
		
	*Loop through all categories for svy proportions for group
	forvalues i = 1/`numcats' {
	
	local spropnom = freq[`i',`k']
	local svprop = `spropnom' / `coltot'
	
	if `spropnom' == 0 {
		local svprop = "."
		}
	
	qui putexcel `letter'`rownum' = `svprop', `nformat'
	
	local ++ rownum
	}
	}

else if `numcats' >= 3 & "`stat'" == "mimean" {
	
	local ++ rownum		// new row so each category is below
	local varname = substr("`v'", 3, .)		// Strip the i. prefix
	
	qui mi est: prop `varname' if `touse' `groupspec' `grpnum`k''
	mat freq = r(table)
	
	*Loop through all categories for mi est proportions for group
	forvalues i = 1/`numcats' {
	
	local mipropnom = freq[`k',`i']
	
	if `mipropnom' == 0 {
		local mipropnom = "."
		}
	
	qui putexcel `letter'`rownum' = `mipropnom', `nformat'
	
	local ++ rownum
	}
	}

else if `numcats' >= 3 & "`stat'" == "misvymean" {
	
	local ++ rownum		// new row so each category is below
	local varname = substr("`v'", 3, .)		// Strip the i. prefix
	
	qui mi est: svy: prop `varname' if `touse' `groupspec' `grpnum`k''
	mat freq = r(table)
	
	*Loop through all categories for mi est proportions for group
	forvalues i = 1/`numcats' {
	
	local mipropnom = freq[`k',`i']
	
	if `mipropnom' == 0 {
		local mipropnom = "."
		}
	
	qui putexcel `letter'`rownum' = `mipropnom', `nformat'
	
	local ++ rownum
	}
	}
	
else if `numcats' >= 3 & "`stat'" == "n" {

	local varname = substr("`v'", 3, .)		// Strip the i. prefix
	
	*Calculate n
	qui tabstat `varname' if `touse' `groupspec' `grpnum`k'', stat("`stat'") save
	mat temp = r(StatTotal)

	local nnom = temp[1,1]
	qui putexcel `letter'`rownum' = `nnom', `fformat'
	
	local ++ rownum
	
	*Loop to skip over each individual category rows
	forvalues i = 1/`numcats' {
		local ++ rownum
	}
	}
	
else if `numcats' >= 3 & "`stat'" == "freq" | "`stat'" == "count" {

	local ++ rownum		// new row so each category is below
	local varname = substr("`v'", 3, .)		// Strip the i. prefix
	
	*Calculate frequencies
	qui tab `varname' `groupname' if `touse', matcell(freq)
			
	*Loop through all categories for frequencies / total n for group
	forvalues i = 1/`numcats' {
	
	*Calculate total n for that group
	qui tabstat `varname' if `touse' `groupspec' `grpnum`k'', stat(n) save
	mat tempn = r(StatTotal)
	local groupn = tempn[1,1]
	
	local freqnom = freq[`i',`k']
	
	if `freqnom' == 0 {
		local freqnom = "."
		}
	
	qui putexcel `letter'`rownum' = `freqnom', `fformat'
	
	local ++ rownum
	}
	}	

else {
	if `numcats' == 1 | `numcats' == 2 {
		local ++rownum
	}
	else if `numcats' >= 3 {
		local rownum = `rownum' + `numcats' + 1
	}
}
}
local rownum = `rownum' - `numrows'		// start back at first row
di "." _cont	// add dot to output every time column is completed
}
}


**************************************
// Format and Title the Excel Table //
**************************************

*Grab the furthest right column letter
if "`group'" == "" {
	local rightcol : word `numstats' of `letters'
	}

else {
	local rightnum = `numstats' * `numgroups'
	local rightcol : word `rightnum' of `letters'
	}	


*Add a basic title at the top of the table; change name if specified
if "`group'" == "" {
	if "`title'" == "" {
	qui putexcel B3:`rightcol'3 = "Table #: Descriptive Statistics (N = `N')",  ///
				merge left border(bottom, `lineset') ///
				font("`fonttype'", "`fsize'") bold
	}

	else {
	local titletext = `" `title' "'
	qui putexcel B3:`rightcol'3 = "`titletext'",  ///
				merge left border(bottom, `lineset') ///
				font("`fonttype'", "`fsize'") bold
	}
}
	
if "`group'" != "" {
	if "`title'" == "" {
	qui putexcel B2:`rightcol'2 = "Table #: Descriptive Statistics (N = `N')",  ///
				merge left border(bottom, `lineset') ///
				font("`fonttype'", "`fsize'") bold
	}

	else {
	local titletext = `" `title' "'
	qui putexcel B2:`rightcol'2 = "`titletext'",  ///
				merge left border(bottom, `lineset') ///
				font("`fonttype'", "`fsize'") bold
	}
}
	
*Add single line under stats column headings
qui putexcel B4:`rightcol'4, border(bottom)

*Add double-line formatting to bottom of the table		
local 			bottom = `numrows' + 4
qui putexcel 	B`bottom':`rightcol'`bottom', border(bottom, `lineset')

*If group( ) specified, add group name labels above corresponding stats
if "`noborder'" == "" {
	local borderop = ", border(right, dotted)"
	}

else {
	local borderop = ""
	}
	
local leftnum 	= 1
local rightnum 	= `numstats'
	
if "`group'" != "" {
	qui levelsof `group', local(levels)
	local lbe : value label `group'

	foreach i of local levels {
	
	fvexpand i.`group'
	local numgroups : word count `r(varlist)' 

	local left 		: word `leftnum' of `letters'
	local right 	: word `rightnum' of `letters'

	local c`i' : label `lbe' `i'
	qui putexcel `left'3:`right'3 = "`c`i''", ///
		underline merge hcenter font("`fonttype'", "`fsize'") 

	*Adding dotted right border between groups except for last group
	if `i' != `numgroups' {
		qui putexcel `right'3:`right'`bottom' `borderop'
		}
	
	local leftnum = `leftnum' + `numstats'
	local rightnum = `rightnum' + `numstats'
	}
}


*Add footnotes to table
local 		notestart = `bottom' + 1

if "`notes'" != "" {
	local notetext = `" `notes' "'
	qui putexcel B`notestart':`rightcol'`notestart' = "`notetext'", ///
			merge left txtwrap font("`fonttype'", "`notefsize'")
	}


*Display a note for where the table is saved
di _newline(1)
di in white "Descriptive statistics table has been saved in the folder:"
pwd
	
end	

	
