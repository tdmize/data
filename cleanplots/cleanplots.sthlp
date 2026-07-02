{smcl}
{* 2026-07-02 Trenton D Mize}{...}
{title:Title}

{p2colset 5 16 16 1}{...}
{p2col:{cmd:cleanplots} {hline 2}}Graphics scheme that implements best 
data visualization practices. Default color choices are effective in both 
color and when printed in grayscale. Colors are chosen to be color-blind friendly. {p_end}
{p2colreset}{...}

{title:Overview}

{pstd}
{cmd:cleanplots} changes the default look and feel of Stata graphics. 
The choices of colors, markers, gridlines, and other aspects of the figure 
follow best data visualization practices. 

{pstd}
The choices for colors and markers allow for graphics that are effective when 
used in color but that can also be easily distinguished when printed in 
grayscale. The colors are also color-blind friendly.

{pstd}
For more information and to see examples, see the 
{browse "https://www.trentonmize.com/software/cleanplots": cleanplots website here}.

{pstd}
Many of the features of cleanplots are adapted from the excellent black and 
white colorscheme plotplain 
{browse "https://www.dropbox.com/s/m5viis9oybgkept/FigureScheme.pdf?dl=0": which you can read about here}.

{title:Using cleanplots}

{pstd}
To change your graphics scheme to {cmd:cleanplots} use the command: 

{phang2} {stata set scheme cleanplots, perm: set scheme cleanplots, perm}

{pstd}
Stata's default graphic scheme is {cmd:s2color}. To change back to the default: 

{phang2} {stata set scheme s2color, perm: set scheme s2color, perm}

{title:Authorship}

{pstd} {cmd:cleanplots} is written by Trenton D Mize (Departments of Sociology 
& Statistics [by courtesy] & The Methodology Center at Purdue University). 
Questions can be sent to tmize@purdue.edu {p_end}

{title:Updates}

{pstd} {cmd:cleanplots} was overhauled on 2026-07-02 to ensure all 10 colors 
and choices of lines, markers, etc are color-blind friendly and work as well as 
possible in black and white. When using 6 or more colors, I recommnend including 
markers or similar features of plots that aid in distinguishing parts of the 
graph (e.g., different lines). {cmd:cleanplots} ensures that the first 10 
features of a graph (e.g., lines or markers) are distinguishable if both color 
and line/markers are used. {p_end}

{title:Citation}

{pstd} In general, I do not think the use of a graphics scheme requires citation. 
So for most cases, feel free to use cleanplots without citation. 
But, if you need/want a citation you can cite cleanplots as: {p_end}

Mize, Trenton D. 2017. "cleanplots: Stata graphics scheme for easy and 
effective data visualizations." https://www.trentonmize.com/software/cleanplots 
