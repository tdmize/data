{smcl}
{* 2019-03-22 Trenton D Mize}{...}
{title:Title}

{p2colset 5 16 16 1}{...}
{p2col:{cmd:irt_coef} {hline 2}}Calculates y* standardized coefficients 
(discrimination parameters) for binary and ordinal IRT models{p_end}
{p2colreset}{...}


{title:General syntax}


{p 4 18 2}
{cmd:irt_coef} [{varlist}] {cmd:,} [options]
{p_end}

{marker overview}
{title:Overview}

{pstd}
{cmd:irt_coef} calculates y* standardized coefficients (discrimination 
parameters) for binary and ordinal IRT models. The raw coefficient, standard 
error, and p-value are also reported alongside the y* standardized coefficient.

{marker required}
{dlgtab:Required Option for gsem models}

{p2colset 5 18 19 0}
{synopt:{opt latent(name)}} is required if {cmd:gsem} was used to fit the 
model of interest. This is the name of the latent variable that is the 
indepenent variable (the items are the dependent variables [i.e. the y's]). 
The {opt latent( )} option should not be used if the model was fit with 
the {cmd:irt} command as {cmd:irt} automatically names the latent 
variable {it:Theta}.
{p_end}

{marker required}
{dlgtab:Options}

{p2colset 5 18 19 0}
{synopt:{opt model(name)}} specifies the name of saved model estimates to use. 
See {help estimates store} for saving model estimates. By default, {cmd:irt_coef} 
will use the IRT/GSEM estimates in memory. If the relevant model estimates are 
not in memory, you must specify their name.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt dec:imals(#)}} changes the number of decimal places reported 
for the statistics. The default is 3. Any integer between 1 - 8 is allowed.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt sort}} orders the rows of the table based on the values of the 
y* standardized coefficients. 
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

{phang} {stata webuse charity: webuse charity}{p_end}	

{phang} {stata irt grm ta1 ta2 ta3 ta4 ta5: irt grm ta1 ta2 ta3 ta4 ta5}{p_end}	
{phang} {stata irt_coef, help: irt_coef, help}{p_end}	

{phang} {stata gsem (Theta -> ta1 ta2 ta3 ta4 ta5, ologit), var(Theta@1): gsem (Theta -> ta1 ta2 ta3 ta4 ta5, ologit), var(Theta@1)}{p_end}	
{phang} {stata irt_coef, latent(Theta): irt_coef, latent(Theta)}{p_end}	
	
{title:Comments}

{pstd} For details on y* standardized coefficients generally see Long 1997 
(pages 69-71; 128-130). In the context of IRT models, see Bartholomew et al. 
2008 (pages 224-225; 259-260).
	
{title:Authorship}

{pstd} {cmd:irt_coef} is written by Trenton D Mize (Departments of Sociology 
& Statistics [by courtesy] & The Methodology Center at Purdue University). 
Questions can be sent to tmize@purdue.edu {p_end}

{title:Citation}

{pstd} Please cite the use of irt_coef as: {p_end}

Mize, Trenton D. 2024. "irt_coef: Stata command for y*-standardized 
coefficients in item response theory models." https://www.trentonmize.com/software/irt_coef

{title:References}

{pstd} Bartholomew, David J., Fiona Steele, Irini Moustaki, and Jane I. Galbrath. 
2008. {it:Analysis of Multivariate Social Science Data}. Second Edition. CRC 
Press.

{pstd} Long, J. Scott. 1997. 
{it:Regression Models for Categorical and Limited Dependent Variables}. Sage.
{p_end}
