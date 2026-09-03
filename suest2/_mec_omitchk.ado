*! _mec_omitchk v1.0.0 Trenton Mize 2026-08-18  | history: CHANGELOG-suest2.md (repo)

*v1.1.0: refuse rather than report an inequality built from omitted
*	coefficients. Stata marks an omitted factor level in the column name --
*	a token ending `o.' -- while `bn.' alone is an ordinary base level and
*	`bno.' is a base level that is also omitted. Measured against both arms
*	of probe_meineq_groups_v1_1.do: no balanced column is flagged and every
*	omitted one is.
*	This matters because nlcom does NOT fail on such a term. It returns
*	rc 0, a value of exactly 0 and a variance of exactly 0, so without this
*	check the command prints 0.000 with a standard error of 0.000.
capture program drop _mec_omitchk
program define _mec_omitchk, rclass
	version 16
	syntax , FOCal(string) [ WHEre(string) CMDname(string) ]
*	v1.0.0: the calling command's name is a parameter now that three
*		commands share this guard. It defaults to meinequality so an
*		unconverted call site keeps its exact previous wording.
	if trim(`"`cmdname'"') == ""  local cmdname "meinequality"
	local cn : colnames e(b)
	local bad ""
	foreach c of local cn {
*		only columns involving the focal variable can enter the statistic
		if strpos("`c'", ".`focal'") == 0  continue
*		split on # and test each factor token for the omitted annotation
		local parts = subinstr("`c'", "#", " ", .)
		foreach pt of local parts {
			local dotp = strpos("`pt'", ".")
			if `dotp' <= 1  continue
			local head = substr("`pt'", 1, `dotp' - 1)
			if substr("`head'", -1, 1) == "o" {
				local bad "`bad' `c'"
				continue, break
				}
			}
		}
	local nbad : word count `bad'
	if `nbad' > 0 {
		di _newline(1)
		di as err "{cmd:`cmdname'} cannot compute an ME inequality for "  /*
		*/ "{bf:`focal'}`where': `nbad' of its marginal predictions are "  /*
		*/ "{bf:omitted}, so the pairwise contrasts the statistic averages "  /*
		*/ "over do not all exist."
		di as err "This happens when a level of {bf:`focal'} is absent or "  /*
		*/ "collinear in one of the models. Refit on a sample where every "  /*
		*/ "level is estimable, or drop the affected level."
		di as text "Omitted predictions:"
		foreach c of local bad {
			di as text "    `c'"
			}
		exit 198
		}
	return scalar nomit = `nbad'
end

