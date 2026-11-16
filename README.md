# SOL-like and TA-like motoneuron models

BIOE 472 — Models of the Nervous System  
**Integrated main simulation, independent numerical fitting, and four-condition NaP/CAN comparisons**

## Project purpose

This project investigates how differences in motoneuron electrophysiological properties and persistent inward currents affect firing rates and spike-frequency adaptation. It compares two **single-compartment, six-state conductance-based models**, SOL-like and TA-like, adapted from Molkov et al. (2025). Their resting and firing properties are calibrated against the SOL-associated **cluster 1** and TA-associated **cluster 3** reported by Hadzipasic et al. (2014).

Both models were **numerically calibrated using `fminsearch`**, with the **same three adjustable parameters**: `hRate`, `nRate`, and `gKCa`. The experimental targets differ between phenotypes. The fitted kinetic factors and conductances are phenomenological model estimates, not direct measurements of ion-channel properties.

## Folder structure

```text
Molkov_SOL_TA_project/
├── main.m             Main entry point: SOL/TA simulations, then PIC comparison
├── compare_PIC.m      Function called by main.m: four NaP/CAN conditions
├── model_params.m     Fixed parameters selected from both fitting workflows
├── dyn.m              Six-state ionic differential equations
├── run_protocol.m     ode15s integration and findpeaks spike detection
├── fitting_SOL/        Independent SOL-like numerical fitting
│   ├── main_fitting.m
│   ├── fit_params.m
│   ├── find_rheobase.m
│   ├── dyn.m
│   ├── run_protocol.m
│   └── README.md
├── fitting_TA/         Independent TA-like numerical fitting
│   ├── main_fitting.m
│   ├── fit_params.m
│   ├── find_rheobase.m
│   ├── dyn.m
│   ├── run_protocol.m
│   └── README.md
└── README.md
```

The root `results/` folder is created when `main` runs. Each fitting folder creates its own independent `results/` directory when `main_fitting` is run.

## How to run

Open the project root (`Molkov_SOL_TA_project`) as MATLAB's **Current Folder** and run **one command**:

```matlab
main
```

`main.m` performs the calibrated SOL-like and TA-like reference simulations, exports their summary and figures, and then calls **`compare_PIC()` automatically**. The latter is a MATLAB **function**, not a separate script in the final workflow. It evaluates Both ON, NaP OFF, CAN OFF, and Both OFF for each phenotype and exports the corresponding figures and CSV. **Do not run `compare_PIC` a second time after `main`** unless you deliberately want to repeat that comparison.

To repeat a numerical fitting procedure, open the corresponding folder as MATLAB's **Current Folder** and run:

```matlab
main_fitting
```

`fitting_SOL/main_fitting.m` and `fitting_TA/main_fitting.m` are independent scripts. They save `results/SOL_matlab_fitting.mat` and `results/TA_matlab_fitting.mat`, respectively, within their own folders. **Neither fitting procedure is run by `main`**. To adopt a fitted parameter set, transfer the values into the root `model_params.m` and rerun `main`.

**Important:** Each fitting folder has its own `dyn.m` and `run_protocol.m`. Do not add all project subfolders recursively to the MATLAB path, since functions with identical names may conflict. Keep these shared functions consistent when making corrections.

**Requirements:** MATLAB and Signal Processing Toolbox (`findpeaks`). `fminsearch` does not require Optimization Toolbox.

## Model and parameter calibration

The six state variables are membrane voltage, intracellular calcium, CaL activation, CaL inactivation, NaF inactivation, and Kdr activation. The seven modeled membrane currents are **NaF, NaP, Kdr, CaL, KCa, CAN, and leak**. Kv1.2 is omitted because its conductance is zero in the chosen configuration.

Both fitting workflows optimize:

| Parameter | Role |
|---|---|
| `hRate` | Multiplies the speed of NaF inactivation and recovery |
| `nRate` | Multiplies the speed of Kdr activation and deactivation |
| `gKCa` | Calcium-activated K⁺ conductance (mS/cm²) |

`gKdr = 100 mS/cm²` is held fixed for **both final models**, following the original Molkov parameterization. The shared NaP and CAN conductances (`gNaP = 0.01`, `gCAN = 1.05 mS/cm²`) are modeling choices, **not** SOL- or TA-specific experimental measurements.

The fitting procedure:

1. Constructs a resting equilibrium at the target resting voltage by deriving the leak reversal potential `EL` from zero net current.
2. Adjusts `gL` to approximate the target membrane time constant using a small hyperpolarizing pulse; derives an **effective electrical area** from the target input resistance. These are not independently predicted quantities.
3. Estimates the **500 ms numerical rheobase**, defined as the minimum tested rectangular current producing at least one detected spike.
4. Applies a 500 ms pulse of **3 × that candidate's ON-condition rheobase**, with 1500 ms pre-stimulus and 1800 ms post-stimulus at zero injected current.
5. Calculates **FIF** and **SSF** as `1000 / ISI` (ISI in ms) for the first and last within-pulse interspike intervals, and compares SSF and FIF/SSF with experimental targets.
6. Uses two starting points with `fminsearch` and selects the valid candidate with the lowest objective value, including a regularization term.
7. In the **updated** fitting criterion, candidates must have at least **three** within-pulse spikes and no pre-stimulus spikes. Post-stimulus spikes are **recorded but not grounds for rejection**. The three-spike minimum is a computational requirement to obtain separate first and last ISIs, not a physiological threshold.

Fitting bounds, initial guesses, and objective weights are **numerical modeling choices**, not experimentally established ranges. The optimization is local, and the fitted parameters are not uniquely identifiable from the selected firing targets. See the README in each fitting folder for exact settings.

### Experimental targets and current main-simulation results

The tables below refer to the **updated fitted parameters**, after removing the previous `nPost > 0` exclusion and replacing the eight-spike minimum with a three-spike minimum.

| Property | SOL experimental | SOL-like model | TA experimental | TA-like model |
|---|---:|---:|---:|---:|
| Resting potential (mV) | −70.3 | −70.30 | −74.2 | −74.20 |
| Input resistance (MΩ) | 95.4 | 95.40 | 48.0 | 48.00 |
| Membrane time constant (ms) | 8.9 | 8.90 | 4.9 | 4.90 |
| FIF (Hz) | 45.9 | 48.92 | 340.6 | 218.67 |
| SSF (Hz) | 31.9 | 33.37 | 74.6 | 54.08 |
| FIF/SSF | 1.44 | 1.47 | 4.57 | 4.04 |
| Spikes before/during/after pulse | — | 0/19/0 | — | 0/42/0 |
| Numerical rheobase (µA/cm²) | — | 0.861816 | — | 2.861328 |

The key phenotype-specific parameters in the root `model_params.m` are:

| Parameter | SOL-like | TA-like |
|---|---:|---:|
| `hRate` | 0.8831005817202662 | 4.711388620598399 |
| `nRate` | 0.3519733081847274 | 6.804273234097027 |
| `gKCa` (mS/cm²) | 0.8335601089772888 | 2.3890445345840963 |
| `gL` (mS/cm²) | 0.10448386558117018 | 0.18330878832335062 |
| Effective area (cm²) | 9.566538424497626e−05 | 1.0497291222517192e−04 |

These values agree with the updated `summary_matlab.csv` and the two new fitting `.mat` files. Resting potential, input resistance, and membrane time constant were calibrated to the targets, **not independently predicted**. SOL firing is quantitatively close to the targets; TA reproduces higher initial firing and stronger adaptation than SOL but continues to underestimate its experimental absolute FIF and SSF.

## Independent NaP and CAN removal experiment

`compare_PIC.m` now examines **four conditions in each calibrated phenotype**:

| Condition | `gNaP` | `gCAN` |
|---|---|---|
| Both ON | Original | Original |
| NaP OFF | 0 | Original |
| CAN OFF | Original | 0 |
| Both OFF | 0 | 0 |

The original conductances are **the same in both calibrated phenotypes** (`gNaP = 0.01` and `gCAN = 1.05 mS/cm²`). Their **functional contributions** are assessed separately in two motoneurons with different calibrated electrophysiological properties. This comparison does **not** establish experimentally measured differences in NaP/CAN channel densities between SOL and TA.

For each phenotype, the applied rectangular current stays fixed at **3 × the original Both-ON rheobase** in all four conditions. The leak reversal potential, CaL, KCa, gating kinetics and all other parameters are unchanged. Modified configurations are allowed to settle for 2000 ms at zero applied current before the standard 1500 ms baseline, 500 ms pulse and 1800 ms recovery. There is **no refitting**.

As well as FIF, SSF and spike counts, the updated comparison reports the number of spikes during the **last 100 ms** of stimulation and the time of the **last spike** relative to pulse onset. These help identify sparse or intermittent firing, for which an SSF calculated from the final ISI does not necessarily represent steady-state firing.

### Four-condition PIC results with the updated fitted parameters

All conditions within one phenotype receive the same current, obtained from the **Both-ON** rheobase: **2.585449 µA/cm²** for SOL and **8.583984 µA/cm²** for TA. The table reflects the latest MATLAB export, `PIC_components_summary.csv`.

| Model | Condition | FIF (Hz) | SSF (Hz) | FIF/SSF | Spikes pre/during/post | Spikes in final 100 ms |
|---|---|---:|---:|---:|---:|---:|
| SOL-like | Both ON | 48.92 | 33.37 | 1.47 | 0/19/0 | 3 |
| SOL-like | NaP OFF | 47.99 | 31.08 | 1.54 | **0/18/1** | 3 |
| SOL-like | CAN OFF | 42.49 | 10.99 | 3.87 | 0/8/0 | 1 |
| SOL-like | Both OFF | 41.52 | 13.93 | 2.98 | 0/7/0 | 1 |
| TA-like | Both ON | 218.67 | 54.08 | 4.04 | 0/42/0 | 6 |
| TA-like | NaP OFF | 215.28 | 47.85 | 4.50 | 0/38/0 | 4 |
| TA-like | CAN OFF | 215.17 | 38.61 | 5.57 | 0/32/0 | 4 |
| TA-like | Both OFF | 211.78 | 32.41 | 6.53 | 0/29/0 | 4 |

**Interpretation:** At the fixed applied currents and conductances selected for this project, removing CAN has a larger impact than removing NaP on spike count in both phenotypes, especially SOL. This does **not** imply different measured NaP or CAN channel densities in biological SOL and TA motoneurons. The consequences of separate removals need not add linearly, given the voltage- and calcium-dependent dynamics.

**Sparse firing in SOL:** The `SSF` values for SOL CAN OFF and Both OFF are simply reciprocals of the last within-pulse ISIs. Because these trains are irregular, they should **not** be described as verified steady-state firing frequencies. The final-100-ms spike count and last-spike time provide additional context.

**Isolated post-stimulus event:** In SOL NaP OFF, one peak is detected **2.5277 ms after stimulus offset**. Inspection of the voltage trace suggests that the depolarization leading to this spike was already underway before the stimulus ended. Spikes are assigned to protocol phases by **peak time**, so this isolated event is counted as post-stimulus. No subsequent spike train was observed; it is **not evidence of self-sustained firing or bistability**. This does not establish a definitive action-potential onset time, which would require a separate onset-detection rule.

The ablations leave `EL` unchanged, so the resting potential and potentially the rheobase change. These are fixed-*absolute*-current comparisons, not comparisons at an equal multiple of each ablated model's own rheobase.

## Protocol, numerical method, and outputs

- `run_protocol.m` integrates constant-current intervals consecutively using `ode15s`, maintaining continuity of the state vector across intervals.
- Action potentials are detected as voltage peaks above **0 mV** using `findpeaks`. This is a **detection cutoff**, not the physiological excitation threshold. Subthreshold traces should return an empty spike list without unnecessary warnings.
- `main.m` runs 1500 ms at zero current, 500 ms at 3 × stored rheobase, and 1800 ms at zero current for both ON-condition models, then calls `compare_PIC()`.
- FIF and SSF are defined if there is at least one ISI (two spike peaks); the **fitting acceptance criterion** uses three within-pulse spikes to obtain distinct first and last ISIs. Sparse trains should not be interpreted as demonstrating stationary firing.

Running `main` creates all of the following files in the root `results/` folder:

| File | Contents |
|---|---|
| `SOL_like.png` | SOL-like voltage, instantaneous firing frequency and injected current |
| `TA_like.png` | TA-like voltage, instantaneous firing frequency and injected current |
| `summary_matlab.csv` | Passive and firing metrics for both final models |
| `PIC_components_voltage.png` | Eight separate membrane-voltage plots (two phenotypes × four conditions) |
| `PIC_components_frequency.png` | Eight separate instantaneous-frequency plots |
| `PIC_components_summary.csv` | Four-condition results, including last-100-ms spike count and last spike time |

## Scientific limitations

- This is a **single-compartment phenomenological model**, without dendritic spatial structure or explicit changes in intracellular/extracellular Na⁺ and K⁺ concentrations.
- NaF and NaP activation is instantaneous in this formulation. Intracellular calcium is represented by one effective state, with the slow calcium time constant incorporating CICR phenomenologically rather than modeling calcium stores explicitly.
- `gCaL = 0.01 mS/cm²` follows the original repository code; `0.05 mS/cm²` is also reported in the publication. This version uses the repository value.
- The numerical fitting does **not** uniquely identify biological channel densities or kinetic mechanisms. `hRate` and `nRate` scale the full kinetic rates, not only recovery or activation in one direction.
- The TA-like model reproduces greater initial firing and adaptation than SOL-like, but **does not quantitatively match** Hadzipasic's TA FIF and SSF.
- The four-condition experiment manipulates **NaP and CAN only**, not every persistent inward current. It leaves CaL and KCa active. Individual ablations quantify each modeled contribution in context, but do not prove experimentally different ion-channel densities in SOL and TA.
- No persistent post-stimulus spike train was observed. The single peak occurring 2.5277 ms after stimulus offset in SOL NaP OFF is an isolated transition event. The simulations **do not establish bistability, recruitment/derecruitment hysteresis, or self-sustained firing**.
- The reported passive properties reflect calibration to the target values, not independent validation.

## References

1. **Molkov et al. (2025)**, *Ionic mechanisms underlying bistability in spinal motoneurons: insights from a computational model*. https://doi.org/10.3389/fncel.2025.1710893  
   Original implementation: https://github.com/jeterlab/ionic-mechanisms-underlying-bistability-in-spinal-motoneurons
2. **Hadzipasic et al. (2014)**, experimental electrophysiological targets for the SOL-associated cluster 1 and TA-associated cluster 3.

**Status:** Both numerical fitting workflows and all eight PIC conditions have been run in MATLAB with the updated parameter sets. The root `main.m` is now the **single entry point for final simulations**, calling `compare_PIC()` after the reference runs. Both fitting scripts remain independent. **Running a fitter does not automatically update `model_params.m`**; any change to fitted parameters requires rerunning `main` and updating the result tables. Older `PIC_ON_OFF_*` files may remain in `results/` from previous versions and should not be mixed with the current `PIC_components_*` outputs.
