{smcl}
{* 2026-07-10 Trenton D Mize}{...}
{title:Title}

{p2colset 5 16 16 1}{...}
{p2col:{cmd:cleanplots} {hline 2}}Graphics scheme that implements best 
data visualization practices. Colors are color-blind friendly and remain 
distinguishable when printed in black and white, with coordinated marker 
symbols and line patterns so that groups stay distinct across multiple 
visual channels. {p_end}
{p2colreset}{...}

{title:Overview}

{pstd}
{cmd:cleanplots} changes the default look and feel of Stata graphics. 
The choices of colors, markers, line patterns, gridlines, legend placement, 
and other aspects of the figure follow best data visualization practices, 
with no per-graph effort needed.

{pstd}
The color palette is designed for accessibility. It contains no red-green 
pair (red-green color blindness is the most common form, affecting roughly 
8% of men), and the first five colors pass simulation checks for all three 
major forms of color blindness. The palette also alternates darker and 
lighter colors so that the first several groups remain distinguishable by 
lightness alone when a figure is printed in black and white.

{pstd}
Color alone reliably distinguishes about 4-5 groups. Beyond that, addiitonal 
markers or patterns are needed for distinguishability. {cmd:cleanplots} 
automatically varies markers, line patterns, and other features.

{pstd}
Bar charts, area plots, and pie charts automatically use softer versions 
of the colors. These elements use far more ink than points and lines, so 
full-strength colors overwhelm; {cmd:cleanplots} fades them for a cleaner 
look while full-strength colors remain on markers, lines, and outlines.

{pstd}
The default {cmd:cleanplots} colors are a nominal palette, meaning no 
ordering is implied by the colors or markers. When an ordered (ordinal) 
palette is needed, use the {cmd:cleanplots#} schemes on a single graph 
(see {help cleanplots##ordinal:Ordinal color schemes} below).

{pstd}
For more information and to see examples, see the 
{browse "https://www.trentonmize.com/software/cleanplots":cleanplots website here}.

{pstd}
Many of the features of cleanplots are adapted from the excellent black and 
white colorscheme plotplain.

{title:Using cleanplots}

{pstd}
To change your graphics scheme to {cmd:cleanplots} for all graphs: 

{phang2} {stata set scheme cleanplots, perm: set scheme cleanplots, perm}

{pstd}
Or apply it to a single graph with the {cmd:scheme()} option: 

{phang2} {stata sysuse auto, clear}{p_end}
{phang2} {stata graph twoway scatter price weight, scheme(cleanplots)}{p_end}

{pstd}
Stata's default graphic scheme is {cmd:s2color}. To change back to the 
default: 

{phang2} {stata set scheme s2color, perm: set scheme s2color, perm}

{title:The colors}

{pstd}
The ten main colors, used for markers, lines, and confidence intervals 
(shown as the Stata color definition and the resulting hex code):

{p2colset 8 24 40 2}{...}
{p2col:{bf:#}}{bf:Definition}{space 8}{bf:Hex}{space 8}{bf:RGB}{p_end}
{p2col:1}red*1.2{space 10}#D50000{space 4}213 0 0{p_end}
{p2col:2}eltblue*.9{space 7}#8FC6EB{space 4}143 198 235{p_end}
{p2col:3}black{space 12}#000000{space 4}0 0 0{p_end}
{p2col:4}gs9{space 14}#909090{space 4}144 144 144{p_end}
{p2col:5}purple*1.1{space 7}#740074{space 4}116 0 116{p_end}
{p2col:6}pink*.3{space 10}#FFB3D9{space 4}255 179 217{p_end}
{p2col:7}navy*1.3{space 9}#143755{space 4}20 55 85{p_end}
{p2col:8}gs12{space 13}#C0C0C0{space 4}192 192 192{p_end}
{p2col:9}gs4{space 14}#404040{space 4}64 64 64{p_end}
{p2col:10}lavender*.35{space 5}#D9D7F0{space 4}217 215 240{p_end}
{p2colreset}{...}

{pstd}
Bars, areas, and pies use softer versions of the same colors (e.g., 
eltblue*.7, purple*.9), rendered with 70% intensity. You can verify any 
of the colors interactively at 
{browse "https://davidmathlogic.com/colorblind/#%23D50000-%238FC6EB-%23000000-%23909090-%23740074-%23FFB3D9-%23143755-%23C0C0C0-%23404040-%23D9D7F0":Coloring for Colorblindness}.

{marker ordinal}{...}
{title:Ordinal color schemes}

{pstd}
The default {cmd:cleanplots} colors are nominal, with no implied ordering: 

{phang2} {stata sysuse auto, clear}{p_end}
{phang2} {stata graph bar price, over(rep78) asyvars scheme(cleanplots)}{p_end}

{pstd}
To have the colors reflect ordering, use the {cmd:cleanplots#} schemes on 
a single graph. Five are available -- {cmd:cleanplots3}, 
{cmd:cleanplots5}, {cmd:cleanplots7}, {cmd:cleanplots9}, and 
{cmd:cleanplots11} -- where the number is how many sequential colors the 
scheme provides. Colors run from light yellow to dark navy, so higher 
categories are darker. For example, for a chart with 5 ordered groups: 

{phang2} {stata sysuse auto, clear}{p_end}
{phang2} {stata graph bar price, over(rep78) asyvars scheme(cleanplots5)}{p_end}

{pstd}
The ordinal colors are from the cividis palette (Nunez, Anderton, & Renslow 
2018), a variant of viridis (van der Walt & Smith 2015) optimized so that 
readers with red-green color blindness see essentially the same palette 
as everyone else. Because the colors run monotonically from light to 
dark, the ordering itself also survives black and white printing.

{pstd}
The {cmd:cleanplots#} schemes inherit all layout, sizing, and legend 
settings from the main {cmd:cleanplots} scheme, and each series gets a 
distinct line pattern and marker 
symbol for maximum distinguishability. If a graph has more groups than 
the scheme has colors, the colors recycle (e.g., under {cmd:cleanplots3} 
the 4th group repeats color 1) while the line patterns and marker symbols 
continue to vary, so recycled groups never share both color and 
pattern/symbol.

{title:Updates}

{pstd} {cmd:cleanplots} was overhauled in July 2026 to ensure all 10 colors 
and the choices of lines, markers, etc. are color-blind friendly and work as 
well as possible in black and white. In addiiton, the ordinal {cmd:cleanplots#} 
schemes were added. Finally, the legend was  moved to be at the 
direct right of the graph {p_end}

{pstd} I recommend using the updated scheme. But if you are feeling nostalgic, 
the older version is preserved as {cmd:cleanplots_classic}. {p_end}

{title:cleanplots for R}

{pstd}
A companion {cmd:cleanplots} package for R (ggplot2) shares this scheme's 
colors, marker symbols, line patterns, and layout. See the full 
documentation and details on downloading the R package at
{browse "https://tdmize.github.io/cleanplots/":tdmize.github.io/cleanplots}.

{title:Authorship}

{pstd} {cmd:cleanplots} is written by Trenton D Mize (Departments of Sociology 
& Statistics [by courtesy] & The Methodology Center at Purdue University). 
Questions can be sent to tmize@purdue.edu {p_end}

{title:Citation & References}

{pstd} In general, I do not think the use of a graphics scheme requires citation. 
So for most cases, feel free to use cleanplots without citation. 
But, if you need/want a citation you can cite cleanplots as: {p_end}

{pstd}
Mize, Trenton D. 2017. "cleanplots: Stata graphics scheme for easy and 
effective data visualizations." https://www.trentonmize.com/software/cleanplots
{p_end}

{pstd}
If using the ordinal {cmd:cleanplots#} schemes, please also credit the 
cividis colors: {p_end}

{pstd}
Nunez, Jamie R., Christopher R. Anderton, and Ryan S. Renslow. 2018. 
"Optimizing colormaps with consideration for color vision deficiency to 
enable accurate interpretation of scientific data." PLOS ONE 13(7): e0199239.
{p_end}
