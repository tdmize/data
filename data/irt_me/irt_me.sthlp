{smcl}
{* 2018-09-19 Trenton D Mize}{...}
{title:Title}

{p2colset 5 16 16 1}{...}
{p2col:{cmd:irt_me} {hline 2}}Calculates marginal effects for the latent 
variable (Theta) after IRT models{p_end}
{p2colreset}{...}


{title:General syntax}


{p 4 18 2}
{cmd:irt_me} [{varlist}] {cmd:,} [options]
{p_end}

{marker overview}
{title:Overview}

{pstd}
{cmd:irt_me} calculates marginal effects for the latent variable (theta) after 
an IRT model. The latent variable is the independent variable; the variables 
specifed in the {it:varlist} are the observed items which are the dependent 
variables in an IRT model. If no {it:varlist} is specified, {cmd:irt_me} 
calculates marginal effects for theta across all of the observed items.

{pstd}
{cmd:irt_me} supports all models that can be estimated using the Stata 
{cmd:irt} commands and also models for continuous and count items  
({cmd:regress}, {cmd:poisson}, and {cmd:nbreg}). A mix of different item 
types is also allowed (e.g., a mix of binary and ordinal items). 

{marker required}
{dlgtab:Required Option for gsem models}

{p2colset 5 18 19 0}
{synopt:{opt latent(string)}} is required if {cmd:gsem} was used to fit the 
model of interest. This is the name of the latent variable you wish to obtain 
marginal effects for. The {opt latent( )} option should not be used if the 
model was fit with the {cmd:irt} command as {cmd:irt} automatically names the 
latent variable {it:Theta}.
{p_end}

{marker required}
{dlgtab:Options}

{p2colset 5 18 19 0}
{synopt:{opt model(string)}} specifies the name of saved model estimates to use. 
See {help estimates store} for saving model estimates. By default, {cmd:irt_me} 
will use the IRT/GSEM estimates in memory. If the relevant model estimates are 
not in memory, you must specify their name.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt dec:imals(#)}} changes the number of decimal places reported 
for the statistics. The default is 3. Any integer between 1 - 8 is allowed.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt start(#)}} specifies the starting value for the prediction used 
in the calculation of the marginal effect. The default is -0.5 for a default 
marginal effect estimate of a centered +1 unit change.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt end(#)}} specifies the ending value for the prediction used 
in the calculation of the marginal effect. The default is 0.5 for a default 
marginal effect estimate of a centered +1 unit change.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt range}} calculates marginal effects across the trimmed range 
of the predicted values of the latent variable theta. Predictions are made 
at the 1st percentile of theta (start) and at the 99th percentile of theta 
(end)
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt title(string)}} changes the title of the table of results. 
A default title is automatically included.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt help}} prints footnotes below the table describing what the 
columns in the table represent.
{p_end}

{title:Examples}

{phang} {stata webuse masc1: webuse masc1}{p_end}	

{phang} {stata irt 2pl q1 q2 q3 q4 q5: irt 2pl q1 q2 q3 q4 q5}{p_end}	
{phang} {stata irt_me, help: irt_me, help}{p_end}	

{phang} {stata gsem (Theta -> q1 q2 q3 q4 q5, logit), var(Theta@1): gsem (Theta -> q1 q2 q3 q4 q5, logit), var(Theta@1)}{p_end}	
{phang} {stata irt_me, latent(Theta): irt_me, latent(Theta)}{p_end}	
	

{title:Authorship}

{pstd} {cmd:irt_me} is written by Trenton D Mize (Departments of Sociology & 
Statistics [by courtesy] & The Methodology Center at Purdue University). 
Questions can be sent to tmize@purdue.edu {p_end}

{title:Citation}

{pstd} Please cite the use of irt_me as: {p_end}

	Mize, Trenton D. 2024. "Stata command for marginal effects from item 
	response theory models." https://www.trentonmize.com/software/irt_me 