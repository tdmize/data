{smcl}
{* 2018-03-19 Trenton D Mize}{...}
{title:Title}

{p2colset 5 16 16 1}{...}
{p2col:{cmd:balanceplot} {hline 2}}Plots of Imbalance Across Groups 
	of a Categorical Independent Variable{p_end}
{p2colreset}{...}


{title:General syntax}


{p 4 18 2}
{cmd:balanceplot} [{depvar}] [{varlist}] {ifin}{cmd:,}  
[{opt group(var)} {opt ref(var)} {opt ref2(var)} 
{opt graphop( )} {opt nosort} {opt nodropdv} {opt plotcommand}
{opt leg1( )} {opt leg2( )} {opt leftmargin( )} 
{opt table} {opt width( )} {opt decimals( )}]
{p_end}

{marker overview}
{title:Overview}

{pstd}
{cmd:balanceplot} produces dot plots of standardized imbalance statistics 
across groups of a categorical independent variable. Standarized imbalance 
statistics provide a useful way to present differences across covariates 
(specifed in {cmd: varlist}) for groups of the categorical independent variable 
(specified in option {opt group( )}) of interest. 
 
{pstd}
{cmd:balanceplot} calculates standardized imbalance statistics and plots them 
as a dotplot using {cmd:coefplot}. The table of means, t-tests for balance, 
and standardized imbalance statistics can be shown with the option {opt table}.
The base of the command that {cmd: balanceplot} uses to to make the plot can 
be shown with the option {opt plotcommand}.

{pstd}
Factor variables are allowed in the list of covariates specified in {opt varlist}. 
Covariates are assumed to be continuous unless they are specified as factor 
variables using Stata's {opt i.} syntax. For example, specifying {opt catvar} in the 
{opt varlist} will treat the variable as continuous. Specifying {opt i.catvar} 
will treat the variable as categorical.
{p_end}

{title:Options}

{p2colset 5 18 19 0}
{synopt:{opt group(var)}} is required. The group variable is the independent 
variable of interest for which imbalance statistics will be calculated. 
The group variable can have between 2 and 3 levels.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt base(var)}} sets the base category for the group variable. If option 
base( ) is not specified, the base cateory is set to 0 by default.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt ref(var)}} sets the reference category for the group variable. If option 
ref( ) is not specified, the reference cateory is set to 1 by default.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt ref2(var)}} sets the second reference category for the group variable. 
Option ref2( ) is only needed if the grouping variable has 3 or more levels. 
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt graphop( )}} allows options to control the look of the graph. 
Most common graph options available for Stata graphs can be used. For example, 
{opt title( )}, {opt xtitle( )}, {opt xlabel( )}, and many other graph 
options can be specified within the {opt graphop( )} option.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt nosort}} specifies the plot to be ordered (top to bottom) based on 
the order of the variables specified in the {opt varlist}. By default, {cmd: balanceplot} 
orders the plot based on the size of the imbalance statistics.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt nodropdv}} does not drop the dependent variable from the plot of 
imbalance statistics. By default, the dependent variable is not included in the 
plot.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt plotcommand}} returns the base of the command used to produce the 
dot plot of imbalance statistics. This is useful if a user wants to create a more 
complex plot than {cmd: balanceplot} can produce as it allows the user to create 
a plot from the raw matrix of imbalance statistics.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt leg1( )}} is only available when 3 or more levels of the group 
variable are specified. {opt leg1( )} specifies a legend label for the first comparison 
(base vs ref) shown in the plot. Note that {cmd: balanceplot} will provide a 
logical label for the graph by default. It is recommended to try the default 
before specifying an option.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt leg2( )}} is only available when 3 or more levels of the group 
variable are specified. {opt leg2( )} specifies a legend label for the second comparison 
(base vs ref2) shown in the plot. Note that {cmd: balanceplot} will provide a 
logical label for the graph by default. It is recommended to try the default 
before specifying an option.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt leftmargin( )}} specifies additional space to be provided on the left 
side of the graph. This is helpful if the labels for the variables are too long 
to fit on the default graph. The default is 0. Specify an additional % of plot space 
to increase the left margin. E.g. {opt leftmargin(10)} specifies an additional 10% of 
space on the plot be extended to the left.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt table}} returns the table of means for each level of the group variable, 
t-tests for imbalance, and the standardized imbalance statistics ("bias").
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt decimals( )}} specifies the number of decimal places to be displayed in 
the table of balance statistics (note, the {opt table} option must be specified). 
The default number of decimal places is 3. 
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt width( )}} specifies the width of the columns in the table of balance 
statistics (note, the {opt table} option must be specified). The default number 
is 10. Specify a larger width if more decimal places are requested with {opt decimals}.
{p_end}


{title:Examples}

{phang} {stata sysuse nlsw88: sysuse nlsw88}

{phang} {stata balanceplot wage age i.married i.collgrad i.south tenure ttl_exp, group(union): balanceplot wage age i.married i.collgrad i.south tenure ttl_exp, group(union)} {p_end}

{phang} {stata balanceplot wage age i.married i.collgrad i.south tenure ttl_exp, group(race) base(1) ref(2) ref2(3): balanceplot wage age i.married i.collgrad i.south tenure ttl_exp, group(race) base(1) ref(2) ref2(3)} {p_end}

{phang} {stata balanceplot wage age i.married i.collgrad i.south tenure ttl_exp, group(race) base(1) ref(2) ref2(3) graphop(xlab(-75(25)75)): balanceplot wage age i.married i.collgrad i.south tenure ttl_exp, group(race) base(1) ref(2) ref2(3) graphop(xlab(-75(25)75))} {p_end}

			
{title:Comments}

{pstd} Standardized imbalance is calculated based on the formulas from 
Rosenbaum and Rubin (1985). The graph is made using coefplot (Jann 2014).
{p_end}

{title:Authorship}

{pstd} balanceplot is written by Trenton D Mize, Department of Sociology, 
Purdue University. Questions can be sent to tmize@purdue.edu {p_end}

{title:References}

{pstd} Rosenbaum, Paul R. and Donald Rubin. 1985. "Constructing a Control Group 
Using Multivariate Matched Sampling Methods That Incorporate the Propensity Score." 
The American Statistician. {p_end}

{pstd} Jann, Ben. 2014. "Plotting regression coefficients and other estimates." 
Stata Journal.


