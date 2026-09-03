*! melincom (RETIRED) Trenton Mize 2026-07-30

*melincom has been replaced by metest. This file is a stub: it exists so that
*	upgrading the package overwrites any previously installed melincom.ado.
*	net install does not delete files that have left a package, so without
*	this stub an existing user would keep running the old command -- which
*	returned rc 0 on failure, making errors look like successes.

capture program drop melincom
program define melincom
	version 16.0
	di _newline(1)
	di as err "{cmd:melincom} has been retired and replaced by {cmd:metest}."
	di _newline(1)
	di as text "{cmd:metest} takes the same {it:ME #} references, so most calls " /*
	*/ "translate directly:"
	di as text "        {cmd:melincom 1 - 2}        {c |}->  {cmd:metest 1 - 2}"
	di as text "        {cmd:melincom 1 - 2, add}   {c |}->  {cmd:metest 1 - 2, add}"
	di as text "        {cmd:melincom clear}        {c |}->  {cmd:metest, clear}"
	di _newline(1)
	di as text "{cmd:metest} also accepts coefficient names, multiplication and " /*
	*/ "division, nonlinear"
	di as text "functions, and equality tests, and it works after any estimation " /*
	*/ "command, not"
	di as text "only after {cmd:mecompare}. See {help metest}."
	di _newline(1)
	exit 198
end
