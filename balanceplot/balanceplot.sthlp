{smcl}
{* balanceplot v2.0.0}{...}
{title:Title}

{p2colset 5 18 18 1}{...}
{p2col:{cmd:balanceplot} {hline 2}}Plot covariate imbalance for categorical 
or continuous treatments{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 17 2}
{cmd:balanceplot} {it:varlist} {ifin}{cmd:,} {opt group(varname)}
[{opt outcome(varname)} {opt base(#)} {opt level(#)} {opt noci}
{opt matchweight(varname)} {opt cohensh} {opt fade:ns} {opt sort} {opt abs:olute} {opt threshold(#)} {opt graphop(options)}
{opt leg1(string)} {opt leg2(string)} {opt plotcommand} {opt table} {opt tablefull}
{opt store(stubname[, replace])}
{opt leftmargin(#)} {opt decimals(#)} {opt width(#)} {opt labwidth(#)}]

{p 8 17 2}
{cmd:balanceplot} {it:varlist} {ifin}{cmd:,} {opt contreat(varname)}
[{opt outcome(varname)} {opt level(#)} {opt noci} {opt fade:ns} {opt sort}
{opt abs:olute} {opt threshold(#)} {opt graphop(options)} {opt plotcommand} {opt table} {opt tablefull}
{opt store(stubname[, replace])}
{opt leftmargin(#)} {opt decimals(#)} {opt width(#)} {opt labwidth(#)}]

{p 8 17 2}
{cmd:balanceplot} [{it:varlist}]{cmd:,} {opt tebalance}
[{opt sort} {opt abs:olute} {opt threshold(#)} {opt graphop(options)}
{opt plotcommand} {opt leftmargin(#)}]

{title:Description}

{pstd}
Balanceplot calculates standardized covariate imbalance statistics and makes 
a plot using the user-written command {cmd:coefplot}. 

{pstd}
Specify {opt group()}, {opt contreat()}, or {opt tebalance}. 
With {opt group()}, standardized imbalance
is calculated across all observed categories of a categorical grouping variable.
With {opt contreat()}, correlations are calculated between a continuous treatment
and each covariate row. After a supported {cmd:teffects} or {cmd:stteffects}
model, {opt tebalance} compares the raw and matched or weighted standardized
differences returned by {cmd:tebalance summarize}.

{pstd}
All variables in {it:varlist} are included in the balance analysis. 

{pstd}
Factor syntax is required in {it:varlist}. Bare variables and variables
specified with {cmd:c.} are treated as continuous. Variables specified
with {cmd:i.} or {cmd:ib#.} are treated as binary/nominal.

{pstd}
A binary categorical covariate contributes only its nonreference category.
A nominal categorical covariate contributes every category. With {opt group()},
the nominal reference category is a zero-valued placeholder row labeled
{cmd:(ref)}. With {opt contreat()}, every nominal category, including the
reference category, receives an estimated correlation. Nominal covariates are
displayed under a heading; continuous and binary covariates are not. Use
factor-variable base syntax, such as {cmd:ib2.race}, to change the displayed
covariate reference category.

{pstd}
With {opt group()}, every nonreference row is reported as a standardized mean
difference: {cmd:(mean_group - mean_base) / sqrt((sd_group^2 + sd_base^2)/2)}. 
The option {opt cohensh} can be specified, which changes the statistics for 
binary and nominal variables specified with {cmd:i.} or 
{cmd:ib#.} to be Cohen's h:
{cmd:2*asin(sqrt(p_group)) - 2*asin(sqrt(p_base))}. 
Continuous variables are always reported on the standardized-mean-difference scale.

{pstd}
With {opt contreat()}, Pearson and/or polyserial correlations are calculated 
using the user-written command {cmd:polychoric}. 
Continuous covariates receive Pearson correlations; binary indicators receive
polyserial correlations. Nominal covariates are converted to category indicators
and receive one polyserial correlation per category.

{pstd}
Confidence intervals are plotted by default. Non-significant imbalance can be 
visually emphasized on the graph with {opt fade:ns}.

{pstd}
Balance plots are often used to examine balance before and after matching to 
estimate treatment effects. {opt tebalance} can be used after most 
{cmd:teffects} and {cmd:steffects} commands to compare the pre- and 
post-matched samples. Supported commands are {cmd:teffects}' aipw, ipw, 
ipwra, nnmatch, and psmatch estimators and {cmd:stteffects}' ipw and ipwra 
estimators.

{pstd}
{opt matchweight()} plots the unweighted and weighted results together after 
commands such as {cmd:psmatch2}. See examples below.

{title:Required Options}

{phang}
{opt group(varname)} specifies the categorical grouping variable. Imbalance
statistics are calculated across all categories of this variable. {opt group()}
and {opt contreat()} may not be combined.

{phang}
{opt contreat(varname)} specifies a continuous treatment variable. The graph
reports its correlation with each covariate. {opt contreat()} may not be
combined with {opt group()}, {opt base()}, {opt cohensh}, or {opt matchweight()}.

{phang}
{opt tebalance} is a postestimation mode for supported {cmd:teffects} and
{cmd:stteffects} estimators. It quietly calls {cmd:tebalance summarize} and plots
the first two columns of its {cmd:r(table)} matrix as unweighted and matched or
weighted standardized differences. An optional {it:varlist} restricts the plot
to selected treatment-model covariates. With a multivalued treatment, each
nonbase treatment comparison is displayed as a separate covariate block under
its treatment-category heading. Confidence intervals and {opt fade:ns} are
unavailable because {cmd:tebalance summarize} does not return standard errors
for these statistics. {opt sort}, {opt absolute}, {opt threshold()},
{opt graphop()}, and {opt plotcommand} are supported.

{title:Optional Options}

{phang}
{opt base(#)} selects the base/reference category of {opt group()} and may not
be used with {opt contreat()}. Each nonbase
group is compared with the group base. For a binary grouping variable, the 
lowest category is the default. For three or more categories, the largest 
complete-case category is the default.

{phang}
{opt cohensh} reports Cohen's h statistics for binary and nominal variables
when {opt group()} is specified. Imbalance statistics for continuous variables
are unchanged. {opt cohensH} is a synonym. 

{phang}
{opt outcome(varname)} allows a hypothetical outcome variable which will be 
used in listwise deletion to determine the sample for {cmd: balanceplot}, but 
is not shown in the plot. Useful when you want {cmd:balanceplot}'s sample to match 
a subsequent model with all of {it:varlist} and an {opt outcome()}.

{phang}
{opt matchweight(varname)} compares unweighted and weighted balance in the same
graph. Matching weights are applied to the base category of {opt group()} only;
all nonbase categories receive weight 1. Each group comparison retains one color,
while marker symbols distinguish unweighted and weighted estimates. Missing or
zero base-group weights are retained in the unweighted results and excluded from
the weighted results. It may not be combined with {opt contreat()}. This matches
ATT-style output from {cmd:psmatch2}, where controls are ordinarily coded 0 and
treated observations are coded 1. If the control category is not the command's
default base, specify it with {opt base()}.

{phang}
{opt level(#)} sets the confidence interval level. The default is 95.

{phang}
{opt noci} suppresses confidence intervals in the graph. Confidence intervals 
remain in the returned matrices and {opt table} (if requested).

{phang}
{opt fade:ns} fades nonsignificant point estimates and confidence intervals on
the graph. With {opt matchweight()}, unweighted and weighted estimates are faded
according to their own p-values.

{phang}
{opt sort} By default, {cmd:balanceplot} retains covariates in the order 
specified in {it:varlist} and keeps all categories of a nominal variable 
together under a heading. {opt sort} sorts variables from negative to positive
imbalance. With {opt absolute}, it sorts from the smallest to largest absolute
imbalance. With {opt matchweight()}, sorting is based on the weighted estimates.
Variable headings are omitted when {opt sort} is specified because
categories from the same nominal variable may no longer remain together.

{phang}
{opt abs:olute} plots the absolute magnitude of each imbalance statistic.
Returned matrices and printed tables retain the signed statistics. Confidence
intervals are reflected onto the absolute scale for the graph; an interval that
crosses zero begins at zero. {opt abs} is the shortest allowed abbreviation.

{phang}
{opt threshold(#)} adds dashed light-gray reference lines at {cmd:-#} and
{cmd:#}. With {opt absolute}, only the positive threshold line is shown. The
threshold must be greater than zero. With {opt contreat()}, it must also be no
greater than one. The zero reference line remains unchanged.

{phang}
{opt store(stubname[, replace])} posts results as separate estimation results for use
with {cmd:esttab}, {cmd:estout}, or official {cmd:estimates} commands. For an
unweighted two-category {opt group()} analysis, the generated names are
{it:stubname}{cmd:_mean_g#} for each group and
{it:stubname}{cmd:_imbalance}. With three or more categories, each nonbase
comparison is stored as {it:stubname}{cmd:_imb_g#}. Mean results contain
{cmd:e(b)} only. Imbalance results contain {cmd:e(b)} and a diagonal {cmd:e(V)},
so significance information is calculated from the stored estimate and standard
error.

{phang2}
With {opt matchweight()}, {opt store()} posts complete unweighted and weighted
sets. The prefixes are {it:stubname}{cmd:_unw_} and
{it:stubname}{cmd:_w_}. For example, a binary analysis with {cmd:store(bp)}
creates {cmd:bp_unw_mean_g0}, {cmd:bp_unw_mean_g1},
{cmd:bp_unw_imbalance}, {cmd:bp_w_mean_g0}, {cmd:bp_w_mean_g1}, and
{cmd:bp_w_imbalance}. With {opt contreat()}, the correlation result is stored as
{it:stubname}{cmd:_correlation}, with correlations in {cmd:e(b)} and squared
{cmd:polychoric} standard errors on the diagonal of {cmd:e(V)}.

{phang2}
The {cmd:replace} suboption replaces estimation results whose generated names
already exist. Without {cmd:replace}, {cmd:balanceplot} reports an error before
posting any results. For example, specify {cmd:store(bp, replace)} to replace
results previously created from {cmd:store(bp)}.

{phang}
{opt graphop(options)} passes graph options to {cmd:coefplot}.

{phang}
{opt table} displays one compact table for each group comparison. Its columns
are the two group-specific means, Standardized Imbalance, and p-value. With
{opt matchweight()}, an unweighted table is followed by a weighted table for each
comparison. With {opt contreat()}, it displays the correlation and p-value.
{opt width()} and {opt labwidth()} customize the table size.

{phang}
{opt tablefull} displays the same table but with more details: the two
group-specific means, Standardized Imbalance, standard error, lower confidence
limit, upper confidence limit, and p-value. With {opt matchweight()}, an
unweighted table is followed by a weighted table for each comparison. With
{opt contreat()}, it displays the correlation, standard error, confidence limits,
and p-value. {opt table} and {opt tablefull} may not be combined.

{phang}
{opt decimals(#)} sets the number of digits after the decimal in printed tables.
The default is 3.

{phang}
{opt width(#)} sets the display width of every statistic column in printed tables.
The default is 10.

{phang}
{opt labwidth(#)} sets the display width of the leftmost column containing variable
and category labels. The default is 24. Labels longer than this width are
abbreviated.

{title:Stored results}

{pstd}
{cmd:balanceplot} stores the first nonbase comparison in {cmd:r(bias1)}, the second
in {cmd:r(bias2)}, and subsequent comparisons in {cmd:r(bias3)}, and so on.
Export-ready compact matrices are stored in {cmd:r(table1)}, {cmd:r(table2)}, and
so on. 

{pstd}
With {opt store(stubname)}, group means and imbalance statistics are also posted
as estimation results. For example, {cmd:store(bp)} with an unweighted binary
grouping variable creates {cmd:bp_mean_g0}, {cmd:bp_mean_g1}, and
{cmd:bp_imbalance}. 

{pstd}
With {opt contreat()}, results are returned in {cmd:r(correlation)}.

{pstd}
With {opt tebalance}, {cmd:r(table)} and {cmd:r(size)} reproduce the matrices
returned by {cmd:tebalance summarize}, while {cmd:r(balance)} contains its two
standardized-difference columns.

{title:Examples}

{phang}{stata "sysuse nlsw88, clear":. sysuse nlsw88, clear}

{phang}{stata "balanceplot wage age i.married i.race tenure, group(union)":. balanceplot wage age i.married i.race tenure, group(union)}

{phang}{stata "balanceplot wage age i.married i.race tenure, group(union) cohensh":. balanceplot wage age i.married i.race tenure, group(union) cohensh}

{phang}{stata "balanceplot wage age i.married i.race tenure, group(union) fadens":. balanceplot wage age i.married i.race tenure, group(union) fadens}

{phang}{stata "balanceplot wage age i.married i.race tenure, group(union) cohensH noci":. balanceplot wage age i.married i.race tenure, group(union) cohensH noci}

{phang}{stata "balanceplot wage age i.married i.race tenure, group(union) sort":. balanceplot wage age i.married i.race tenure, group(union) sort}

{phang}{stata "balanceplot wage age i.married i.race tenure, group(union) absolute sort threshold(.1)":. balanceplot wage age i.married i.race tenure, group(union) absolute sort threshold(.1)}

{phang}{stata "balanceplot wage age i.married i.race tenure, group(union) threshold(.1)":. balanceplot wage age i.married i.race tenure, group(union) threshold(.1)}

{phang}{stata "balanceplot wage age i.married i.race tenure, group(union) table":. balanceplot wage age i.married i.race tenure, group(union) table}

{phang}{stata "balanceplot wage age i.married i.race tenure, group(union) tablefull":. balanceplot wage age i.married i.race tenure, group(union) tablefull}

{phang}{stata "balanceplot wage age i.married i.race tenure, group(union) table labwidth(30) width(11)":. balanceplot wage age i.married i.race tenure, group(union) table labwidth(30) width(11)}

{pstd}
More than two groups:

{phang}{stata "balanceplot wage age i.married tenure, group(race)":. balanceplot wage age i.married tenure, group(race)}

{pstd}
Store results for {cmd:esttab}:

{phang}{stata "balanceplot wage age i.married i.race tenure, group(union) store(bp)":. balanceplot wage age i.married i.race tenure, group(union) store(bp)}

{phang}{stata "esttab bp_mean_g0 bp_mean_g1 bp_imbalance, se label mtitles":. esttab bp_mean_g0 bp_mean_g1 bp_imbalance, se label mtitles}

{phang}{stata "balanceplot wage age i.married tenure, group(race) store(br)":. balanceplot wage age i.married tenure, group(race) store(br)}

{phang}{stata "esttab br_mean_g1 br_mean_g2 br_mean_g3 br_imb_g2 br_imb_g3, se label mtitles":. esttab br_mean_g1 br_mean_g2 br_mean_g3 br_imb_g2 br_imb_g3, se label mtitles}

{pstd}
Continuous treatment:

{phang}{stata "balanceplot age i.union i.race tenure, contreat(wage)":. balanceplot age i.union i.race tenure, contreat(wage)}

{phang}{stata "balanceplot age i.union i.race tenure, contreat(wage) threshold(.1)":. balanceplot age i.union i.race tenure, contreat(wage) threshold(.1)}

{phang}{stata "balanceplot age i.union i.race tenure, contreat(wage) abs sort threshold(.1)":. balanceplot age i.union i.race tenure, contreat(wage) abs sort threshold(.1)}

{phang}{stata "balanceplot age i.union i.race tenure, contreat(wage) fadens sort tablefull":. balanceplot age i.union i.race tenure, contreat(wage) fadens sort tablefull}

{phang}{stata "balanceplot age i.union i.race tenure, contreat(wage) store(ct)":. balanceplot age i.union i.race tenure, contreat(wage) store(ct)}

{phang}{stata "esttab ct_correlation, se label mtitles":. esttab ct_correlation, se label mtitles}

{title:Matching-weight examples}

{pstd}
After ATT matching with {cmd:psmatch2}, {cmd:_weight} equals 1 for treated
observations and records how often or how strongly each matched control contributes.
Unmatched controls have missing weights. {opt matchweight()} displays both the
original complete-case balance and the weighted matched balance. With a
conventional 0/1 treatment variable:

{phang}{stata "sysuse nlsw88, clear":. sysuse nlsw88, clear}

{phang}{stata "psmatch2 union age tenure grade, neighbor(1) logit":. psmatch2 union age tenure grade, neighbor(1) logit}

{phang}{stata "balanceplot age tenure grade, group(union) matchweight(_weight)":. balanceplot age tenure grade, group(union) matchweight(_weight)}

{phang}{stata "balanceplot age tenure grade, group(union) matchweight(_weight) store(bm)":. balanceplot age tenure grade, group(union) matchweight(_weight) store(bm)}

{phang}{stata "esttab bm_unw_mean_g0 bm_unw_mean_g1 bm_unw_imbalance, se label mtitles":. esttab bm_unw_mean_g0 bm_unw_mean_g1 bm_unw_imbalance, se label mtitles}

{phang}{stata "esttab bm_w_mean_g0 bm_w_mean_g1 bm_w_imbalance, se label mtitles":. esttab bm_w_mean_g0 bm_w_mean_g1 bm_w_imbalance, se label mtitles}

{pstd}
Official {cmd:teffects} and {cmd:stteffects} estimators provide raw and matched
or weighted standardized differences through {cmd:tebalance summarize}.
{cmd:balanceplot, tebalance} calls that command internally and plots the results:

{phang}{stata "sysuse nlsw88, clear":. sysuse nlsw88, clear}

{phang}{stata "teffects psmatch (wage) (union age tenure grade), atet":. teffects psmatch (wage) (union age tenure grade), atet}

{phang}{stata "balanceplot, tebalance":. balanceplot, tebalance}

{phang}{stata "balanceplot age tenure, tebalance absolute sort threshold(.1)":. balanceplot age tenure, tebalance absolute sort threshold(.1)}

{title:Authorship}

{pstd} {cmd:balanceplot} is written by Trenton D Mize, 
Departments of Sociology & Statistics (by courtesy) and The Methodology 
Center, Purdue University. 
Questions can be sent to tmize@purdue.edu {p_end}