{smcl}
{* 2018-08-23 Trenton D Mize}{...}
{title:Title}

{p2colset 5 16 16 1}{...}
{p2col:{cmd:usetdm} {hline 2}}Command to load datasets from the web for
	classes and workshop {p_end}
{p2colreset}{...}

{title:General syntax}

{p 4 18 2}
{cmd:usetdm} [dataname] {cmd:,} [{opt clear}] 

{marker overview}
{title:Overview}

{pstd}
{cmd:usetdm} loads datasets from the web to recreate the examples from 
various classes and workshops. 
 
{pstd}
Option {opt clear} must be specified if another dataset is currently in memory.

{pstd} Datasets available include: addhealth4, gss, hrs06, pew16, tenure, 
usstates, uscounty, world, and many more. To see the full list, 
{browse "https://tdmize.github.io/data/data.html": click here}.
{p_end}

{title:Examples}

{phang} usetdm gss, clear

{phang} usetdm addhealth4, clear {p_end}

{title:Additional Materials}

{pstd} Class and workshop materials are available 
{browse "https://www.trentonmize.com/teaching": on the author's website.}{p_end}

{title:Authorship}

{pstd} usetdm is written by Trenton D Mize, Department of Sociology, 
Purdue University. Questions can be sent to tmize@purdue.edu {p_end}




