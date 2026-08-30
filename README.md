# OFDM and OTFS Performance Comparison in a Doubly-Selective Channel

## 1. Project Overview

This undergraduate project implements and compares **OFDM** and **OTFS** in a wireless channel affected by multipath delay and Doppler.

The project starts from a simple engineering question:

> **When the same information is transmitted through the same time-varying multipath channel, which waveform gives better bit-error-rate performance as Doppler increases?**

To answer that question, the project builds the complete simulation chain:

```text
QAM data
   ↓
OFDM / OTFS modulation
   ↓
Doubly-selective EVA channel
   ↓
AWGN and selected impairments
   ↓
Channel estimation / equalization / detection
   ↓
BER and other performance measurements
   ↓
Plots and saved results
```

The main comparison is designed so that OFDM and OTFS are given the same basic conditions instead of giving one waveform an easier problem.

---

## 2. Project Goal

The project has one main goal and several supporting goals.

### Main goal

Compare the BER performance of OFDM and OTFS as the normalized Doppler

$$
f_D T_u
$$

increases.

Here,

$$
T_u = \frac{1}{\Delta f}
$$

is the useful OFDM symbol duration.

### Supporting goals

The project also studies:

- channel estimation;
- inter-carrier interference (ICI);
- receiver performance and complexity;
- OTFS pilot detection;
- practical impairments;
- channel Doppler behavior;
- covariance mismatch;
- MIMO reception and CSI aging.

These supporting experiments explain the main BER result and show how different parts of a wireless receiver affect performance.

---

## 3. What We Achieved

The project achieved the following:

1. Built an end-to-end MATLAB simulation for OFDM and OTFS.
2. Implemented a doubly-selective EVA channel with fractional path delays and Doppler.
3. Used the same physical channel conditions for the main OFDM/OTFS comparison.
4. Used the same information-symbol count and transmitted duration for both waveforms.
5. Used the same PCG-MMSE receiver class for the main comparison.
6. Measured BER over several normalized-Doppler values.
7. Added channel-estimation, ICI, receiver, pilot, impairment, channel, covariance, and MIMO studies.
8. Added automated configuration and numerical checks.
9. Completed the full simulation with all 16 studies.
10. Passed all **46 numerical checks** in the final run.

The most important result is that **OTFS shows a clear BER advantage over OFDM in the tested EVA doubly-selective channel**.

---

# Contents

| Section | Description |
|---|---|
| [1. Project Overview](#1-project-overview) | What the project is |
| [2. Project Goal](#2-project-goal) | Main objective |
| [3. What We Achieved](#3-what-we-achieved) | Final project outcome |
| [4. Main Result: OFDM vs OTFS](#4-main-result-ofdm-vs-otfs) | Main comparison and numbers |
| [5. Other Results](#5-other-results) | Supporting experiments |
| [6. System and Simulation Setup](#6-system-and-simulation-setup) | Main parameters and assumptions |
| [7. How the Simulation Works](#7-how-the-simulation-works) | Processing flow |
| [8. Project Folder Structure](#8-project-folder-structure) | What each folder contains |
| [9. Validation](#9-validation) | Correctness checks |
| [10. Running the Project](#10-running-the-project) | MATLAB commands |
| [11. Output Files](#11-output-files) | Generated files and figures |
| [12. Final Summary](#12-final-summary) | Main conclusion |

---

# 4. Main Result: OFDM vs OTFS

## 4.1 Comparison setup

The main comparison uses:

| Parameter | Value |
|---|---:|
| Carrier frequency | 2.4 GHz |
| Vehicle speed | 120 km/h |
| Subcarrier spacing | 15 kHz |
| Useful symbol duration | 66.666667 µs |
| OFDM FFT size | 256 |
| OFDM CP | 32 samples |
| Sampling rate | 3.84 MHz |
| Channel | EVA, 9 paths |
| Maximum path delay | 2.51 µs |
| OTFS grid | 32 × 128 |
| Information symbols/frame | 4096 |
| Transmitted samples/frame | 4608 |
| Receiver | matched PCG-MMSE |
| Tested normalized Doppler | 0.01, 0.05, 0.10, 0.20 |

The same basic conditions are used on both sides of the comparison:

- same physical channel;
- same information bits;
- same information-symbol count;
- same transmitted duration;
- same energy accounting;
- same receiver class.

This is important because the project is intended to compare the **waveforms**, not simply compare one waveform with a better receiver.

---

## 4.2 Figure 8 — OFDM vs OTFS BER

![OFDM vs OTFS BER](figures/08_ofdm_vs_otfs.png)

The main result is the BER difference between the two waveforms.

### BER at 12 dB

| \(f_D T_u\) | OFDM BER | OTFS BER | Approx. OTFS BER improvement |
|---:|---:|---:|---:|
| 0.01 | 1.850 × 10<sup>-2</sup> | 4.565 × 10<sup>-3</sup> | 4.1× |
| 0.05 | 1.449 × 10<sup>-2</sup> | 1.816 × 10<sup>-3</sup> | 8.0× |
| 0.10 | 1.477 × 10<sup>-2</sup> | 1.641 × 10<sup>-3</sup> | 9.0× |
| 0.20 | 1.454 × 10<sup>-2</sup> | 1.865 × 10<sup>-3</sup> | 7.8× |

So at 12 dB, OTFS gives about **4× to 9× lower BER** over the tested normalized-Doppler values.

### Required SNR for BER = 10<sup>-2</sup>

Interpolation of the measured BER curves gives:

| \(f_D T_u\) | OFDM \(E_b/N_0\) | OTFS \(E_b/N_0\) | OTFS advantage |
|---:|---:|---:|---:|
| 0.01 | 15.15 dB | 10.02 dB | **5.13 dB** |
| 0.05 | 13.62 dB | 9.02 dB | **4.60 dB** |
| 0.10 | 13.68 dB | 8.94 dB | **4.75 dB** |
| 0.20 | 13.46 dB | 9.09 dB | **4.37 dB** |

The main numerical result is therefore:

> **In the tested EVA channel, OTFS needs about 4.4–5.1 dB less \(E_b/N_0\) than OFDM to reach a BER of 10<sup>-2</sup> over \(f_D T_u = 0.01\) to 0.20 when the payload, duration, channel, and receiver class are matched.**

### One example

At

$$
f_D T_u = 0.10
$$

and

$$
E_b/N_0 = 20\ \text{dB},
$$

the measured OFDM BER is

$$
\frac{475}{204800}
=
2.3193\times10^{-3}.
$$

OTFS records zero observed errors at that point.

A zero-error measurement does **not** mean that the true BER is exactly zero. With finite data, it means that no errors were observed in the tested bits. The corresponding 95% upper bound used by the project is about:

$$
1.4628\times10^{-5}.
$$

So the correct interpretation is:

> OTFS produced no observed errors in the tested bits at that operating point, with a finite-sample upper bound on BER.

---

# 5. Other Results

## 5.1 Figure 1 — Baseline BER

![Baseline BER](figures/01_baseline_ber.png)

This figure gives the basic reference for the rest of the project.

The AWGN reference is the ideal case. The EVA channel results remain above it because the multipath channel creates frequency selectivity, and the time-varying case additionally introduces Doppler effects.

---

## 5.2 Figure 2 — Channel Estimation

![Channel Estimation](figures/02_channel_estimation.png)

The project compares:

- LS;
- DFT-LS;
- LMMSE;
- vector-Kalman estimation.

The tested ordering is:

$$
\text{Vector-Kalman}
\lesssim
\text{LMMSE}
<
\text{DFT-LS}
<
\text{LS}.
$$

Near the 20 dB operating point, vector-Kalman estimation gives roughly a fivefold reduction in NMSE compared with LS in the tested configuration.

---

## 5.3 Figure 3 — ICI Growth

![ICI Growth](figures/03_ici_growth_bandwidth.png)

ICI increases as Doppler increases.

At small normalized Doppler, the simulated trend is approximately consistent with the expected quadratic small-Doppler behavior. At larger Doppler, the simple approximation becomes less accurate.

This supports one of the main reasons OFDM becomes more difficult to detect in a fast time-varying channel.

---

## 5.4 Figure 4 — BEM Order

![BEM Order](figures/04_bem_order.png)

This experiment studies how the required Basis Expansion Model order changes with channel variation.

It is used to choose a useful model order without unnecessarily increasing computation.

---

## 5.5 Figure 5 — Receiver Comparison

![Receiver Comparison](figures/05_receiver_ladder_high_doppler.png)

This figure compares receiver choices at higher Doppler.

The important idea is the trade-off between:

- BER performance;
- receiver complexity;
- ability to deal with time variation.

The main OFDM/OTFS comparison uses the same PCG-MMSE receiver class so that this receiver choice does not become an extra advantage for either waveform.

---

## 5.6 Figure 6 — Receiver Cost

![Receiver Cost](figures/06_receiver_cost.png)

This figure compares the computational cost of the receiver choices.

The project therefore considers both performance and the amount of computation required to obtain that performance.

---

## 5.7 Figure 7 — OTFS Detectors

![OTFS Detectors](figures/07_otfs_detectors.png)

This experiment compares OTFS detection methods.

The message-passing detector is treated as a separate detector study. The main OFDM-vs-OTFS result does not depend on giving OTFS a different detector class.

---

## 5.8 Figure 9 — OTFS Pilot

![OTFS Pilot](figures/09_otfs_pilot.png)

This experiment checks the implemented OTFS pilot path-detection method.

It demonstrates the behavior of the selected pilot, guard region, threshold, and channel conditions used in the project.

---

## 5.9 Figure 10 — Impairments

![Impairments](figures/10_impairments.png)

The impairment study covers:

- CP length;
- phase noise;
- impulsive noise.

The wide EVA representation has a resolved channel-memory span of **13 samples**, while the nominal OFDM CP is 32 samples.

The phase-noise experiment shows small degradation at low phase-noise levels and much larger BER degradation at higher phase-noise levels.

The impulsive-noise experiment shows increasing BER as impulse probability increases.

---

## 5.10 Figure 11 — Physical Channel Diagnostics

![Physical Channel Diagnostics](figures/11_physical_channel_diagnostics.png)

The project keeps two channel models separate:

1. the clustered EVA physical channel;
2. a separate ideal Clarke/Jakes reference.

The generated Clarke/Jakes reference follows the theoretical autocorrelation

$$
R(\tau)=J_0(2\pi f_D\tau).
$$

The final normalized ACF RMSE is approximately **0.0232**.

This checks that the Jakes reference generation behaves as expected. It does not mean that the clustered EVA channel is itself an ideal Jakes channel.

---

## 5.11 Figure 12 — Covariance Mismatch

![Covariance Mismatch](figures/12_covariance_mismatch.png)

This experiment studies the effect of using an incorrect channel covariance model in an LMMSE/Bayesian estimator.

The result shows that estimator performance depends on how well the assumed channel statistics match the actual channel statistics.

---

## 5.12 Figure 13 — MIMO

![MIMO](figures/13_mimo_ofdm.png)

The tested ordering is:

$$
\text{Perfect-CSI MMSE}
<
\text{Aged-CSI MMSE}
<
\text{ZF}.
$$

The result shows that CSI aging can cause a large performance penalty in a changing channel.

The tested high-SNR CSI-aging penalty is approximately **10.1 dB** in the selected MIMO configuration.

---

# 6. System and Simulation Setup

## 6.1 OFDM parameters

The production comparison uses:

$$
\Delta f = 15\text{ kHz}
$$

and therefore

$$
T_u=\frac{1}{15\,000}
=66.666667\ \mu s.
$$

The wide OFDM configuration uses:

- FFT size \(N=256\);
- sampling rate \(f_s=3.84\) MHz;
- CP length = 32 samples.

The wide configuration is used because it gives a better time-domain representation of the EVA path delays than the quick narrow configuration.

## 6.2 EVA channel

The channel contains 9 paths with a maximum physical delay of 2.51 µs.

Fractional-delay interpolation is used because physical path delays do not generally fall exactly on integer sample locations.

In the wide configuration the resolved representation contains **14 rows**, corresponding to a **13-sample memory span**.

## 6.3 Doppler

The main Doppler parameter is:

$$
f_D T_u.
$$

Using \(T_u=66.666667\,\mu s\), the Figure 8 values correspond approximately to:

| \(f_D T_u\) | Doppler |
|---:|---:|
| 0.01 | 150 Hz |
| 0.05 | 750 Hz |
| 0.10 | 1500 Hz |
| 0.20 | 3000 Hz |

The Doppler sweep is therefore directly tied to the OFDM useful-symbol duration.

## 6.4 OTFS grid

The OTFS grid is:

$$
32\times128=4096
$$

delay-Doppler symbols per frame.

The main comparison uses the same number of information symbols as OFDM.

---

# 7. How the Simulation Works

The main processing chain is:

### Step 1 — Generate information bits

Random information bits are generated and mapped to QAM symbols.

### Step 2 — Build the waveform

The symbols are converted into either:

- OFDM time-domain samples; or
- OTFS time-domain samples.

### Step 3 — Generate the physical channel

The EVA channel provides the multipath delays and Doppler variation.

Fractional-delay interpolation preserves the sub-sample delay structure.

### Step 4 — Apply the channel

The transmitted waveform passes through the time-varying multipath channel.

### Step 5 — Add noise and impairments

AWGN is added at the required \(E_b/N_0\). Separate experiments add phase noise, impulsive noise, or CP stress.

### Step 6 — Receiver processing

Depending on the experiment, the receiver performs:

- channel estimation;
- frequency-domain equalization;
- PCG-MMSE detection;
- OTFS detection;
- MIMO detection.

### Step 7 — Measure performance

The code records:

- BER;
- NMSE;
- ICI power;
- pilot detection;
- complexity;
- covariance effects;
- MIMO performance.

### Step 8 — Save results

The result structures and figures are written to the `results/` directory.

---

# 8. Project Folder Structure

```text
OFDM_OTFS_V8_5_CLAIMABLE_CLEAN/
│
├── main.m
├── timing_probe.m
├── plot_results.m
│
├── experiments/
│   └── research_suite.m
│
├── src/
│   ├── core/
│   │   └── physical_core.m
│   ├── otfs/
│   │   └── otfs_core.m
│   ├── receivers/
│   │   └── estimation_receiver.m
│   └── mimo/
│       └── mimo_resource_allocation.m
│
├── validation/
│   ├── quick_smoke_test.m
│   └── analysis_tools.m
│
└── figures/
    ├── 01_baseline_ber.png
    ├── 02_channel_estimation.png
    ├── 03_ici_growth_bandwidth.png
    ├── 04_bem_order.png
    ├── 05_receiver_ladder_high_doppler.png
    ├── 06_receiver_cost.png
    ├── 07_otfs_detectors.png
    ├── 08_ofdm_vs_otfs.png
    ├── 09_otfs_pilot.png
    ├── 10_impairments.png
    ├── 11_physical_channel_diagnostics.png
    ├── 12_covariance_mismatch.png
    └── 13_mimo_ofdm.png
```

### `main.m`

Main entry point for checks, timing calibration, and simulation runs.

### `experiments/`

Contains the experiments that generate the project results.

### `src/core/`

Contains the main physical channel and OFDM processing functions.

### `src/otfs/`

Contains OTFS modulation, demodulation, and delay-Doppler processing.

### `src/receivers/`

Contains channel-estimation and receiver functions.

### `src/mimo/`

Contains the MIMO processing functions.

### `validation/`

Contains the fast correctness checks and supporting analysis.

### `figures/`

Contains the project result figures used in the README and presentations.

---

# 9. Validation

The project has two kinds of checks.

## 9.1 Configuration checks

These verify items such as:

- CP coverage;
- channel power normalization;
- Doppler calculation;
- delay representation;
- OFDM/OTFS dimensions.

## 9.2 Numerical checks

The final simulation passed:

```text
[PASS] Scientific validation gate passed basic checks.
[PASS] Numerical identity gate: 46/46 checks passed.
[PASS] Result passed both the scientific and the numerical gate.
```

The checks are used to catch implementation errors before using the simulation results.

---

# 10. Running the Project

MATLAB is required.

Open MATLAB and set the current folder to the project directory.

## 10.1 Basic checks

Run:

```matlab
main('CHECKS')
```

This performs the fast configuration and implementation checks.

A narrow-mode delay-resolution warning is expected during this command because the quick check uses a smaller FFT and lower sampling rate.

## 10.2 Estimate the runtime

Run:

```matlab
main('SMOKE','wide')
```

This measures smaller versions of the studies and estimates how long the full simulation will take.

## 10.3 Run the complete project

Run:

```matlab
main('AUDIT','wide','RESTART')
```

This runs all 16 studies from the beginning.

The longest studies are normally:

- OTFS;
- OFDM vs OTFS crosswaveform comparison;
- impairments.

The final complete run used approximately 1.5 hours on the computer used for this project.

## 10.4 Plot saved results

After results have been generated:

```matlab
main('PLOTS','wide')
```

generates the project figures from the saved results.

---

# 11. Output Files

A completed run produces a `results/` directory containing files such as:

```text
results/
│
├── audit_wide_results.mat
├── validation.mat
├── claimability_summary.txt
├── claim_crosswaveform_metrics.csv
│
├── checkpoints/
│   └── checkpoint_audit_wide.mat
│
└── figures/
    ├── 01_baseline_ber.png
    ├── 02_channel_estimation.png
    ├── 03_ici_growth_bandwidth.png
    ├── 04_bem_order.png
    ├── 05_receiver_ladder_high_doppler.png
    ├── 06_receiver_cost.png
    ├── 07_otfs_detectors.png
    ├── 08_ofdm_vs_otfs.png
    ├── 09_otfs_pilot.png
    ├── 10_impairments.png
    ├── 11_physical_channel_diagnostics.png
    ├── 12_covariance_mismatch.png
    └── 13_mimo_ofdm.png
```

The most important files for the project are:

- `audit_wide_results.mat` — all numerical results;
- `claim_crosswaveform_metrics.csv` — main OFDM/OTFS comparison data;
- `figures/08_ofdm_vs_otfs.png` — main project result.

---

# 12. Final Summary

This project started with a practical comparison of OFDM and OTFS and developed into a complete MATLAB simulation covering the important parts of the communication chain.

The central result is:

> **For the tested EVA doubly-selective channel, OTFS required approximately 4.4–5.1 dB less \(E_b/N_0\) than OFDM to reach BER = 10<sup>-2</sup> over \(f_D T_u = 0.01\)–0.20 when the payload, duration, channel, and receiver class were matched.**

The supporting experiments show:

- ICI increases as Doppler increases;
- channel estimation improves when moving from LS to DFT-LS, LMMSE, and vector-Kalman processing;
- receiver complexity must be considered together with BER;
- phase noise and impulsive noise degrade performance as their severity increases;
- covariance mismatch affects LMMSE estimation;
- CSI aging can significantly reduce MIMO performance.

The final project therefore gives a complete undergraduate-level implementation and performance comparison of **OFDM and OTFS in a time-varying multipath wireless channel**.
