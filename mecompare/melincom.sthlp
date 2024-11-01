{smcl}
{* 2019-02-24 trenton mize}{...}
{title:Title}

{p2colset 5 16 17 2}{...}
{p2col:{cmd:melincom} {hline 2}}Computes linear combinations of 
{cmd:mecompare} estimates{p_end}
{p2colreset}{...}


{title:General syntax}

{p 6 18 2}
{cmd:melincom} {it:exp} [ {cmd:,} {it:options} ]
{p_end}

{p 4 4 2}
{it:exp} is the expression for a linear combination of estimates
from the last {cmd:mecompare} command. Estimates are referred
to by their order in the {cmd:mecompare} table which is documented in the 
{it:ME #} column of the {cmd:mecompare} table.

{p 4 4 2}
If a single number is listed as the expression, {cmd:melincom} repeats the 
marginal effect listed in the associated {cmd:mecompare} row; e.g. 
{cmd:melincom 3} will list the third marginal effect in the {cmd:mecompare} 
table. The true utility of {cmd:melincom} is to test linear combinations of 
the marginal effects listed in the {cmd:mecompare} table. 
E.g. {cmd:melincom 5 - 3} will test the equality of the fifth and third 
marginal effects in the {cmd:mecompare} table.
{p_end}


{title:Overview}

{pstd}
{cmd:melincom} uses {cmd:lincom} to compute linear combinations of marginal
effects from {cmd:mecompare}. This lets you estimates additional comparisons 
of effects that {cmd:mecompare} does not compute by default.
{p_end}

{pstd}
{cmd:melincom} must be run immediately following a {cmd:mecompare} command.
{p_end}


{title:Table of contents}

    {help mlincom##stats:Which statistics to display}
    {help mlincom##show:Controlling how results are displayed}
    {help mlincom##table:Adding results to prior results}
    {help mlincom##matrices:Matrices created}
    {help mlincom##examples:Examples}


{title:Options}
{marker stats}
{dlgtab:Statistics to include in the table}
{p2colset 8 25 25 0}
{synopt:{opt stat:istics(list)}}select statistics to
display. The following statistics can be included
in {it:list}.
{p_end}

{p2colset 10 23 22 12}{...}
{p2col :Name}Description{p_end}
{p2line}
{p2col :{ul:{bf:e}}{bf:stimate}}Estimated linear combination{p_end}
{p2col :{ul:{bf:l}}{bf:l}}Lower level bound of confidence interval{p_end}
{p2col :{ul:{bf:u}}{bf:l}}Upper level bound of confidence interval{p_end}
{p2col :{ul:{bf:p}}{bf:value}}p-value for test estimate is 0{p_end}
{p2col :{ul:{bf:s}}{bf:e}}Standard error of estimate{p_end}
{p2col :{bf:z}}z-value{p_end}
{p2col :{bf:noci}}Only display estimate{p_end}
{p2col :{bf:all}}Display all statistics{p_end}

{p2line}

{marker show}
{dlgtab:Controlling what is displayed}
{p2colset 8 24 25 0}

{synopt:{opt dec:imal(#)}}Number of decimal digits displayed in table.

{synopt:{opt rown:ame(string)}}Label for row of table. Can contain spaces. 
By default rows are numbered.

{synopt:{opt roweq:nm(string)}}Add row equation name to table. Cannot contain
spaces. Helpful to add one heading to related rows of the table. 
See {help matrix rownames}

{synopt:{opt labw:idth(#)}} changes the width of the leftmost column of the 
table that provides the labels for the row (specified in {opt rowname} option).
The default is 15. Any integer between 10 - 32 is allowed.

{synopt:{opt statw:idth(#)}} changes the width of the columns of the 
table that report the statistics (e.g. estimate, SE, pvalue, etc.). The 
default is 9. Any integer between 9 - 20 is allowed.

{synopt:{opt title(string)}}Display {it:string} above table as a title.

{synopt:{opt d:etail}}Show output from {cmd:lincom} in addition to the 
{cmd:melincom} table.

{marker table}
{dlgtab:Add results to the table}

{p 7 7 2}
Multiple results from {cmd:melincom} can be combined to make a table of 
results. You can add new rows to the {cmd:melincom} table in subsuquent calls 
to {cmd:melincom}.

{p2colset 8 15 15 0}

{synopt:{opt melincom clear}}Clear any saved results from prior calls to 
{cmd:melincom}. You should clear results before building a new table.

{synopt:{opt add}}Add results from current {cmd:melincom} command as a new row 
at the bottom of the saved {cmd:melincom} table. All of the {cmd:melincom} 
commands must include the same statistics from {opt stat()}.

{marker matrices}
{dlgtab:Matrices used by mlincom}

{p 7 7 2}
{cmd:melincom} saves the current table to the matrix {opt _melincom}, adding
them to what is in the matrix if option {cmd:add} is used. The matrix
has columns corresponding to the displayed results. In addition, the
matrix {opt _melincom_allstats} contains all statistics, not just those in
the table.


{marker examples}{...}
{dlgtab:Examples}


{pstd}{ul:{bf:Example 1}}{p_end}

{phang2}{stata sysuse nlsw88, clear: sysuse nlsw88, clear}{p_end}

{phang2}{stata logit union i.collgrad i.married age, vce(robust): logit union i.collgrad i.married aged, vce(robust)}{p_end}

{phang2}{stata estimates store mod1: estimates store mod1}{p_end}

{phang2}{stata logit union i.collgrad i.married age i.race, vce(robust): logit union i.collgrad i.married age i.race, vce(robust)}{p_end}

{phang2}{stata estimates store mod2: estimates store mod2}{p_end}

{phang2}{stata mecompare i.collgrad i.married, models(mod1 mod2): mecompare i.collgrad i.married, models(mod1 mod2)}{p_end}

{phang2}{stata melincom 5 - 1: melincom 5 - 1}{p_end}

{title:Authorship}

{pstd} {cmd:mecompare} and {cmd:melincom} are written by Trenton D Mize 
(Departments of Sociology & Statistics, Purdue University).
Questions can be sent to tmize@purdue.edu {p_end}

{pstd} {cmd:melincom} relies heavily on Long & Freese's (2014) SPost13 
{help mlincom} command to create the table. {p_end}

{title:References}

{pstd} Mize, Trenton D., Long Doan, and J. Scott Long. "A General Framework 
for Comparing Predictions and Marginal Effects Across Models." {p_end}

{pstd} Long, J. Scott and Jeremy Freese. 2014. 
{it:Regression Models for Categorical Dependent Variables Using Stata.} 
Third Edition. Stata Press.
{p_end}
