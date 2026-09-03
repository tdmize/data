{smcl}
{* 2026-07-30 Trenton D Mize}{...}
{title:Title}

{p2colset 5 18 18 1}{...}
{p2col:{cmd:melincom} {hline 2}}retired; replaced by {help metest}{p_end}
{p2colreset}{...}

{title:Description}

{pstd}
{cmd:melincom} has been retired. Its replacement is {help metest}, which takes
the same {it:ME #} references, so most calls translate directly:

{p 8 8 2}{cmd:melincom 1 - 2}{space 8}becomes{space 3}{cmd:metest 1 - 2}{p_end}
{p 8 8 2}{cmd:melincom 1 - 2, add}{space 3}becomes{space 3}{cmd:metest 1 - 2, add}{p_end}
{p 8 8 2}{cmd:melincom clear}{space 8}becomes{space 3}{cmd:metest, clear}{p_end}

{pstd}
{cmd:metest} additionally accepts coefficient names, multiplication and
division, nonlinear functions, and equality tests, and it can be used after any
estimation command rather than only after {cmd:mecompare}.

{title:Also see}

{psee}
{help metest}, {help mecompare}
