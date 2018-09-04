* Author: Trenton Mize & Bianca Manago
* dstable creates descriptive statistics tables

capture program drop dstable
*! dstable v1.0.2 Trenton Mize 2018-09-03
program define dstable, rclass
	version 15.0

	syntax varlist(min=1 fv) [if] [in], ///
		FILEname(string) ///		*  these are required options
		[STATs(string) ///	// these are optional options
		nformat(string) title(string) NOTEs(string) ///
		font(string) FONTSize(string) notesize(string) ///
		txtindent(string) SINGleborder SHEETname(string) ///
		group(varlist max=1)]
		
		
marksample touse, novarlist 	// allows missing values casewise
	
*Error out if if/in qualifiers specify no obs
qui count if `touse'
	local N = `r(N)'
	
	if `r(N)' == 0 {
	error 2000
	}
		
		
*Create blank excel sheet - name based on filename() specification
*	name the individual sheet if specified
if "`sheetname'" == "" {
	qui putexcel set "`filename'.xlsx", sheet("Descriptives Table") replace
	}

else {
	local nametext = `" `sheetname' "'
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
if "`nformat'" == "" {
	local nfmt = "#.00"
	}

else {
	local nfmt = `" `nformat' "'
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

local rownum = 5	// starting on Excel's 5th row so space for headings

*Count categories to determine if var is continuous, binary, or nominal	
foreach v in `varlist' {
	fvexpand `v'
	local numcats : word count `r(varlist)' 

*For continuous vars	
if `numcats' == 1 {

	local clab: variable label `v'
	qui putexcel B`rownum' = "`clab'", `lformat'

	local ++rownum
	}
	

*For binary vars
if `numcats' == 2 {
	
	local varname = substr("`v'", 3, .)		// Strip the i. prefix
	local blab: variable label `varname'
	qui putexcel B`rownum' = "`blab'", `lformat'
	
	local 	++rownum	
	}
	
	
*For nominal (3+ category) vars
if `numcats' >= 3 {

	*Label the overall variable
	local varname = substr("`v'", 3, .)		// Strip the i. prefix
	local nomlab: variable label `varname'
	qui putexcel B`rownum' = "`nomlab'", `lformat' italic underline
	
	local ++ rownum		// new row so each category is below
	
	*Label each individual category
	qui levelsof `varname', local(levels)
	local lbe : value label `varname'

	foreach i of local levels {
		local c`i' : label `lbe' `i'
		qui putexcel B`rownum' = "    `c`i''", `lformat'
		
		local ++ rownum	
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

	forvalues i = 1/`numgroups' {
		fvexpand i.`group'
		
		local grp`i' 		: word `i' of `r(varlist)'
		local grpnum`i'		= substr("`grp`i''", 1, 1)
	}
}	


**************************************
// Calculate descriptive statistics //				
**************************************

*Create temporary DV to use in regress for estat sum	
tempvar 	y
qui gen 	`y' = runiform()

*Default is to report mean/prop and SD
if "`stats'" == "" {
	local statlist = "mean sd"
	}

else {
	local statlist = `" `stats' "'
	}	

local numstats 	: word count `statlist'	

*Set column #s (letters in Excel) based on number of stats 	
local letters `" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L" "M" "N" "O" "P" "Q" "R" "S" "T" "U" "V" "W" "X" Y" Z" "'

local rownum = 5	// starting on Excel's 5th row so space for headings


// Loop through each group
forvalues k = 1/`numgroups' { 


// Loop through requested stats //
forvalues i = 1/`numstats' {

*Put next group's stats to the right of the preceeding group
local letnum 	= `i' + `numstats' * (`k' - 1)

/*
*NOTE: This only works between 1st and 2nd groups set of stats?
if `k' > 1 {		// adding an empty column to separate groups
	local letnum = `letnum' + 1 
	}
*/
	
local letter 	: word `letnum' of `letters'
local stat 		: word `i' of `statlist'

*Label the current column with nicer formatted stat name
local meancol 		= "Mean"
local sdcol 		= "SD"
local ncol 			= "n"
local freqcol 		= "Freq."
local countcol 		= "Freq."
local mincol 		= "Min."
local maxcol 		= "Max."
local sumcol 		= "Sum"
local rangecol 		= "Range"
local rcol 			= "Range"
local variancecol 	= "Var."
local varcol 		= "Var."
local vcol 			= "Var."
local cvcol 		= "SD/Mean"
local semeancol 	= "SE(Mean)"
local skewnesscol 	= "Skew."
local skewcol 		= "Skew."
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
local iqrcol 		= "IQR"

qui putexcel `letter'4 = `" ``stat'col' "', ///
			hcenter font("`fonttype'", "`fsize'")


*Count categories to determine if var is continuous, binary, or nominal	
foreach v in `varlist' {
	fvexpand `v'
	local numcats : word count `r(varlist)' 

	
// For continuous vars //	
if `numcats' == 1 & "`stat'" != "freq" & "`stat'" != "count" & "`stat'" != "n" {
	
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
	
	
// For binary vars //
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
	
	
// For nominal (3+ category) vars //
else if `numcats' >= 3 & "`stat'" == "mean" {

	local ++ rownum		// new row so each category is below
	
	local varname = substr("`v'", 3, .)		// Strip the i. prefix
	
	*Calculate proportions
	qui reg `y' ibn.`varname' if `touse' `groupspec' `grpnum`k'', nocon
	qui estat sum
	mat temp = r(stats)
		
	*Loop through all categories for proportions
	forvalues i = 1/`numcats' {
	
	local tempnum = `i' + 1
		
	local propnom = temp[`tempnum',1]
	qui putexcel `letter'`rownum' = `propnom', `nformat'
	
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
	qui tab `varname' if `touse' `groupspec' `grpnum`k'', matcell(freq)
			
	*Loop through all categories for frequencies
	forvalues i = 1/`numcats' {
	
	local freqnom = freq[`i',1]
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
	qui putexcel B3:D`rightcol'3 = "`titletext'",  ///
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
	qui putexcel B2:D`rightcol'2 = "`titletext'",  ///
				merge left border(bottom, `lineset') ///
				font("`fonttype'", "`fsize'") bold
	}
}
	
*Add single line under stats column headings
qui putexcel B4:`rightcol'4, border(bottom)

*If group( ) specified, add group name labels above corresponding stats
local leftnum 	= 1
local rightnum 	= `numstats'
	
if "`group'" != "" {
	qui levelsof `group', local(levels)
	local lbe : value label `group'

	foreach i of local levels {
	
	fvexpand `group'
	local numgroups : word count `r(varlist)' 

	local left 		: word `leftnum' of `letters'
	local right 	: word `rightnum' of `letters'
	
	local c`i' : label `lbe' `i'
	qui putexcel `left'3:`right'3 = "`c`i''", ///
		underline merge hcenter font("`fonttype'", "`fsize'") 

	local leftnum = `leftnum' + `numstats'
	local rightnum = `rightnum' + `numstats'
	}
}


*Add double-line formatting to bottom of the table		
local 			bottom = `numrows' + 4
qui putexcel 	B`bottom':`rightcol'`bottom', border(bottom, `lineset')

*Add footnotes to table
local 		notestart = `bottom' + 1

if "`notes'" != "" {
	local notetext = `" `notes' "'
	qui putexcel B`notestart':`rightcol'`notestart' = "`notetext'", ///
			merge left txtwrap font("`fonttype'", "`notefsize'")
	}

	
end	

	
