{smcl}
{* 2018-09-19 Trenton D Mize}{...}
{title:Title}

{p2colset 5 16 16 1}{...}
{p2col:{cmd:lca_entropy} {hline 2}}Calculates an entropy statistic 
for latent class analysis (LCA) models{p_end}
{p2colreset}{...}

{title:General syntax}

{p 4 18 2}
{cmd:lca_entropy} {cmd:,} [options]
{p_end}

{marker overview}
{title:Overview}

{pstd}
{cmd:lca_entropy} calculates an entropy statistic for latent class 
analysis (LCA) models. The LCA must have been fit using {cmd:gsem} with the 
{opt lclass( )} option.

{marker required}
{dlgtab:Options}

{p2colset 5 18 19 0}
{synopt:{opt model(string)}} specifies the name of saved model estimates to use. 
See {help estimates store} for saving model estimates. By default, 
{cmd:lca_entropy} will use the {cmd:gsem} estimates in memory. 
If the relevant model estimates are not in memory, you must specify their name.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt dec:imals(#)}} changes the number of decimal places reported 
for the entropy statistic. The default is 3. Any integer between 1 - 5 is allowed.
{p_end}

{title:Examples}

{phang} {stata "use http://www.stata-press.com/data/r15/gsem_lca1, clear": use http://www.stata-press.com/data/r15/gsem_lca1, clear}{p_end}	
{phang} {stata gsem ( -> accident play insurance stock), logit lclass(C 2): gsem ( -> accident play insurance stock), logit lclass(C 2)}{p_end}	
{phang} {stata lca_entropy: lca_entropy}{p_end}	


{title:Authorship}

{pstd} {cmd:irt_me} is written by Trenton D Mize (Department of Sociology & 
Advanced Methodologies, Purdue University). 
Questions can be sent to tmize@purdue.edu {p_end}

{title:References}

{pstd} The entropy statistic is calculated using the formula shown in 
Collins and Lanza (2010) page 75. {p_end}

{pstd} Collins, Linda M. and Stephanie T. Lanza. 2010. 
{it:Latent Class and Latent Transition Analysis}. Wiley.{p_end}

