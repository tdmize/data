{smcl}
{* 2018-03-21 Trenton D Mize}{...}
{title:Title}

{p2colset 5 16 16 1}{...}
{p2col:{cmd:usedmv} {hline 2}}Command to load datasets from the web for
	Data & Model Visualization Workshop{p_end}
{p2colreset}{...}

{title:General syntax}

{p 4 18 2}
{cmd:usedmv} [dataname] {cmd:,} [{opt clear}] 

{marker overview}
{title:Overview}

{pstd}
{cmd:usedmv} loads datasets from the web to recreate the examples for the
Data & Model Visualization workshop. 
 
{pstd}
Option {opt clear} must be specified if another dataset is currently in memory.

{pstd} Datasets available include: addhealth4, gss, hrs06, pew16, tenure, 
usstates, uscounty, & world. 
{p_end}

{title:Examples}

{phang} usedmv gss, clear

{phang} usedmv addhealth4, clear {p_end}

{title:Additional Materials}

{pstd} Workshop materials are available at trentonmize.com/teaching/dmv {p_end}

{title:Authorship}

{pstd} usedmv is written by Trenton D Mize, Department of Sociology, 
Purdue University. Questions can be sent to tmize@purdue.edu {p_end}




