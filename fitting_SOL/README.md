# SOL-like motoneuron fitting

Independent numerical calibration of the **SOL-like motoneuron** for the BIOE 472 project. This workflow calibrates a six-state, single-compartment conductance-based model adapted from Molkov et al. (2025) against the SOL-associated **cluster 1** electrophysiological targets from Hadzipasic et al. (2014).

The SOL and TA fitting scripts use the **same three adjustable parameters**, ionic equations, stimulation protocol, and objective-function structure. They are run separately and **are not called by the root `main.m`**.

## How to run

Open `fitting_SOL/` as MATLAB's **Current Folder** and execute:

```matlab
main_fitting
```

The fitter saves `results/SOL_matlab_fitting.mat` in this folder. Running it **does not update** the fixed SOL parameters stored in the parent `model_params.m`; those must be transferred explicitly if a new solution is adopted.

**Software:** MATLAB and Signal Processing Toolbox (`findpeaks`). The optimizer `fminsearch` is included with MATLAB and does not require Optimization Toolbox. Fitting can take time because each objective evaluation runs several ODE simulations.

Do not recursively add both fitting folders to the MATLAB path: they contain functions with identical names (`dyn.m`, `run_protocol.m`, and others).

## Files

| File | Purpose |
|---|---|
| `main_fitting.m` | Two-start `fminsearch` fitting, passive calibration, objective, and MAT export |
| `fit_params.m` | Constructs a SOL-like candidate from the three fitted parameters |
| `find_rheobase.m` | Estimates the 500-ms numerical rheobase by bracketing and binary search |
| `dyn.m` | Six-state ionic ODEs, shared in structure with the TA-like model |
| `run_protocol.m` | Integrates rectangular current steps with `ode15s` and detects spikes |

## Model and fitted parameters

The modeled currents are NaF, NaP, Kdr, CaL, KCa, CAN, and leak; the Kv1.2 term is omitted. The model includes membrane voltage, intracellular calcium, and four gating states. The calcium variable uses an effective 250-ms time constant incorporating calcium-induced calcium release phenomenologically, without an explicit intracellular store.

The vector fitted with `fminsearch` is:

```text
theta = [hRate, nRate, gKCa]
```

| Parameter | Search bounds | Role |
|---|---:|---|
| `hRate` | 0.2–6 | Multiplies NaF inactivation **and recovery** rates |
| `nRate` | 0.1–10 | Multiplies Kdr activation **and deactivation** rates |
| `gKCa` | 0.65–3.5 mS/cm² | Maximal calcium-activated K+ conductance |

The two initial guesses are `[1, 0.30, 0.78]` and `[1, 1, 1.185]`. The fitting holds `gKdr = 100 mS/cm²`, as in the TA-like workflow. This differs from an earlier **manual** SOL calibration that used `gKdr = 60 mS/cm²`; that earlier parameterization is not the final one. The bounds, starting points, and kinetic multipliers are phenomenological modeling choices, not measured physiological ranges.

Both phenotypes share `gNaP = 0.01` and `gCAN = 1.05 mS/cm²` in the final project. These are assumed model conductances, not SOL- or TA-specific experimental measurements. `gCaL = 0.01 mS/cm²` follows the original model repository's code; the paper also reports `0.05 mS/cm²`.

## Experimental targets

Targets for the SOL-associated cluster 1 in Hadzipasic et al. (2014):

| Quantity | Target | How it is used |
|---|---:|---|
| Resting potential | −70.3 mV | Imposed equilibrium by deriving leak reversal potential `EL` |
| Input resistance | 95.4 MΩ | Determines an **effective electrical area** |
| Membrane time constant | 8.9 ms | Guides leak conductance `gL` calibration and objective penalty |
| First interspike firing frequency (FIF) | 45.9 Hz | Entered through the FIF/SSF ratio |
| Last interspike firing frequency (SSF) | 31.9 Hz | Objective target |
| FIF/SSF | 45.9/31.9 ≈ 1.44 | Objective target |

Resting voltage, input resistance, and time constant are fitted or imposed targets, **not independent validation results**. The effective electrical area is a calibration construct, not a measured anatomical area.

## Calibration protocol

1. For a trial `theta`, construct an equilibrium at the experimental resting voltage and adjust `gL` using three corrections based on a **−0.05 µA/cm², 300-ms** hyperpolarizing pulse.
2. Calculate effective area from the target input resistance.
3. Estimate the rheobase for a **500-ms** current step, defined numerically as the smallest tested input eliciting a detected voltage peak above 0 mV.
4. Simulate **1500 ms at zero current, 500 ms at 3 × the candidate's own rheobase, and 1800 ms at zero current**.
5. Detect spikes using `findpeaks` with a 0-mV *peak-detection cutoff*. This is not the physiological excitation threshold. Compute FIF and SSF as `1000/ISI`, using the first and last within-pulse interspike intervals (ISI in ms).
6. Accept candidates with **at least three within-pulse spike peaks and no prestimulus spike peaks**. **Poststimulus spikes are recorded but do not disqualify the candidate.** Three peaks are the mathematical minimum for separate first and last ISIs; this is not a physiological spike-count threshold.
7. Apply the common objective below from two initial guesses. Save the valid result with the lowest loss.

The updated criterion above replaces an earlier, more restrictive rule requiring at least eight spike peaks and no poststimulus firing.

## Objective function

The same functional form and weights are used in the SOL and TA fitting workflows:

```text
J = [2 ln((FIF/SSF)/(45.9/31.9))]^2
  + [1.2 ln(SSF/31.9)]^2
  + 10 [ln(tau/8.9)]^2
  + 0.035 [(ln hRate)^2 + (ln nRate)^2 + (ln(gKCa/1.185))^2]
```

The squared logarithms penalize relative mismatches. The weights and reference `gKCa = 1.185 mS/cm²` are modeling choices. The optimization is local and does not establish uniquely identifiable ionic parameters.

## Current adopted solution

The fixed values currently recorded in the parent `model_params.m` (from the updated fitting without the poststimulus exclusion) are:

| Parameter / result | SOL-like |
|---|---:|
| `hRate` | 0.8831005817202662 |
| `nRate` | 0.3519733081847274 |
| `gKCa` (mS/cm²) | 0.8335601089772888 |
| `gL` (mS/cm²) | 0.10448386558117018 |
| Effective area (cm²) | 9.566538424497626e-05 |
| Numerical rheobase (µA/cm²) | 0.86181640625 |
| FIF (Hz), main simulation | 48.92 |
| SSF (Hz), main simulation | 33.37 |
| Spikes before / during / after | 0 / 19 / 0 |

The adopted model reproduces SOL-like firing rates relatively closely, but this is a numerical fit, not a unique physiological identification. Changes to the fitting settings may yield a different local optimum. Compare any new run with these values before modifying `model_params.m`.

## Output and interpretation

`results/SOL_matlab_fitting.mat` contains the selected parameter vector (`bestTheta`), its objective (`bestLoss`), fitted parameter structure `p` (including `p.rheobase`), rheobase `rh`, passive measurements, FIF and SSF, the two candidate solutions, their losses, and exit flags.

To reproduce the final *main* simulations and the eight-condition NaP/CAN experiment, return to the repository root and run:

```matlab
main
```

The root `main.m` calls `compare_PIC()` automatically. It **does not rerun this fitter**.

## References

- Molkov et al. (2025), *Ionic mechanisms underlying bistability in spinal motoneurons: insights from a computational model*. https://doi.org/10.3389/fncel.2025.1710893
- Original ionic model code: https://github.com/jeterlab/ionic-mechanisms-underlying-bistability-in-spinal-motoneurons
- Hadzipasic et al. (2014), experimental target properties for the SOL-associated cluster 1.
