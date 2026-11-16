# TA-like motoneuron fitting

Independent calibration workflow for the **TA-like motoneuron** in the BIOE 472 project. This folder documents how candidate parameters are tested against experimental electrophysiological targets. It **does not modify** the fixed TA-like model in the parent folder.

## Run

Open the `fitting_TA` folder as MATLAB's **Current Folder**, then run:

```matlab
main_fitting
```

`main_fitting.m` is a **script**, not a function requiring inputs. It calls two small local functions at the end of the file: `fitting_error` and `passive_response`.

**Requirements:** MATLAB and Signal Processing Toolbox (`findpeaks`). No separate optimization toolbox is needed for `fminsearch`.

## Files

| File | Purpose |
|---|---|
| `main_fitting.m` | Two-start fitting, experimental targets, objective, passive calibration and result export |
| `fit_params.m` | Build a candidate TA-like model from three trial parameters |
| `find_rheobase.m` | Determine the 500 ms current threshold by bracketing and binary search |
| `dyn.m` | Six-state ionic differential equations |
| `run_protocol.m` | Rectangular current steps, `ode15s` integration and `findpeaks` spike detection |

## Parameters and targets

Only **three parameters** are optimized:

| Parameter | Meaning | Search bounds |
|---|---|---|
| `hRate` | Multiplier of NaF inactivation/recovery gating speed | 1–6 |
| `nRate` | Multiplier of Kdr activation/deactivation gating speed | 1–10 |
| `gKCa` | Calcium-activated K⁺ conductance | 0.65–3.5 mS/cm² |

The multipliers act in **both directions** of the relevant gating variable. Bounds and initial guesses (`[2.5, 4, 1.8]` and `[4.5, 7, 2.4]`) are **modeling choices**, not measured physiological ranges.

Experimental targets from the TA-associated group reported by Hadzipasic et al. (2014):

| Quantity | Target | Use in the fitting |
|---|---|---|
| Resting potential | −74.2 mV | Fixed equilibrium target |
| Input resistance | 48 MΩ | Determines effective electrical area |
| Membrane time constant | 4.9 ms | Leak calibration and objective penalty |
| FIF | 340.6 Hz | Used through the FIF/SSF ratio |
| SSF | 74.6 Hz | Objective target |
| FIF/SSF | 340.6 / 74.6 ≈ 4.57 | Objective target |

`gL` is iteratively adjusted to match the passive time constant; the effective area is then calculated to match input resistance. **Neither is an additional independent optimization parameter.**

## Fitting workflow

1. `fminsearch` (Nelder–Mead) starts from each of two initial parameter sets. Candidates outside the specified ranges receive a large penalty. There is **no `encode`/`decode` transformation**.
2. Each valid candidate is built using `fit_params.m`, and `gL` is adjusted through repeated responses to a −0.05 µA/cm², 300 ms hyperpolarizing step. An effective electrical area is derived from the 48 MΩ target.
3. `find_rheobase.m` estimates the lowest 500 ms injected-current pulse that produces at least one spike.
4. Firing is simulated using 1500 ms of zero current, a 500 ms pulse at **3 × that candidate's own rheobase**, and 1800 ms of zero current.
5. `findpeaks` detects voltage maxima above 0 mV. FIF and SSF are calculated from the first and last interspike intervals. Candidates with fewer than eight pulse spikes, pre/post firing, or simulation failures are rejected.
6. The valid candidate with the lowest objective value is reported and saved.

All these simulations use the **same `ode15s` settings**. The previous `fast`/`accurate` modes and manual 0 mV crossing interpolation have been removed.

## Objective function

The objective combines squared logarithmic relative errors in **FIF/SSF** and **SSF**, a kinetic/conductance regularization penalty, and a penalty for deviation from the **4.9 ms** membrane time constant:

```text
J = [2 ln((FIF/SSF)/(340.6/74.6))]^2
  + [1.2 ln(SSF/74.6)]^2
  + 0.035 [(ln hRate)^2 + (ln nRate)^2 + (ln(gKCa/1.185))^2]
  + 10 [ln(tau/4.9)]^2
```

The weights and the `gKCa = 1.185 mS/cm²` regularization reference are **project choices**, not experimental estimates. The objective intentionally balances firing targets against parameter deviations; it need not achieve an exact experimental match.

## Output and interpretation

The script prints the selected candidate's parameters, passive properties, rheobase, FIF, SSF, ratio, spike counts, objective value and optimizer exit status. It saves:

```text
results/TA_matlab_fitting.mat
```

The `.mat` file includes the selected parameters (`bestTheta`), best error, fitted model structure, firing metrics, candidate summaries and exit flags.

**Important limitations:** `fminsearch` is a local optimizer with finite evaluation limits. A run may terminate without confirmed convergence, find a local minimum, or yield parameters different from those frozen in the parent model. The newer one-protocol/`findpeaks` implementation is not numerically identical to the earlier fitting procedure. **Do not claim that running this revised script reproduces the frozen parameters unless verified in MATLAB.**

For reference, the fixed parent TA-like configuration uses:

```text
hRate = 4.639222220533549
nRate = 6.557542497801196
gKCa  = 2.3736263832684124 mS/cm²
```

These values are **phenomenological fitted parameters**, not direct measurements of TA motoneuron channel kinetics or conductances.

## References

- Molkov et al. (2025), *Ionic mechanisms underlying bistability in spinal motoneurons: insights from a computational model*. https://doi.org/10.3389/fncel.2025.1710893
- Original code: https://github.com/jeterlab/ionic-mechanisms-underlying-bistability-in-spinal-motoneurons
- Hadzipasic et al. (2014), experimental electrophysiological targets for the TA-associated motoneuron group.
