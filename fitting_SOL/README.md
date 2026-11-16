# SOL-like motoneuron fitting

Independent numerical fitting workflow for the **SOL-like motoneuron** in BIOE 472. It follows the same model, three optimized parameters, stimulus, numerical solver, spike detection, and objective-function structure as the TA-like fitting. This is **Option A**, an exploratory comparison: a successful fit is not guaranteed.

## Run

Set MATLAB's **Current Folder** to `fitting_SOL`, then execute:

```matlab
main_fitting
```

**Requirements:** MATLAB and Signal Processing Toolbox for `findpeaks`. `fminsearch` does not require Optimization Toolbox. Each objective evaluation runs multiple ODE simulations, so the fit may be computationally expensive. Do not run `main_fitting` in another fitting folder at the same time unless using separate MATLAB sessions.

## Files

| File | Purpose |
|---|---|
| `main_fitting.m` | Two-start Nelder–Mead optimization, targets, fitting loss, passive calibration, and export |
| `fit_params.m` | Build an SOL-like candidate from the three trial parameters |
| `find_rheobase.m` | Bracket and bisect the minimum 500-ms stimulation current producing a spike |
| `dyn.m` | Six-state ionic ODEs, unchanged from the TA fitting reference |
| `run_protocol.m` | Rectangular current steps, `ode15s`, and `findpeaks`, unchanged from the TA reference |

## Model and assumptions

The model is the six-state reduction of Molkov et al. (2025), without Kv1.2, using the same fixed conductances and calcium equations as the TA workflow. To test the **same three-parameter fitting approach**, the SOL fitting holds `gKdr = 100 mS/cm²`, the original Molkov value, just as in the TA fit. **This differs from the previous manually calibrated SOL model**, which held `gKdr = 60 mS/cm²`. The outcome of this new approach must therefore be evaluated before replacing SOL parameters in the main simulation.

The optimized parameter vector is:

```text
theta = [hRate, nRate, gKCa]
```

| Parameter | Search bounds | Meaning |
|---|---:|---|
| `hRate` | 0.2–6 | NaF inactivation / recovery speed multiplier |
| `nRate` | 0.1–10 | Kdr activation / deactivation speed multiplier |
| `gKCa` | 0.65–3.5 mS/cm² | Calcium-activated potassium conductance |

The TA fit used `hRate = 1–6` and `nRate = 1–10`. Lower values are permitted here because the earlier SOL configuration used **slower** Kdr kinetics (`nRate = 0.30`). The optimized parameters remain the same three quantities. Bounds are practical search choices, **not measured physiological limits**.

Two optimization starting points are used: `[1, 0.30, 0.78]` and `[1, 1, 1.185]`. The first reuses the kinetic and KCa settings of the earlier SOL calibration, **but not its different gKdr**; consequently, it is not guaranteed to reproduce the prior SOL result.

## Experimental targets

Hadzipasic et al. (2014), SOL-associated cluster 1:

| Property | Target | Treatment |
|---|---:|---|
| Resting potential | −70.3 mV | Set as an equilibrium target |
| Membrane time constant | 8.9 ms | Calibrate leak (`gL`) and penalize error |
| Input resistance | 95.4 MΩ | Determine effective electrical area |
| First interspike firing frequency (FIF) | 45.9 Hz | Used through FIF/SSF ratio |
| Last interspike firing frequency (SSF) | 31.9 Hz | Objective target |
| FIF/SSF | 45.9/31.9 ≈ 1.44 | Objective target |

The effective area is a fitting construct, not a direct anatomical area measurement. The resting reversal potential `EL` is derived to enforce zero net membrane current at the target rest voltage.

## Fitting protocol

1. `fminsearch` evaluates two initial guesses and applies a large penalty to candidates outside the chosen bounds.
2. For each candidate, `fit_params.m` constructs an SOL-like neuron and `gL` is adjusted using a **−0.05 µA/cm², 300-ms** hyperpolarizing step to approximately match `tau = 8.9 ms`.
3. The electrical area is calculated to reproduce `Rin = 95.4 MΩ`.
4. `find_rheobase.m` estimates the minimum current eliciting a spike in 500 ms.
5. `run_protocol.m` simulates **1500 ms baseline + 500 ms at 3× its own rheobase + 1800 ms recovery**, using `ode15s` and `findpeaks` (voltage peak above 0 mV).
6. FIF and SSF are computed as 1000 divided by the first and last interspike intervals, respectively. Candidates with fewer than 8 spikes or any pre/post firing are rejected.
7. The valid candidate with the lowest objective value is reported and saved.

## Objective function

The *same form and weights* as in the TA fitting are retained, substituting SOL targets:

```text
J = [2 ln((FIF/SSF)/(45.9/31.9))]^2
  + [1.2 ln(SSF/31.9)]^2
  + 0.035 [(ln hRate)^2 + (ln nRate)^2 + (ln(gKCa/1.185))^2]
  + 10 [ln(tau/8.9)]^2
```

The weights and `gKCa = 1.185 mS/cm²` regularization reference were inherited from the TA procedure for a direct methodological comparison. **They are choices, not experimental SOL-specific estimates.** This is a local optimization with a limited number of evaluations, so it may fail to find a good or unique fit.

## Output

Results are saved to `results/SOL_matlab_fitting.mat`. Output variables include `bestTheta`, `bestLoss`, final parameter structure `p` (including `p.rheobase`), `rh`, passive properties, FIF/SSF, both candidates, and their exit flags. The script **does not automatically update the model in the parent folder**.

After running, compare predicted FIF, SSF, ratio and spike counts with the experimental targets and with the prior SOL simulation. If this approach fits poorly, the alternative is to fit `[gKdr, nRate, gKCa]` while holding `hRate = 1` (Option B), rather than silently changing the present code.

## References

- Molkov et al. (2025). *Ionic mechanisms underlying bistability in spinal motoneurons: insights from a computational model*. DOI: https://doi.org/10.3389/fncel.2025.1710893
- Model source: https://github.com/jeterlab/ionic-mechanisms-underlying-bistability-in-spinal-motoneurons
- Hadzipasic et al. (2014). Experimental data for SOL-associated motoneuron cluster 1.
