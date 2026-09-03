*! mec_wcheck v1.0.0 Trenton Mize 2026-07-31  | history: CHANGELOG-suest2.md (repo)

*Shared by mecompare, meinequality and totalme: one implementation rather
*	than three copies that can drift apart.

capture program drop mec_wcheck
program define mec_wcheck
*A weight given to the command may RESTATE the stored model's weight but may
*	not contradict it. The principle: the marginal effects reported must be the
*	ones the stored models themselves imply, so the weighting has to come from
*	those models. Repeating it is harmless and simply confirms; supplying a
*	different weight, or supplying one when the model carries none, would give
*	effects the stored model does not imply, so it is refused. svy: models
*	carry their design from the svyset and need no weight at all.
	version 16.0
	syntax , [ GWeight(string) GExp(string) MWType(string) MWExp(string) /*
		*/ PREfix(string) CMD(string) ]
	if "`gweight'" == ""  exit

	if "`prefix'" == "svy" {
		di _newline(1)
		di as err "The model was fit with {opt svy:}, which already carries the "  /*
		*/ "sampling weights from {help svyset}. Do not also specify a weight "    /*
		*/ "on {cmd:`cmd'}."
		exit 198
		}

	if "`mwexp'" == "" {
		di _newline(1)
		di as err "A weight was given to {cmd:`cmd'} but the stored model was "    /*
		*/ "fit without one, so the marginal effects would not be those the "      /*
		*/ "model implies. Refit the model with the weight -- e.g. "               /*
		*/ "{cmd:logit y x [pw=w]} -- and {cmd:`cmd'} will use it."
		exit 198
		}

*	compare ignoring spaces: [pw=w] and [pweight = w] are the same weight
	local a = subinstr("`gexp'", " ", "", .)
	local b = subinstr("`mwexp'", " ", "", .)
	if "`a'" != "`b'" | "`gweight'" != "`mwtype'" {
		di _newline(1)
		di as err "The weight given to {cmd:`cmd'} ([`gweight' `gexp']) differs "  /*
		*/ "from the one the stored model was fit with ([`mwtype' `mwexp']). "     /*
		*/ "The marginal effects reported are those the stored models imply, so "  /*
		*/ "the weight must match. Refit the model, or omit the weight here and "  /*
		*/ "the model's own will be used."
		exit 198
		}
end
