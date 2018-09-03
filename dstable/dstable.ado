* Author: Trenton Mize & Bianca Manago
* dstable creates descriptive statistics tables

capture program drop dstable
*! dstable v1.0.1 Trenton Mize 2018-09-01
program define dstable, rclass
	version 15.0

	syntax varlist(min=1 fv) [if] [in], ///
		FILEname(string) ///		*  these are required options
		[STATs(string) ///	// these are optional options
		nformat(string) title(string) NOTEs(string) ///
		font(string) FONTSize(string) notesize(string) ///
		txtindent(string) SINGleborder SHEETname(string)]
		
		
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
	putexcel set "`filename'.xlsx", sheet("Descriptives Table") replace
	}

else {
	local nametext = `" `sheetname' "'
	putexcel set "`filename'.xlsx", sheet("`nametext'") replace
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
	local notefsize = "10"
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

noisily di "`numrows'"


******************************************
// Label the rows with var/value labels //				
******************************************

local rownum = 4	// starting on Excel's 4th row for space and headings

*Count categories to determine if var is continuous, binary, or nominal	
foreach v in `varlist' {
	fvexpand `v'
	local numcats : word count `r(varlist)' 

*For continuous vars	
if `numcats' == 1 {

	local clab: variable label `v'
	putexcel B`rownum' = "`clab'", `lformat'

	local ++rownum
	}
	

*For binary vars
if `numcats' == 2 {
	
	local varname = substr("`v'", 3, .)		// Strip the i. prefix
	local blab: variable label `varname'
	putexcel B`rownum' = "`blab'", `lformat'
	
	local 	++rownum	
	}
	
	
*For nominal (3+ category) vars
if `numcats' >= 3 {

	*Label the overall variable
	local varname = substr("`v'", 3, .)		// Strip the i. prefix
	local nomlab: variable label `varname'
	putexcel B`rownum' = "`nomlab'", `lformat' italic underline
	
	local ++ rownum		// new row so each category is below
	
	*Label each individual category
	levelsof `varname', local(levels)
	local lbe : value label `varname'

	foreach i of local levels {
		local c`i' : label `lbe' `i'
		putexcel B`rownum' = "    `c`i''", `lformat'
		
		local ++ rownum	
	}
	}
}	


**************************************
// Calculate descriptive statistics //				
**************************************

*Create temporary DV to use in regress for estat sum	
tempvar 	y_999
gen 		y_999 = runiform()
sum 		y_999

*Default is to report mean/prop and SD
if "`stats'" == "" {
	local statlist = "mean sd"
	}

else {
	local statlist = `" `stats' "'
	}	

local numstats 	: word count `statlist'	

*Set column #s (letters in Excel) based on number of stats 	
local letters `" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L" "M" "N" "O" "P" "Q" "'

local rownum = 4	// starting on Excel's 4th row for space and headings


// Loop through requested stats //
forvalues i = 1/`numstats' {

local letter 	: word `i' of `letters'
local stat 		: word `i' of `statlist'

*Label the current column with nicer formatted stat name
local meancol 		= "Mean/Prop."
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

putexcel 	`letter'3 = `" ``stat'col' "', ///
			hcenter font("`fonttype'", "`fsize'")


*Count categories to determine if var is continuous, binary, or nominal	
foreach v in `varlist' {
	fvexpand `v'
	local numcats : word count `r(varlist)' 

	
// For continuous vars //	
if `numcats' == 1 & "`stat'" != "freq" & "`stat'" != "count" & "`stat'" != "n" {
	
	tabstat `v' if `touse', stat("`stat'") save
	mat temp = r(StatTotal)

	local statcon = temp[1,1]
	putexcel `letter'`rownum' = `statcon', `nformat'
	
	local ++rownum
	}

else if `numcats' == 1 & "`stat'" == "n" {
	
	tabstat `v' if `touse', stat("`stat'") save
	mat temp = r(StatTotal)

	local ncon = temp[1,1]
	putexcel `letter'`rownum' = `ncon', `fformat'
	
	local ++rownum
	}
	
	
// For binary vars //
else if `numcats' == 2 & "`stat'" == "mean" {
	
	local varname = substr("`v'", 3, .)		// Strip the i. prefix
	
	*Calculate proportion (note: need this instead of tabstat in case
	* binary var is not coded 0/1)
	reg y_999 i.`varname' if `touse'
	estat sum
	mat temp = r(stats)
	
	local propbin = temp[2,1]
	putexcel `letter'`rownum' = `propbin', `nformat'
	
	local 	++rownum	
	}

else if `numcats' == 2 & "`stat'" == "n" {
	
	local varname = substr("`v'", 3, .)		// Strip the i. prefix
	
	*Calculate n
	tabstat `varname' if `touse', stat("`stat'") save
	mat temp = r(StatTotal)

	local nbin = temp[1,1]
	putexcel `letter'`rownum' = `nbin', `fformat'
	
	local 	++rownum	
	}	
	
	
// For nominal (3+ category) vars //
else if `numcats' >= 3 & "`stat'" == "mean" {

	local ++ rownum		// new row so each category is below
	
	local varname = substr("`v'", 3, .)		// Strip the i. prefix
	
	*Calculate proportions
	reg y_999 ibn.`varname' if `touse', nocon
	estat sum
	mat temp = r(stats)
		
	*Loop through all categories for proportions
	forvalues i = 1/`numcats' {
	
	local tempnum = `i' + 1
		
	local propnom = temp[`tempnum',1]
	putexcel `letter'`rownum' = `propnom', `nformat'
	
	local ++ rownum
	}
	}

else if `numcats' >= 3 & "`stat'" == "n" {

	local varname = substr("`v'", 3, .)		// Strip the i. prefix
	
	*Calculate n
	tabstat `varname' if `touse', stat("`stat'") save
	mat temp = r(StatTotal)

	local nnom = temp[1,1]
	putexcel `letter'`rownum' = `nnom', `fformat'
	
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
	tab `varname' if `touse', matcell(freq)
			
	*Loop through all categories for frequencies
	forvalues i = 1/`numcats' {
	
	local freqnom = freq[`i',1]
	putexcel `letter'`rownum' = `freqnom', `fformat'
	
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


**************************************
// Format and Title the Excel Table //
**************************************

*Grab the furthest right column letter
local rightcol : word `numstats' of `letters'

*Add a basic title at the top of the table; change name if specified
if "`title'" == "" {
	putexcel 	B2:`rightcol'2 = "Table #: Descriptive Statistics (N = `N')",  ///
				merge left border(bottom, `lineset') ///
				font("`fonttype'", "`fsize'") bold
		}

else {
	local titletext = `" `title' "'
	putexcel 	B2:D`rightcol'2 = "`titletext'",  ///
				merge left border(bottom, `lineset') ///
				font("`fonttype'", "`fsize'") bold
	}
	
*Add single line under stats column headings
putexcel 	B3:`rightcol'3, border(bottom)


*Add double-line formatting to bottom of the table		
local 		bottom = `numrows' + 3
putexcel 	B`bottom':`rightcol'`bottom', border(bottom, `lineset')

*Add footnotes to table
local 		notestart = `bottom' + 1

if "`notes'" != "" {
	local notetext = `" `notes' "'
	putexcel 	B`notestart':`rightcol'`notestart' = "`notetext'", ///
			merge left txtwrap font("`fonttype'", "`notefsize'")
	}

else {
	}
	


end	

	