*! mecomp v1.0.0 Trenton Mize 2026-07-30  | history: CHANGELOG-mecompare.md (repo)

*Short-name alias for mecompare, so that mecomp and mecompare are
*	interchangeable. Stata does not abbreviate ado-commands, so the shorter
*	name has to exist as its own file; the help file documents the command as
*	{cmdab:mecomp:are} on that basis.
*
*	Everything typed after mecomp is handed to mecompare unchanged, so the
*	varlist, if/in, weights and every option behave identically -- including
*	replay (mecomp on its own) and mecomp, coeflegend.
*
*	Deliberately NOT declared eclass. mecompare posts e(b)/e(V) itself and
*	those results persist through a plain wrapper; this follows Stata's own
*	reg.ado, which wraps regress the same way.

capture program drop mecomp
program define mecomp
	version 16.0
	mecompare `0'
end
