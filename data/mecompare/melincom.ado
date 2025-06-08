*****************
* melincom.ado
*****************

*NOTES: For use after mecompare. This programs interprets the globals that 
* mecompare sets to calculate additional tests of MEs/cross-model diffs 
* listed in the mecompare table; based on (and uses in parts) Long & Freese's
* mlincom

*! melincom version 0.1. 2019-03-18 | Mize
capture program drop melincom
program define melincom

    version 11.2
	
	syntax anything, ///
		[   /// Optional options which are passed directly to mlincom
			/// results to display
            STATS(string asis) STATistics(string asis) ///
            ALLstats /// all stats (p, z, se, level)
			COMMANDs /// show lincom command syntax
            Details /// show lincom output
            NOTABle /// only show lincom
        /// save results to matrix
            add save /// add results to matrix
        /// label matrix
            ROWName(string) label(string) /// row name for current estimate
            ROWEQnm(string) /// row eq name for current estimate
            ESTName(string asis) /// allow override margin name for estimate
        /// displaying matrix
            DECimals(integer 3) /// Digits when list matrix
			LABWidth(numlist >8 integer) /// width of leftmost column
			STATWidth(numlist >7 integer) /// width of stats columns
            title(string) /// Title when listing
		]
			
// User must specify "melincom clear" to clear the table
if "`anything'" == "clear" {
	mlincom, clear
	exit
	}	
	
*Set the statistics displayed in final table	
if "`statistics'" == "" {
	local stats = "estimate se pvalue"
	}
else {
	local stats = "`statistics'"
	}
	
if "`labwidth'" == "" {
	local twidth = 15
	}
	else {
	local twidth = `labwidth'
	}
if "`statwidth'" == "" {
	local width = 9
	}
	else {
	local width = `statwidth'
	}
	
	local numspecs : word count `anything'
	
//  decode expression (adapted from mlincom)

    local lc "`anything'"
    foreach c in ( ) + - {
        local lc = subinstr("`lc'","`c'"," `c' ",.)
    }

    local lcstr ""
    foreach e in `lc' {
        if ("`e'"=="(") local lcstr "`lcstr'("
        else if ("`e'"==")") local lcstr "`lcstr')"
        else if ("`e'"=="+") local lcstr "`lcstr'+"
        else if ("`e'"=="-") local lcstr "`lcstr'-"
        else {
            local i = int(real("`e'"))
            if `i' == . {
                display as error "unexpected missing value found"
                exit
            }
            else {
                local bnm  ${me__`e'}
                local lcstr "`lcstr'`bnm'"
            }
        }
    }
	
if "`commands'" != "" {
	di 	"lincom `lcstr'"
	}

mec_mlincom `lcstr', 	///
	stat(`statistics') `allstats' `details' `notable' `clear' ///
	`add' `save' rowname("`rowname'") label("`label'") ///
	roweq("`roweqnm'") estname("`estname'") dec(`decimals') ///
	width(`width') twidth(`twidth') title("`title'")
	
	
matrix _melincom = _mlincom		// Copy mlincom's matrices
matrix _melincom_allstats = _mlincom_allstats	

end

exit
