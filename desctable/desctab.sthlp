{smcl}
{* 2018-09-19 Trenton D Mize}{...}
{title:Title}

{p2colset 5 16 16 1}{...}
{p2col:{cmdab:desctab:le} {hline 2}}Tables of Descriptive Statistics - with 
	Unique Treatment of Continuous, Binary, and Nominal Variables {p_end}
{p2colreset}{...}


{title:General syntax}


{p 4 18 2}
{cmdab:desctab:le} {varlist} {ifin} {cmd:,}
{opt filename( )} [options]
{p_end}

{marker overview}
{title:Overview}

{pstd}
{cmd:desctable} produces a descriptive (summary) statistics table. {cmd:desctable} 
treats continuous, binary, and nominal variables differently -- providing 
statistics and labeled output most appropriate for the measurement level 
of the variable.

{pstd}
Factor syntax is required: binary and nominal variables must be entered 
into the variable list with the i. prefix. Variables without any prefix are 
assumed to be continuous.

{pstd}
{cmd:desctable} outputs the descriptive statistics table to Excel; it can 
easily be copied to Word without losing the formatting of the table.

{pstd}
{cmd:desctable} labels the rows of the table with the corresponding variable label. 
Categories of nominal variables are labeled with the value labels of the 
corresponding variable. Thus, the effectiveness of the default table depends on 
the effectivness of the labels in the data (see {help label} for details on 
adding variable and value labels to your data).


{title:Options}

{marker required}
{dlgtab:Required Option}

{p2colset 5 18 19 0}
{synopt:{opt file:name(string)}} is required. This names the Excel sheet that 
is saved with the descriptive statistics table. If the filename includes spaces, 
it must be enclosed in quotations; e.g. filename("file name has spaces")
{p_end}

{marker stats}
{dlgtab:Optional statistics to include in the table}

{p2colset 5 18 19 0}
{synopt:{opt stat:s(string)}} specifies which statistics should be included in 
the table. Each statistic is reported in a separate column of the table. The 
default is {bf:stat(mean sd)} which reports the mean [proportion for binary and 
nominal variables] and the standard deviation of continuous variables. 
Statistics can be requested in any order desired; columns of the table will 
be ordered based on the list specified in {bf:stats( )}. The following 
statistics are available:
{p_end}

{p2colset 10 23 22 12}{...}
{p2col :Stat Name}Description{p_end}
{p2line}
{p2col :{ul:{bf:mean}}}Mean of continuous variables; proportion of binary/nominal variables.{p_end}
{p2col :{ul:{bf:sd}}}Standard deviation (c).{p_end}
{p2col :{ul:{bf:freq}}}Freqency for each category of a nominal variable.{p_end}
{p2col :{ul:{bf:n}}}Number of non-missing observations for a variable.{p_end}
{p2col :{ul:{bf:var}}{bf:iance}}Variance (c).{p_end}
{p2col :{ul:{bf:med}}{bf:ian}}Median (c).{p_end}
{p2col :{ul:{bf:min}}}Minimum (c).{p_end}
{p2col :{ul:{bf:max}}}Maximum (c).{p_end}
{p2col :{ul:{bf:range}}}Range [max - min] (c). {p_end}
{p2col :{ul:{bf:iqr}}}Interquartile range [75th percentile - 25th percentile] (c).{p_end}
{p2col :{ul:{bf:cv}}}Coefficient of variation [sd/mean] (c).{p_end}
{p2col :{ul:{bf:semean}}}Standard error of mean (c).{p_end}
{p2col :{ul:{bf:skew}}{bf:ness}}Skewness (c).{p_end}
{p2col :{ul:{bf:kur}}{bf:tosis}}Kurtosis (c).{p_end}
{p2col :{ul:{bf:p1}}}1st percentile (c).{p_end}
{p2col :{ul:{bf:p5}}}5th percentile (c).{p_end}
{p2col :{ul:{bf:p10}}}10th percentile (c).{p_end}
{p2col :{ul:{bf:p25}}}25th percentile (c).{p_end}
{p2col :{ul:{bf:p50}}}50th percentile [same as {bf:median}] (c).{p_end}
{p2col :{ul:{bf:p75}}}75th percentile (c).{p_end}
{p2col :{ul:{bf:p90}}}90th percentile (c).{p_end}
{p2col :{ul:{bf:p95}}}95th percentile (c).{p_end}
{p2col :{ul:{bf:p99}}}99th percentile (c).{p_end}
{p2col :{ul:{bf:}}} {p_end}
{p2col :{ul:{bf:svymean}}}*Survey weighted estimate of mean; proportion of binary/nominal variables.{p_end}
{p2col :{ul:{bf:svysemean}}}*Survey weighted estimate of standard error of mean (c).{p_end}
{p2col :{ul:{bf:mimean}}}*Multiple imputation estimate of mean; proportion of binary/nominal variables.{p_end}
{p2col :{ul:{bf:misemean}}}*Multiple imputation estimate of standard error of mean (c).{p_end}
{p2col :{ul:{bf:misvymean}}}*Survey weighted multiple imputation estimate of mean; proportion of binary/nominal variables.{p_end}
{p2col :{ul:{bf:misvysemean}}}*Survey weighted multiple imputation estimate of standard error of mean (c).{p_end}

{p2line}

(c) indicates this statistic is only reported for continuous variables.

* {bf:svy} statistics are only available if data has been {help svyset}. 
{bf:mi} statistics are only available if data has been {help mi set}. 
{bf:misvy} statistics are only available if data has been {help mi svyset}.

{marker stats}
{dlgtab:Other options}

{p2colset 5 18 19 0}
{synopt:{opt dec:imals(#)}} changes the number of decimal places reported 
for the statistics. The default is 2. Any integer between 0 - 5 is allowed.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt listwise}} performs listwise deletion across all specified 
variables. That is, observations with missing data on any of the variables 
included in the table are excluded from any of the reported statistics. 
The default is casewise deletion which includes observations that are 
non-missing for each specific statistic. 
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt note:s(string)}} adds footnotes to the bottom of the table. 
The notes are automatically wrapped so they do not exceed the width of the 
table. For long lists of notes, you will need to adjust the height of the cell 
in Excel after the table is made for all of the notes to be visible. Notes 
must be enclosed in quotation marks, e.g. notes("This is a footnote"). 
For long lists of notes you can list the notes on multiple lines in the code, 
as long as each line is enclosed in quotations, 
e.g. notes("This is the first footnote" "This is the second footnote"). 
The appearance of the notes will be unaffected.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt title(string)}} adds a title to the table. The default is to 
title the table "Table #: Descriptive Statistics (N = ##)" where the N size is 
calculated automatically based on the total number of observations that 
descriptive statistics were calculated for.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt font(string)}} changes the font of all numbers, labels, notes, 
and titles in the table. The default is "Times New Roman"
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt fonts:ize(#)}} changes the font size of all numbers, labels, 
and titles in the table. The default is 11.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt notesize(#)}} changes the font size of the footnotes on 
the table. The default is 9.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt txtindent(#)}} changes how far the statistics are indented from 
the right edge of the column. All statistics are right-justified so that the 
statistics align on the decimal point. The default is 1.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt sing:leborder}} changes to a single horizontal line as the border 
on the top and bottom of the table. The default is to use double horizontal 
lines as the table top and bottom borders.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt sheet:name(string)}} adds a name to the individual Excel sheet 
where the table is saved. The default is to name the sheet "Descriptives Table"
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt varname:s}} labels the rows of the table with the variable names 
rather than the variable labels. The default is to use the variable's label 
if it exists.
{p_end}

{marker stats}
{dlgtab:Group options}

{p2colset 5 18 19 0}
{synopt:{opt group(groupvar)}} specifies that descriptive statistics should be 
calculated separately for each group of the nominal grouping variable. 
Statistics for each group are added to the right of the tables. Labels for the 
new columns are automatically generated from the value labels of the grouping 
variable.
{p_end}


{title:Examples}

{phang} {stata sysuse nlsw88: sysuse nlsw88}

{phang} desctable wage age i.race i.union i.collgrad tenure i.occupation hours, 
filename("descriptivesEX1")

{phang} desctable wage age i.race i.union i.collgrad tenure i.occupation hours, 
filename("descriptivesEX2") stats(mean freq sd min max iqr median)

{phang} desctable wage age i.race i.union i.collgrad tenure i.occupation hours, 
filename("descriptivesEX3") font("Helvetica") fontsize(13)

{phang} desctable wage age i.race i.union i.collgrad tenure i.occupation hours, 
filename("descriptivesEX4") decimals(3)

{phang} desctable wage age i.union i.collgrad tenure i.occupation hours, 
filename("descriptivesEX5") group(race)
			
{phang} desctable wage age i.race i.union i.collgrad tenure i.occupation hours, /// {p_end}
{phang2}	filename("descriptivesEX6") /// {p_end}
{phang2}	notes("This is the first footnote." /// {p_end}
{phang3}			"This is how to split long footnotes" /// {p_end}
{phang3}			"onto multiple lines of the code.") {p_end}

			
{title:Comments}

{pstd} {cmd:desctable} makes the descriptive statistics table using Stata's 
{bf:putexcel} command. Because of some of the putexcel features used, 
Stata version 14.1 or newer is required to use {cmd:desctable}.

{pstd} Available statistics for continuous variables are those that can be 
calculated with tabstat (with the exception of {bf:q} - which is not allowed 
with {cmd:desctable}). See {help tabstat} for more details.


{title:Authorship}

{pstd} {cmd:desctable} is written by Trenton D Mize (Department of Sociology, 
Purdue University) and Bianca Manago (Department of Sociology, Vanderbilt University). 
Questions can be sent to tmize@purdue.edu {p_end}

