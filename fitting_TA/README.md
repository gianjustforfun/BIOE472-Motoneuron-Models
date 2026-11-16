# TA-like motoneuron fitting

Independent numerical calibration of the **TA-like motoneuron** for BIOE 472. The six-state, single-compartment conductance-based model is adapted from Molkov et al. (2025), and the electrophysiological targets come from the TA-associated **cluster 3** of Hadzipasic et al. (2014).

The TA and SOL fitting workflows optimize **the same three parameters** using the same equations, numerical protocol, and objective-function structure, but different experimental targets and search bounds. They are independent of the root `main.m`.

## How to run

Set MATLAB's **Current Folder** to `fitting_TA/` and execute:

```matlab
main_fitting
```

`main_fitting.m` is a script with local functions `fitting_error` and `passive_response`. It saves `results/TA_matlab_fitting.mat` inside this folder. It **does not modify** `../model_params.m` or run the final PIC experiments.

**Software:** MATLAB and Signal Processing Toolbox (`findpeaks`). `fminsearch` does not require Optimization Toolbox. Each objective evaluation requires multiple ODE simulations.

Do not recursively add both fitting folders to the MATLAB path because they contain functions with identical names.

## Files

| File | Purpose |
|---|---|
| `main_fitting.m` | Two-start `fminsearch` optimization, passive calibration, objective, and MAT export |
| `fit_params.m` | Builds a TA-like candidate from the trial parameters |
| `find_rheobase.m` | Estimates the 500-ms numerical rheobase by bracketing and binary search |
| `dyn.m` | Six-state ionic differential equations |
| `run_protocol.m` | Consecutive rectangular current steps, `ode15s`, and spike detection |

## Model and parameters

The model contains NaF, NaP, Kdr, CaL, KCa, CAN, and leak currents, with Kv1.2 omitted. The six state variables represent voltage, intracellular calcium, CaL activation/inactivation, NaF inactivation, and Kdr activation. The calcium equation has a 250-ms effective time scale that represents CICR phenomenologically rather than explicitly modeling calcium stores.

The optimized vector is:

```text
theta = [hRate, nRate, gKCa]
```

| Parameter | Search bounds | Meaning |
|---|---:|---|
| `hRate` | 1–6 | Multiplier for NaF inactivation and recovery rates |
| `nRate` | 1–10 | Multiplier for Kdr activation and deactivation rates |
| `gKCa` | 0.65–3.5 mS/cm² | Calcium-activated potassium conductance |

The two initial guesses are `[2.5, 4, 1.8]` and `[4.5, 7, 2.4]`. `gKdr = 100 mS/cm²` is fixed. The SOL fitting also uses these three free parameters, but permits lower values for `hRate` and `nRate` and has different targets. Bounds, initial guesses, and fitted kinetic factors are phenomenological choices, not measured channel properties.

The baseline NaP and CAN conductances are fixed at **the same values for both phenotypes**, `gNaP = 0.01` and `gCAN = 1.05 mS/cm²`. They are not measurements of biological SOL/TA channel density. `gCaL = 0.01 mS/cm²` follows the original repository implementation; `0.05 mS/cm²` also appears in the publication.

## Experimental targets

Hadzipasic et al. (2014), TA-associated cluster 3:

| Quantity | Target | How it is used |
|---|---:|---|
| Resting potential | −74.2 mV | Set as an equilibrium by deriving leak reversal potential `EL` |
| Input resistance | 48 MΩ | Determines an effective electrical area |
| Membrane time constant | 4.9 ms | Guides `gL` calibration and an objective penalty |
| First interspike firing frequency (FIF) | 340.6 Hz | Enters through the FIF/SSF ratio |
| Last interspike firing frequency (SSF) | 74.6 Hz | Objective target |
| FIF/SSF | 340.6/74.6 ≈ 4.57 | Objective target |

Resting voltage, membrane time constant, and input resistance are calibration targets, **not independently predicted properties**. Effective electrical area is not an anatomical area estimate.

## Fitting protocol

1. Start `fminsearch` (Nelder–Mead) at each of two initial guesses; candidates outside the selected ranges receive a penalty.
2. Construct the trial model using `fit_params.m` and adjust leak conductance with three corrections based on a **−0.05 µA/cm², 300-ms** hyperpolarizing response. Infer effective area using the input-resistance target.
3. Estimate the numerical rheobase with a **500-ms** step using a peak above 0 mV as the spike-detection criterion.
4. Run the current-step protocol: **1500 ms baseline at zero current, 500 ms at 3 × that candidate's own rheobase, 1800 ms recovery at zero current**.
5. Compute FIF and SSF as `1000/ISI`, using the first and last within-pulse interspike intervals (ISI in ms).
6. Accept candidates with **at least three within-pulse spike peaks and no prestimulus spikes**. **Poststimulus peaks are recorded but are not an exclusion criterion.** Three spikes permit two separate ISIs; this is a numerical minimum, not a biological threshold.
7. Select and save the valid candidate with the lowest objective.

The updated acceptance rule replaces the older requirement of eight pulse spikes and zero poststimulus firing. All trial protocols use `ode15s` with the same solver tolerances and peak-detection convention.

## Objective function

```text
J = [2 ln((FIF/SSF)/(340.6/74.6))]^2
  + [1.2 ln(SSF/74.6)]^2
  + 10 [ln(tau/4.9)]^2
  + 0.035 [(ln hRate)^2 + (ln nRate)^2 + (ln(gKCa/1.185))^2]
```

This is the same loss structure used for SOL-like fitting, with TA-specific targets. The weights and `1.185 mS/cm²` regularization reference are modeling choices. `fminsearch` is local, and the available targets do not uniquely identify ion-channel conductances or gating mechanisms.

## Current adopted solution

The values currently frozen in the root `model_params.m` come from the **updated fitting** (without the poststimulus exclusion). These supersede the older TA fit values `4.6392 / 6.5575 / 2.3736`:

| Parameter / result | TA-like |
|---|---:|
| `hRate` | 4.711388620598399 |
| `nRate` | 6.804273234097027 |
| `gKCa` (mS/cm²) | 2.3890445345840963 |
| `gL` (mS/cm²) | 0.18330878832335062 |
| Effective area (cm²) | 1.0497291222517192e-04 |
| Numerical rheobase (µA/cm²) | 2.861328125 |
| FIF (Hz), main simulation | 218.67 |
| SSF (Hz), main simulation | 54.08 |
| Spikes before / during / after | 0 / 42 / 0 |

The TA-like model shows greater initial firing and more adaptation than SOL-like, but it **underestimates the experimental TA firing rates** (FIF 340.6 Hz and SSF 74.6 Hz). This quantitative mismatch is a model limitation and should not be concealed.

## Output and interpretation

`results/TA_matlab_fitting.mat` stores `bestTheta`, `bestLoss`, the fitted parameter structure `p` including `p.rheobase`, `rh`, `tau`, `Rin`, `fif`, `ssf`, alternative starts and losses, and exit flags. Running the fitter again may produce a different local result; a new solution does not overwrite the adopted parent parameters automatically.

To generate the paper's final baseline and separate/combined NaP/CAN removal simulations, return to the project root and run:

```matlab
main
```

The root `main.m` invokes `compare_PIC()` automatically. **Neither fitting script runs when `main` is executed.**

## References

- Molkov et al. (2025), *Ionic mechanisms underlying bistability in spinal motoneurons: insights from a computational model*. https://doi.org/10.3389/fncel.2025.1710893
- Original ionic model implementation: https://github.com/jeterlab/ionic-mechanisms-underlying-bistability-in-spinal-motoneurons
- Hadzipasic et al. (2014), electrophysiological targets for the TA-associated cluster 3.
