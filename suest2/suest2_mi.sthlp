{smcl}
{* *! version 0.1.59  26jul2026}{...}
{vieweralsosee "suest2" "help suest2"}{...}
{title:Title}

{phang}
{bf:suest2_mi} {hline 2} Internal multiple-imputation execution engine for {cmd:suest2}

{title:Description}

{pstd}
When called through the ordinary stored-estimates interface, {cmd:suest2}
preserves the exact imputation set recorded by the source estimates and
separately replays every stored command on the current MI data. Each replay
must reproduce the source pooled coefficients and VCE before the joint system
is constructed. The final joint system must preserve each source coefficient
block; its diagonal sandwich blocks are not equated with standalone VCEs. A
mismatch is rejected with an explanation that the current MI data, weights,
survey settings, offsets/exposures, or analysis variables may have changed.


{pstd}
{cmd:suest2_mi} is the internal engine used when ordinary {cmd:suest2}
receives separately stored {cmd:mi estimate, post:} results.  Users should
normally estimate and store the individual MI models and call {cmd:suest2}
with their stored names.  See {help suest2##multiple_imputation:suest2}.

{pstd}
The engine executes labeled constituent commands within the current
imputation, stores them temporarily, and calls {cmd:suest2}.  Official
{cmd:mi estimate} then pools the complete stacked coefficient vector and
covariance matrix.  The model labels are retained for postestimation through
{cmd:mimrgns}.
