{smcl}
{* 2026-07-30 Trenton D Mize}{...}
{title:Title}

{p2colset 5 16 16 1}{...}
{p2col:{cmd:metest} {hline 2}}tests and combines the marginal effects
calculated by {help mecompare}{p_end}
{p2colreset}{...}

{title:Syntax}

{p 4 12 2}
{cmd:metest} [{it:exp}] [{cmd:,} {it:options}]

{pstd}
where {it:exp} refers to the marginal effects either by the {it:ME #} shown in
the {cmd:mecompare} table or by their coefficient names, combined with
{cmd:+}, {cmd:-}, {cmd:*}, {cmd:/}, parentheses, or {cmd:=}.

{title:Description}

{pstd}
{cmd:metest} operates on the marginal effects that {help mecompare} posts to
{cmd:e(b)} and {cmd:e(V)}. An expression {bf:without} {cmd:=} is passed to
{help nlcom}, so any combination is allowed -- sums, differences, ratios,
products, and nonlinear functions such as {cmd:abs()}, {cmd:exp()},
{cmd:ln()} and {cmd:min()}. A name followed by {cmd:(} is read as a function
and handed to {cmd:nlcom} as typed, which is what reports an unknown one. An
expression with {cmd:=} goes to {help test} instead, which tests linear
combinations and cannot evaluate a function. An expression {bf:containing} {cmd:=} is
passed to {help test}, which supports chained equalities
({cmd:metest 1 = 2 = 3}) and multiple constraints
({cmd:metest (1 = 2) (3 = 4)}).

{pstd}
A {bf:bare number} is always read as the {it:ME #} from the last
{cmd:mecompare} table. To use a number as a {bf:literal value}, prefix it with
{bf:#}: {cmd:#2} is the number two, whereas {cmd:2} is the second marginal
effect. So {cmd:metest (1 + 4) / #2} averages MEs 1 and 4, while
{cmd:metest 4 / 5} is the ratio of ME 4 to ME 5. A number that is not a whole
number cannot be an {it:ME #} and is always read as a literal.

{pstd}
Anything that is not a number is read as a coefficient name, with or without
the {cmd:_b[ ]} wrapper. Type {cmd:mecompare, coeflegend} to list the names.

{pstd}
Results accumulate with {opt add}, and {cmd:metest} with {bf:no} expression
redisplays what has accumulated. A loop can therefore build a table quietly
and show it once at the end:{p_end}

{phang2}{cmd:. metest, clear}{p_end}
{phang2}{cmd:. qui metest 1, add rowname(race:White)}{p_end}
{phang2}{cmd:. qui metest 2, add rowname(race:Black)}{p_end}
{phang2}{cmd:. metest, title("Marginal effects by race")}{p_end}

{pstd}
{cmd:metest} is written for {help mecompare} but is not restricted to it. A
number is the {it:n}th non-omitted column of {cmd:e(b)}, which is well defined
after any e-class command, so {cmd:metest} can also be used after
{help margins:margins, post} or after a model fit directly -- see
{help metest##other:Use after other commands}.

{title:Options}

{p2colset 5 22 24 2}
{p2col:{opt stat:istics(list)}}statistics to display: {opt estimate},
{opt se}, {opt zvalue}, {opt pvalue}, {opt ll}, {opt ul}, or {opt all}. The
default is {cmd:estimate se pvalue}. Each may be abbreviated or given by a
synonym -- {cmd:est}, {cmd:coef} or {cmd:b} for {opt estimate}; {cmd:stderr}
for {opt se}; {cmd:z}; {cmd:p}; {cmd:lb}; {cmd:ub} -- and the list is not
case sensitive. Ignored for equality tests, which always report the test
statistic, its degrees of freedom, and the p-value. {cmd:stats()} is a
synonym for the option itself.{p_end}

{p2col:{opt all:stats}}equivalent to {cmd:statistics(all)}.{p_end}

{p2col:{opt add}}adds the result as another row of the saved table rather
than starting a new one. {cmd:save} is a synonym.{p_end}

{p2col:{opt clear}}clears the saved table before running. {cmd:metest, clear}
on its own clears it without running anything. It is an option and must
follow a comma; {cmd:metest clear} is not accepted.{p_end}

{p2col:{opt rown:ame(string)}}labels the row. A {cmd::} in the label puts what
comes before it on a row of its own, with the rest indented underneath, which
is how several rows are grouped under one heading:
{cmd:rowname(race:Black - White)}. By default the row is labeled with the test
that was run -- the expression with coefficient names substituted for the ME
numbers -- and whatever every term has in common becomes that heading: the
variable when they come from one variable ({cmd:married:m1 - m2}), otherwise
the model ({cmd:m1:married - age}). When they share neither, the expression
itself is used, e.g. {cmd:(1-2)-(4-5)}. {opt label()} is a synonym.{p_end}

{p2col:{opt dec:imals(#)}}decimal places; the default is 3.{p_end}

{p2col:{opt wid:th(#)}}width of each statistic column; the default is 9.{p_end}

{p2col:{opt labw:idth(#)}}width of the leftmost (label) column; the maximum is 32. By default it is sized so the table fits an 80-column line -- 32 for the default three statistics, narrowing as more are shown. {opt twidth()} is a synonym.{p_end}

{p2col:{opt title(string)}}title above the table.{p_end}

{p2col:{opt notab:le}}suppresses the table.{p_end}

{p2col:{opt d:etails}}shows the underlying {cmd:nlcom} or {cmd:test}
output.{p_end}

{p2col:{opt l:evel(#)}}confidence level for {opt ll} and {opt ul}.{p_end}

{title:Saved results}

{pstd}
Estimates accumulate in the matrix {cmd:_metest} and equality tests in
{cmd:_metest_test}. The two are displayed as separate tables because they
report different statistics. Each row is named for the quantity it reports --
by default the expression with coefficient names substituted for the ME
numbers, or whatever {opt rowname()} was given. When no usable name can be
formed from the expression, the row falls back to a counter that runs
continuously across both matrices, so no two rows share a name within a
session. Note that {cmd:metest} does not print a row-number column: the
counter is a naming fallback, not a column you will see.
{p_end}

{pstd}
A call without {opt add} starts a fresh table. If the result is an estimate,
{cmd:_metest} is replaced and {cmd:_metest_test} is dropped; if it is an
equality test, the reverse. With {opt add} both matrices persist side by
side. {cmd:metest, clear} drops both. {cmd:metest} with no expression
redisplays them without changing either.

{pstd}
{cmd:metest} is r-class. After an expression it returns {cmd:r(estimate)},
{cmd:r(se)}, {cmd:r(zvalue)}, {cmd:r(pvalue)}, {cmd:r(ll)}, and {cmd:r(ul)};
after an equality test it returns {cmd:r(chi2)} (or {cmd:r(F)}), {cmd:r(df)},
and {cmd:r(pvalue)}. {cmd:r(label)} holds the row label used and
{cmd:r(expression)} the expression.

{title:Examples}

{pstd}Setup -- fit and store two models, then calculate the marginal
effects:{p_end}

{phang2}{stata sysuse nlsw88, clear: sysuse nlsw88, clear}{p_end}
{phang2}{stata drop if missing(union, married, age, race, wage): drop if missing(union, married, age, race, wage)}{p_end}
{phang2}{stata logit union i.married age i.race, vce(robust): logit union i.married age i.race, vce(robust)}{p_end}
{phang2}{stata est store m1: est store m1}{p_end}
{phang2}{stata logit union i.married age i.race wage, vce(robust): logit union i.married age i.race wage, vce(robust)}{p_end}
{phang2}{stata est store m2: est store m2}{p_end}
{phang2}{stata mecompare age i.married, models(m1 m2): mecompare age i.married, models(m1 m2)}{p_end}

{pstd}A single marginal effect, by number and by name:{p_end}
{phang2}{stata metest 1: metest 1}{p_end}
{phang2}{stata "metest age:m1":metest age:m1}{p_end}

{pstd}The cross-model difference, three equivalent ways -- and note that
{cmd:mecompare} already reports it as ME 3:{p_end}
{phang2}{stata metest 1 - 2: metest 1 - 2}{p_end}
{phang2}{stata metest 3: metest 3}{p_end}
{phang2}{stata "metest _b[age:m1] - _b[age:m2]":metest _b[age:m1] - _b[age:m2]}{p_end}

{pstd}A ratio and an average -- these need {cmd:nlcom}, so they are not
available in {cmd:lincom} or {cmd:mlincom}. Note the {bf:#} on the divisor of
the average, which makes it the number two rather than ME 2:{p_end}
{phang2}{stata metest 1 / 2: metest 1 / 2}{p_end}
{phang2}{stata metest (1 + 2) / #2: metest (1 + 2) / #2}{p_end}

{pstd}Scaling by a literal value -- the effect of a 10-year change in
age:{p_end}
{phang2}{stata metest 1 * #10: metest 1 * #10}{p_end}

{pstd}Equality tests, including a joint test and two constraints at once:{p_end}
{phang2}{stata metest 1 = 2: metest 1 = 2}{p_end}
{phang2}{stata metest 1 = 2 = 3: metest 1 = 2 = 3}{p_end}
{phang2}{stata metest (1 = 2) (4 = 5): metest (1 = 2) (4 = 5)}{p_end}

{pstd}Building up a table. Estimates and equality tests are shown as two
tables, since they report different statistics, but the rows are numbered
continuously across both:{p_end}
{phang2}{stata metest, clear: metest, clear}{p_end}
{phang2}{stata metest 1 - 2: metest 1 - 2}{p_end}
{phang2}{stata metest 4 - 5, add: metest 4 - 5, add}{p_end}
{phang2}{stata metest 1 = 2, add: metest 1 = 2, add}{p_end}

{pstd}And redisplayed at any point, with a title, by typing {cmd:metest} on
its own:{p_end}
{phang2}{stata metest, title("Age and marriage"): metest, title("Age and marriage")}{p_end}

{pstd}All six statistics, and a label of your own:{p_end}
{phang2}{stata metest 1 - 2, stat(all): metest 1 - 2, stat(all)}{p_end}
{phang2}{stata metest 1 - 2, rowname("Age effect, m1 vs m2"): metest 1 - 2, rowname("Age effect, m1 vs m2")}{p_end}

{marker other}
{title:Use after other commands}

{pstd}
Nothing in {cmd:metest} is specific to {cmd:mecompare}. After any e-class
command, a bare number refers to the {it:n}th non-omitted coefficient of
{cmd:e(b)}, in the order {cmd:matrix list e(b)} reports them, and coefficient
names work as usual. Row labels fall back to the coefficient names themselves,
abbreviated to fit.

{pstd}
This makes {cmd:metest} usable wherever {help mlincom} is, with the addition of
multiplication, division, nonlinear functions, and equality tests:{p_end}

{phang2}{stata sysuse nlsw88, clear: sysuse nlsw88, clear}{p_end}
{phang2}{stata regress wage age ttl_exp grade: regress wage age ttl_exp grade}{p_end}
{phang2}{stata metest 1 - 2: metest 1 - 2}{space 8}the 1st minus the 2nd coefficient{p_end}
{phang2}{stata metest 1 / 2: metest 1 / 2}{space 8}their ratio{p_end}
{phang2}{stata metest 1 = 2 = 3: metest 1 = 2 = 3}{space 2}a joint test that the three are equal{p_end}
{phang2}{stata metest abs(1) - abs(2): metest abs(1) - abs(2)}{space 2}which effect is larger in magnitude{p_end}
{phang2}{stata metest min(1,2): metest min(1,2)}{space 8}the smaller of the two{p_end}
{phang2}{stata metest _b[age] * #10: metest _b[age] * #10}{space 1}by name, scaled by ten{p_end}

{pstd}
Two things to keep in mind away from {cmd:mecompare}. Omitted ({cmd:o.})
coefficients are skipped when numbering, so a number may not match the position
in the displayed regression table -- check with {cmd:matrix list e(b)}. And
after some commands {cmd:test} reports {it:F} rather than {it:chi2}; the two
cannot be stacked in one accumulated table, so run {cmd:metest, clear} when
switching between models of the two kinds.

{title:Also see}

{psee}
{help mecompare}, {help nlcom}, {help test}, {help mlincom}

{title:Authorship}

{pstd}
{cmd:metest} is written by Trenton D Mize (Departments of Sociology &
Statistics [by courtesy] and the Methodology Center, Purdue University).
Questions can be sent to tmize@purdue.edu. The ME-number mapping and the
accumulating result table are adapted from Long and Freese's SPost13
{help mlincom}.
{p_end}
