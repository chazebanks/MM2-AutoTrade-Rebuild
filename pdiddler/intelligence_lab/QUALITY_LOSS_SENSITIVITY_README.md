# Offline quality-loss sensitivity — research, not an automatic strategy

**Developer purpose:** supply reproducible counterfactual economics to inform the user-approved **long-term** goal of controlled autonomous listed-value-loss quality upgrades. No risk budget or real losses have been approved.

- Pure Python source: `pdiddler/intelligence_lab/quality_loss_sensitivity.py`.
- Regression: `pdiddler/ci/test_quality_loss_sensitivity.py`.
- Does not load the MM2 client, P3/P4 modules, Supreme site, Discord archive or private inventory; no trade side effects.
- Inputs are **hypothetical, untrusted values**. The standard published Emberbow/Immortal/Snowcannon example is illustrative; values are *not* independently authenticated current quotes.
- Results for the 775→750 hypothetical loss show **25 units = 3.225806...%**. It exceeds all trial caps of 0%, 0.5%, 1%, 2% and 3%. No candidate is endorsed or permitted by this calculation.
- Ten same-direction hypothetical 3% losses compound to ~73.74% of initial listed value. The numbers are a stress test, **not** evidence of likely future trading outcomes.
- A two-exit break-even model can quantify the required *conditional* higher exit probability, but cannot estimate actual acceptance probability without a defensible sample of completed trades.
- One client-observed `COMPLETED` flag or caller-provided `verified=true` is not independently validated. The placeholder learning audit **quarantines everything**, including an asserted completed trade, until a real independent verification boundary is designed and tested.
- Four physical slots are distinguished from stacked quantity; this does **not** magically fix the old PR106 planner's *four total copies* enumeration restriction.
- Always use the existing PR106/PR182/Stage120 source-bound research modules for **portfolio candidate evaluation**; this is **only an economic stress-test adjunct**, not a replacement planner or trader.
- All of: Gingerscope outbound offers, automatic final Accept, market-based profit reporting, unverified Discord-derived learning, and live loss trading remain disabled.

## Next evidence to collect

Independent executed-trade exit observations, negatives (rejected/cancelled/unknown), time-to-retrade, source revisions and market disagreements. Develop a **private** audit-able settlement/attractiveness dataset. Evaluate candidate caps against realistic target purchasing power, no-loss alternatives, and held-out time windows. **Do not set a production number based on this test.**
