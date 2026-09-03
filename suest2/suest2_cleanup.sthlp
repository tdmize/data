{smcl}
{* *! version 0.1.75  06aug2026}{...}
{title:Title}

{phang}
{bf:suest2_cleanup} {hline 2} list or remove private resources created by {cmd:suest2}

{title:Syntax}

{p 8 17 2}
{cmd:suest2_cleanup}
[{cmd:,} {opt force}]

{title:Description}

{pstd}
{cmd:suest2_cleanup} lists private stored estimates used by the active-system
prediction dispatcher and any hidden composite pweight variables retained so
that official {cmd:margins} can weight heterogeneous-sample systems. Cleanup
uses explicit ownership metadata; user estimates or variables are never removed
merely because their names begin with {cmd:__s2_} or {cmd:__s2pw}.

{pstd}
Specify {cmd:force} only after active and stored {cmd:suest2} results that depend
on these resources are no longer needed.

{pstd}
Each {cmd:suest2} run leaves its private constituent copies stored (two per
run, more under {cmd:mi}), and Stata caps stored estimation sets at 300, so
sessions with very many runs eventually fail with {it:unable to preserve}
{it:constituent model}. Calling {cmd:suest2_cleanup, force} periodically
reclaims all of it while preserving user-stored estimates. {cmd:mecompare}
does this automatically at the start of each of its own runs.
