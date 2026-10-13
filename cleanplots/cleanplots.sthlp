{smcl}
{* 2026-10-12 Trenton D Mize}{...}
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
Color alone reliably distinguishes about 4-5 groups. Beyond that, additional 
markers or patterns are needed for distinguishability. {cmd:cleanplots} 
automatically varies markers, line patterns, and other features.

{pstd}
Bar charts, area plots, and pie charts automatically use softer versions 
of the colors. These elements use far more ink than points and lines, so 
full-strength colors overwhelm; {cmd:cleanplots} fades them for a cleaner 
look while full-strength colors remain on markers, lines, and outlines.

{pstd}
The default {cmd:cleanplots} colors are a nominal palette,
meaning no ordering is implied by the colors or markers.
For ordered categories, sequential cividis and viridis
palettes are available with 2 through 15 colors, each
with light-to-dark and dark-to-light versions
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
For ordered categories, the sequential ordinal
schemes provide four choices for every number of colors
from 2 through 15:

{p2colset 8 30 32 2}{...}
{p2col:{cmd:cleanplots#}} Cividis, light to dark (default){p_end}
{p2col:{cmd:cleanplots#r}} Cividis, {ul:r}eversed dark to light{p_end}
{p2col:{cmd:cleanplots#v}} Viridis, light to dark{p_end}
{p2col:{cmd:cleanplots#vr}} Viridis, {ul:r}eversed dark to light{p_end}
{p2colreset}{...}

{pstd}
Replace {cmd:#} with the number of ordered groups,
from 2 through 15. For example, with five ordered categories:

{phang2} {stata sysuse auto, clear}{p_end}
{phang2} {stata graph bar price, over(rep78) asyvars scheme(cleanplots5)}{p_end}
{phang2} {stata graph bar price, over(rep78) asyvars scheme(cleanplots5r)}{p_end}
{phang2} {stata graph bar price, over(rep78) asyvars scheme(cleanplots5v)}{p_end}
{phang2} {stata graph bar price, over(rep78) asyvars scheme(cleanplots5vr)}{p_end}

{pstd}
The default ordinal colors are from the cividis palette (Nunez, Anderton, & Renslow 
2018), a variant of viridis (van der Walt & Smith 2015) optimized so that 
readers with red-green color blindness see essentially the same palette 
as everyone else. Because both palettes vary monotonically in lightness,
the ordering itself also survives black and white printing.

{pstd}
Cividis runs between light yellow and dark navy and is
recommended for maximum color-vision accessibility.
Viridis runs between light yellow and dark purple,
passing through green and blue; it uses more distinct hues.
Both palettes are designed to be perceptually uniform
and colorblind friendly.

{pstd}
The {cmd:r} suffix reverses only the sequence of colors;
all other layout, legend, marker, and line-pattern settings
remain unchanged. Stata does not have a general graph
option to reverse a scheme's colors.

{pstd}
The palettes are based on the R {cmd:viridisLite} palettes,
sampled with {cmd:end = .95}. The default schemes run
light to dark ({cmd:direction = -1}), while the reversed
schemes run dark to light ({cmd:direction = 1}).
The five originally released cividis schemes (3, 5, 7,
9, 11) retain their original RGB values.

{pstd}
The {cmd:cleanplots#} schemes inherit all layout, sizing, and legend 
settings from the main {cmd:cleanplots} scheme, and each series gets a 
distinct line pattern and marker 
symbol for maximum distinguishability. If a graph has more groups than 
the scheme has colors, the colors recycle (e.g., under {cmd:cleanplots3} 
the 4th group repeats color 1) while the line patterns and marker symbols 
continue to vary, so recycled groups never share both color and 
pattern/symbol.

{pstd}
With many ordered categories, adjacent colors become
increasingly difficult to distinguish. Labels or additional
visual cues are recommended for such graphs.

{pstd}
The colors of every {cmd:cleanplots} scheme are also available by name in
Ben Jann's {cmd:colorpalette} command (from the {cmd:palettes} package on SSC),
for example {cmd:colorpalette cleanplots5v}.

{title:Updates}

{pstd} {cmd:cleanplots} was overhauled in July 2026 to ensure all 10 colors 
and the choices of lines, markers, etc. are color-blind friendly and work as 
well as possible in black and white. In addition, the ordinal {cmd:cleanplots#} 
schemes were added. Finally, the legend was  moved to be at the 
direct right of the graph {p_end}

{pstd} I recommend using the updated scheme. But if you are feeling nostalgic, 
the older version is preserved as {cmd:cleanplots_classic}. {p_end}

{pstd}
In October 2026, the ordinal schemes were expanded to
include every number of colors from 2 through 15.
Viridis palettes and reverse-order versions of both
cividis and viridis were also added. {p_end}

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
If using the ordinal schemes, please also credit the
corresponding color palette: Nunez et al. (2018) for
cividis, or van der Walt and Smith (2015) for viridis. {p_end}

{pstd}
Nunez, Jamie R., Christopher R. Anderton, and Ryan S. Renslow. 2018. 
"Optimizing colormaps with consideration for color vision deficiency to 
enable accurate interpretation of scientific data." PLOS ONE 13(7): e0199239.
{p_end}

{pstd}
van der Walt, Stefan, and Nathaniel Smith. 2015.
"Viridis: A Better Default Colormap for Matplotlib."
https://bids.github.io/colormap/
{p_end}
