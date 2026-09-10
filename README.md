# OFDM and OTFS in a Doubly-Selective Channel

A MATLAB simulation platform that compares OFDM and OTFS bit-error-rate performance
under multipath delay and Doppler, together with fourteen supporting studies covering
channel estimation, inter-carrier interference, receiver design, and system diagnostics.

Every number in this document is read from the saved result files
`results/audit_wide_results.mat` and `results/claim_crosswaveform_metrics.csv`,
produced by a full AUDIT run in the wide numerology.

---

## Contents

| Section | Description |
|---|---|
| [1. What this project answers](#1-what-this-project-answers) | The question and the approach |
| [2. Claim scope](#2-claim-scope) | What the results do and do not support |
| [3. Main result: OFDM vs OTFS](#3-main-result-ofdm-vs-otfs) | The headline comparison |
| [4. System and simulation setup](#4-system-and-simulation-setup) | Parameters and conventions |
| [5. Supporting results](#5-supporting-results) | The other fifteen studies |
| [6. Validation](#6-validation) | Correctness gates |
| [7. Known limitations](#7-known-limitations) | Honest boundaries |
| [8. Running the project](#8-running-the-project) | MATLAB commands |
| [9. Repository structure](#9-repository-structure) | What each folder holds |

---

## 1. What this project answers

> When the same information bits are carried through the same time-varying multipath
> channel, with the same frame duration and the same detector, which waveform gives
> lower BER as Doppler increases?

The project builds the full chain to answer it:

1. Load and validate the configuration.
2. Generate random bits and map them to Gray-labelled QAM symbols.
3. Build the OFDM or OTFS waveform.
4. Generate the clustered EVA channel realization.
5. Apply fractional path delays and per-ray Doppler.
6. Add AWGN, or a selected impairment in the impairment studies.
7. Estimate the channel where the study calls for it.
8. Equalize and detect.
9. Count bit errors against the transmitted bits.
10. Compute BER, NMSE, ICI power, complexity, and paired statistics.
11. Repeat across SNR, Doppler, and per-study settings.
12. Save numerical results and checkpoint.
13. Run both validation gates.
14. Generate figures.

The comparison is deliberately constructed so neither waveform is handed an easier
problem: same physical channel realization, same information-symbol budget, same
transmitted duration, same energy accounting, and the same receiver.

---

## 2. Claim scope

**What the main result supports.** In the tested EVA doubly-selective channel, with
perfect CSI, a matched truncated PCG-MMSE receiver, equal information-bit budget,
equal waveform duration, and paired information bits, OTFS required approximately
**4.4–5.1 dB less E_b/N_0 than OFDM to reach BER = 10⁻²** across
f_D·T_u = 0.01 to 0.20.

**What it does not support.** This is a single-configuration, perfect-CSI, uncoded
QPSK study. It is not evidence of universal OTFS superiority, does not establish a
diversity order, and says nothing about performance with realistic channel
estimation, coding, or other channel profiles.

Specific statements this project does **not** make:

- OTFS is better than OFDM in general.
- OTFS achieves BER = 0. Zero-error observations are censored measurements reported
  as one-sided 95% upper bounds.
- The measured BER slopes establish a diversity order. They are descriptive fits only.
- The clustered EVA channel is an ideal Clarke/Jakes process. The Jakes reference in
  Figure 11 is generated separately, purely to validate the generator.
- The impairment sweeps are universal robustness bounds. They are controlled
  sensitivity experiments at one SNR.

---

## 3. Main result: OFDM vs OTFS

### 3.1 Comparison setup

| Parameter | Value |
|---|---:|
| Carrier frequency | 2.4 GHz |
| Reference vehicle speed | 120 km/h |
| Subcarrier spacing Δf | 15 kHz |
| Useful symbol duration T_u | 66.667 µs |
| OFDM FFT size N | 256 |
| OFDM cyclic prefix | 32 samples |
| Sampling rate f_s | 3.84 MHz |
| Channel profile | EVA, 9 paths, max delay 2.51 µs |
| OTFS delay-Doppler grid | 32 × 128 |
| OTFS cyclic prefix | 4 samples per block |
| Information symbols per frame | 4096 (both waveforms) |
| Transmitted samples per frame | 4608 (both waveforms) |
| Modulation | QPSK, Gray-labelled, uncoded |
| Receiver | Matched truncated PCG-MMSE, 25 iterations, tol 1e-6 |
| CSI | Perfect |
| Frames per point | 25 → 204,800 paired bits per point |
| Tested normalized Doppler | 0.01, 0.05, 0.10, 0.20 |

Equality of the two sides is enforced by assertion in `research_suite.m` and
re-checked by the numerical gate (checks 24 and 25): OFDM 256 × 16 = OTFS 32 × 128
information symbols, and 16 × (256 + 32) = 128 × (32 + 4) = 4608 samples.

### 3.2 Measured BER

![OFDM vs OTFS BER](results/figures/08_ofdm_vs_otfs.png)

At E_b/N_0 = 12 dB:

| f_D·T_u | OFDM BER | OTFS BER | Ratio |
|---:|---:|---:|---:|
| 0.01 | 1.850 × 10⁻² | 4.565 × 10⁻³ | 4.1× |
| 0.05 | 1.449 × 10⁻² | 1.816 × 10⁻³ | 8.0× |
| 0.10 | 1.477 × 10⁻² | 1.641 × 10⁻³ | 9.0× |
| 0.20 | 1.454 × 10⁻² | 1.865 × 10⁻³ | 7.8× |

### 3.3 Required E_b/N_0 at BER = 10⁻²

Log-linear interpolation of the measured curves:

| f_D·T_u | OFDM | OTFS | OTFS advantage |
|---:|---:|---:|---:|
| 0.01 | 15.15 dB | 10.02 dB | **5.13 dB** |
| 0.05 | 13.62 dB | 9.02 dB | **4.60 dB** |
| 0.10 | 13.68 dB | 8.94 dB | **4.75 dB** |
| 0.20 | 13.46 dB | 9.09 dB | **4.37 dB** |

### 3.4 Statistical treatment

Every BER point carries 204,800 bits and a 95% Wilson confidence interval. Because
both waveforms carry identical information bits through the same channel realization,
the comparison is paired, and an exact McNemar test is computed per point.

At the pre-designated primary endpoint, f_D·T_u = 0.10 and E_b/N_0 = 20 dB:

- OFDM: 475 errors in 204,800 bits, BER 2.3193 × 10⁻³, 95% CI [2.120, 2.537] × 10⁻³
- OTFS: 0 errors in 204,800 bits, 95% CI [0, 1.876 × 10⁻⁵]
- Zero-error one-sided 95% upper bound: 1.4628 × 10⁻⁵
- Discordant pairs: 209 OFDM-only errors, 0 OTFS-only errors
- Exact paired McNemar p = 2.43 × 10⁻⁶³ (diagnostic, not a preregistered test)

A zero-error observation does not mean the true BER is zero. It means no errors were
seen in the tested bits, and the correct reporting is the upper bound above. All
zero-error points are drawn on Figure 8 at that bound and circled.

### 3.5 Why the delay-Doppler domain does not help the detector here

The cross-waveform study also computes a sparsity diagnostic on the effective
delay-Doppler operator. Measured density was **0.236 to 0.249** across the Doppler
sweep, well above the 0.15 threshold the code uses to decide whether message-passing
detection is admissible. The message-passing branch was therefore never executed, and
`crosswaveform.berOTFS_MP` is NaN throughout.

The cause is Doppler resolution. The 4608-sample frame gives a Doppler bin of
833 Hz, so the tested Doppler shifts of 150, 750, 1500 and 3000 Hz correspond to
0.18, 0.90, 1.80 and 3.60 bins. Sub-bin and fractional Doppler spreads each path
across the whole Doppler axis, destroying the sparsity that message passing assumes.

This is a substantive finding rather than a limitation to hide: it is precisely why
the headline comparison uses a matched linear detector for both waveforms, and why
the sparse-graph detector results in Section 5.5 are reported separately on a
synthetic channel.

---

## 4. System and simulation setup

### 4.1 OFDM numerology

With Δf = 15 kHz, T_u = 1/Δf = 66.667 µs. The wide configuration uses N = 256,
f_s = 3.84 MHz, CP = 32 samples (8.333 µs), giving T_sym = 75 µs.

The narrow configuration (N = 64, f_s = 0.96 MHz) exists for fast smoke testing only.
It does not resolve the EVA delay profile, and `main('CHECKS')` prints an expected
delay-resolution warning when it runs.

### 4.2 EVA channel

Nine paths, delays 0 to 2510 ns, powers normalized to unit total. Path delays do not
land on integer sample positions, so a windowed-sinc fractional-delay bank
(half-length 4) resolves them. In the wide configuration this produces **14 resolved
tap rows, i.e. a 13-sample channel memory span**, comfortably inside the 32-sample CP.

Each path is generated as a cluster of 16 rays with 25° angular spread and per-ray
Doppler, rather than a classical Jakes sum. This is the physical model throughout.

### 4.3 Doppler convention

Normalized Doppler is f_D·T_u with T_u the OFDM useful-symbol duration:

| f_D·T_u | Doppler | Equivalent speed at 2.4 GHz |
|---:|---:|---:|
| 0.01 | 150 Hz | 67 km/h |
| 0.05 | 750 Hz | 337 km/h |
| 0.10 | 1500 Hz | 675 km/h |
| 0.20 | 3000 Hz | 1350 km/h |

The upper two points are beyond terrestrial vehicular mobility at this carrier. They
are retained as a stress range for the waveform comparison, not as a mobility claim.

### 4.4 Noise convention

Noise is generated in the time domain with variance `noiseVarTD`. The unnormalized
N-point receive FFT inflates it by exactly N, so every frequency-domain estimator,
equalizer and bound receives `noiseVarFD = N · noiseVarTD`. This is verified
numerically (check 5, measured inflation 256.0 against N = 256).

For the cross-waveform study, E_b/N_0 is referenced to the measured CP-inclusive
transmitted waveform energy per information bit, using the same convention for both
waveforms.

---

## 5. Supporting results

### 5.1 Baseline OFDM BER

![Baseline BER](results/figures/01_baseline_ber.png)

Three references at 51,200 bits per point: AWGN, static EVA, and Doppler EVA, all
with perfect-CSI one-tap MMSE equalization.

At 12 dB the measured BERs are 9.01 × 10⁻⁹ (theory) for AWGN, 1.326 × 10⁻² for static
EVA, and 1.773 × 10⁻² for Doppler EVA. The AWGN simulation tracks the QPSK analytical
curve where it is resolvable and is censored beyond 8 dB, where the resolution floor
is 5.85 × 10⁻⁵.

The gap between static and Doppler EVA is the visible cost of the time variation that
the one-tap equalizer does not model.

### 5.2 Channel estimation

![Channel Estimation](results/figures/02_channel_estimation.png)

Five pilot-aided estimators on a comb pilot grid with spacing 4: LS, DFT-LS, LMMSE,
comb-pilot LMMSE (Wiener), and a two-symbol vector Kalman recursion.

Measured NMSE at 20 dB in the doubly-dispersive production sweep:

| Estimator | NMSE at 20 dB | Improvement over LS |
|---|---:|---:|
| LS | 3.768 × 10⁻³ | 1.00× |
| DFT-LS | 1.372 × 10⁻³ | 2.75× |
| LMMSE | 8.750 × 10⁻⁴ | 4.31× |
| **Comb-pilot Wiener** | **7.960 × 10⁻⁴** | **4.73×** |
| Vector Kalman | 3.908 × 10⁻³ | 0.96× |

The correct ordering is therefore:

```text
comb-pilot Wiener  <  LMMSE  <  DFT-LS  <  LS  ≈  vector Kalman
```

Across the full 0–30 dB sweep the comb-pilot Wiener estimator sits **3.1× to 7.8×
below LS** in NMSE.

**The vector Kalman recursion gives no gain over LS in this configuration.** On the
figure its curve lies on top of the LS curve. This is a design consequence rather than
a defect: the study runs a single update across two OFDM symbols, initialized from a
raw LS estimate, with the state transition α = J₀(2π f_D T_sym) = 0.9961 and process
covariance (1 − |α|²)·R_HH. One update from a noisy prior, with no steady-state gain
accumulation, cannot improve on the observation it started from.

**Against the bounds.** The Bayesian posterior CRLB applies to the diagonal
linear-Gaussian pilot model z_p = h_p + v_p/X_p, which is ICI-free. Evaluated on that
reference channel, the comb-pilot Wiener estimator holds to **0.95–1.10× of the
Bayesian CRLB** across 0–30 dB (numerical checks 30 and 31 record the worst ratios,
1.104 and 0.947).

In the production doubly-dispersive sweep the same estimator departs from the bound at
high SNR, from 0.99× at 0 dB to 6.9× at 30 dB, because the raw pilot tones themselves
carry ICI. That departure is the ICI error floor, not an estimator defect, and the
bound is retained as a reference rather than asserted as valid for the Doppler sweep.

### 5.3 ICI growth

![ICI Growth](results/figures/03_ici_growth_bandwidth.png)

Per-subcarrier interference power measured from the exact frequency-domain channel
matrix, across f_D·T_u = 0.005 to 0.20:

| f_D·T_u | ICI power | ICI-to-carrier ratio |
|---:|---:|---:|
| 0.005 | 7.58 × 10⁻⁵ | −40.9 dB |
| 0.05 | 7.11 × 10⁻³ | −21.1 dB |
| 0.10 | 2.70 × 10⁻² | −15.3 dB |
| 0.20 | 8.54 × 10⁻² | −10.2 dB |

Two small-Doppler asymptotes bracket the simulation:
P_ICI = (π²/3)·(E[ν²]/f_D²)·(f_D·T_u)², with E[ν²]/f_D² = 0.5 for classical Jakes and
1.0 for the worst case where all Doppler energy sits at ±f_D. The clustered generator
falls between them: the implied second-moment ratio over f_D·T_u ≤ 0.02 is **0.915**.
No claim is made that the simulation matches either asymptote exactly.

Leakage width grows faster than leakage power. The band capturing 99% of the channel
matrix energy widens from 0 to 6.6 subcarriers over the same range, but the 99.9% band
widens from 0.02 to 146 subcarriers, i.e. essentially the whole 256-point matrix. The
ICI tails are heavy, which is what limits banded receivers in Section 5.4.

### 5.4 CE-BEM order and receiver ladder

![BEM Order](results/figures/04_bem_order.png)

Complex-exponential basis expansion fit error against model order Q, averaged over 40
realizations. Frequency-domain matrix NMSE falls from 1.41 × 10⁻³ at Q = 0 to
1.41 × 10⁻⁴ at Q = 4 and 7.19 × 10⁻⁵ at Q = 8. Returns diminish past Q ≈ 4, which is
the order used by the BEM-MMSE receiver. Because the orders share each realization and
the bases are nested, the tap-domain error is monotone non-increasing in Q by
construction (check 36).

![Receiver Comparison](results/figures/05_receiver_ladder_high_doppler.png)

Eleven receiver configurations at f_D·T_u = 0.10 and 24 dB, 30,720 bits per point:

| Receiver | BER at 24 dB |
|---|---:|
| ZF | 1.299 × 10⁻² |
| PIC (4 iterations) | 3.125 × 10⁻² |
| BEM-MMSE (Q = 4) | 2.214 × 10⁻³ |
| Banded MMSE, B = 1 | 6.836 × 10⁻³ |
| Banded MMSE, B = 4 | 1.855 × 10⁻³ |
| Banded MMSE, B = 16 | 6.836 × 10⁻⁴ |
| PCG-MMSE (20 iterations) | 9.115 × 10⁻⁴ |
| Full MMSE | 2.604 × 10⁻⁴ |

Widening the banded receiver from B = 1 to B = 16 reduces BER by a factor of **10.0**
and beats ZF by 19×, confirming that the off-diagonal ICI structure carries usable
information.

Two honest caveats. The PIC implementation performs *worse* than plain ZF at this
operating point; the four-iteration parallel-interference-cancellation loop does not
converge under this much ICI and is reported as measured. And the full-MMSE point rests
on 8 bit errors out of 30,720, so its Monte-Carlo precision is roughly ±35%; treat the
gap between full MMSE, PCG-MMSE and B16 as unresolved rather than as a ranking.

### 5.5 Receiver cost

![Receiver Cost](results/figures/06_receiver_cost.png)

Analytical real-flop proxies for N = 256: full MMSE over the ICI matrix costs
1.79 × 10⁸ operations against 5.92 × 10⁵ for a B = 8 banded solve, a **302× reduction**,
with memory falling from 1.05 MB to 69.6 kB (**15×**).

Measured median runtime per call at f_D·T_u = 0.10: ZF 0.041 ms, PCG-MMSE 0.724 ms,
B8 3.67 ms, PIC 4.29 ms, full MMSE 4.52 ms. PCG-MMSE is roughly **6× faster than the
exact solve** at 3.5× its BER.

**PCG-MMSE does not converge to the requested tolerance.** At 20 iterations the
relative residual settles near 1.7 × 10⁻³ against a 1 × 10⁻⁶ target, and the converged
flag is false at every point. Early termination regularizes an ill-conditioned ICI
matrix, which is why the truncated solver can outperform an exact solve elsewhere in
the sweep. It must be described as a truncated CG solve of the MMSE normal equations,
never as solving the exact MMSE objective.

### 5.6 OTFS detectors on a synthetic channel

![OTFS Detectors](results/figures/07_otfs_detectors.png)

Four detectors on a **synthetic 32 × 32 delay-Doppler channel with two specified
paths**, swept over fractional Doppler offsets 0, 0.10, 0.25 and 0.40. At 12 dB with
integer Doppler: message passing 3.91 × 10⁻⁴, MMSE 3.68 × 10⁻³, matched filter
1.25 × 10⁻¹, Gauss-Seidel 2.95 × 10⁻¹.

This is a detector benchmark, not the physical comparison. The grid is a free parameter
here because path delays and Dopplers are specified directly, and the resulting operator
is sparse enough for message passing to be valid. As Section 3.5 records, the operator
in the real EVA cross-waveform experiment is not sparse, so this ~9× message-passing
advantage does not transfer to the headline result and was not used there.

### 5.7 OTFS embedded pilot

![OTFS Pilot](results/figures/09_otfs_pilot.png)

A single embedded delay-Doppler pilot with a 3σ_n detection threshold, fractional
Doppler refined by maximizing the matched-filter statistic over a local grid.

| E_b/N_0 | Path detection rate | False alarm rate | DD-operator NMSE |
|---:|---:|---:|---:|
| 0 dB | 6.3% | 0 | 1.096 |
| 6 dB | 50.0% | 0 | 0.636 |
| 12 dB | 100% | 0 | 3.52 × 10⁻² |
| 24 dB | 100% | 0 | 2.62 × 10⁻³ |
| 30 dB | 100% | 0 | 4.84 × 10⁻⁴ |

NMSE is the Frobenius error of the delay-Doppler operator *rebuilt from the estimated
paths* against the true operator, not a noisy-versus-noiseless frame comparison.
Detection requires agreement in both delay and Doppler within half a Doppler bin. The
estimator uses no true path parameter at any stage.

The cost is overhead: the guard region occupies **67.7% of the frame** in this
configuration. That is acceptable for a diagnostic but is not a practical pilot design,
and no spectral-efficiency claim is made from it.

### 5.8 Impairment sensitivity

![Impairments](results/figures/10_impairments.png)

Controlled sweeps at 20 dB with perfect CSI on a block-static EVA channel, 102,400 bits
per point. Each impairment is isolated from channel-estimation error.

**Cyclic prefix.** The resolved channel span is 14 taps, i.e. 13 samples of memory. BER
is 5.21 × 10⁻³ with no CP and flattens at roughly 2.5 × 10⁻³ once the CP reaches 8
samples. The nominal 32-sample CP is comfortably sufficient. The CP-stress sweep
transmits the previous block as well, so insufficient CP produces genuine inter-block
interference.

**Phase noise.** A Wiener phase process with per-sample increment σ_φ. BER is
2.59 × 10⁻³ at σ_φ = 0, essentially unchanged at 0.001 and 0.003, rises to 2.88 × 10⁻³
at 0.01, then to 2.39 × 10⁻² at 0.03 (9.2×) and 3.06 × 10⁻¹ at 0.1 (118×). The onset is
sharp rather than gradual.

**Impulsive noise.** With impulse power 100× the background, BER rises from
2.50 × 10⁻³ at zero impulse probability to 4.71 × 10⁻³ at p = 0.01 and 1.02 × 10⁻² at
p = 0.03, a 4.1× degradation.

These are sensitivity experiments at one SNR and one channel model. They are not
robustness bounds.

### 5.9 Physical channel diagnostics

![Physical Channel Diagnostics](results/figures/11_physical_channel_diagnostics.png)

Two channel models are kept strictly separate.

The clustered EVA model is the physical channel used everywhere in the project. The
figure shows its power-delay profile and a one-second fading-envelope record at the
nominal 267 Hz Doppler.

A classical Clarke/Jakes process is generated **separately**, purely to validate the
generator. Its empirical autocorrelation matches the theoretical R(τ) = J₀(2π f_D τ)
with a normalized RMSE of **0.0232**, and 98.8% of its spectral energy falls inside the
±f_D support.

This validates the Jakes reference generator. It does not make the clustered EVA
channel an ideal Jakes process, and no such equivalence is claimed anywhere.

### 5.10 Covariance mismatch

![Covariance Mismatch](results/figures/12_covariance_mismatch.png)

Analytical expected MSE of a Wiener estimator built on a wrong channel-covariance
prior, evaluated against the true Gaussian channel. Penalty over the matched prior:

| Prior used | at 20 dB | at 30 dB |
|---|---:|---:|
| Wrong power weighting, correct delays | 0.01 dB | 0.03 dB |
| Delay spread under-estimated (×0.4) | 19.6 dB | 29.5 dB |
| Delay spread over-estimated (×2.5) | 17.2 dB | 27.0 dB |
| EPA prior used on an EVA channel | 25.4 dB | 34.7 dB |

The result is directional and useful: getting the *power weighting* wrong is nearly
free, because the prior still spans the correct delay subspace. Getting the *delay
spread* wrong moves the subspace itself and is expensive, and the penalty grows with
SNR because the estimator leans harder on a prior that is wrong.

### 5.11 MIMO with aged CSI

![MIMO](results/figures/13_mimo_ofdm.png)

2 × 2 MIMO-OFDM over the clustered EVA channel with separable Tx/Rx exponential spatial
correlation (ρ = 0.70 each side), noisy Zadoff-Chu training, and CSI aged by one OFDM
symbol relative to the data.

| E_b/N_0 | ZF (aged) | MMSE (aged) | MMSE (perfect CSI) | Aged/perfect BER ratio |
|---:|---:|---:|---:|---:|
| 0 dB | 3.060 × 10⁻¹ | 2.285 × 10⁻¹ | 1.496 × 10⁻¹ | 1.5× |
| 8 dB | 1.441 × 10⁻¹ | 9.722 × 10⁻² | 5.244 × 10⁻² | 1.9× |
| 16 dB | 5.215 × 10⁻² | 3.682 × 10⁻² | 1.079 × 10⁻² | 3.4× |
| 24 dB | 2.891 × 10⁻² | 2.476 × 10⁻² | 2.336 × 10⁻³ | **10.6×** |

Ordering: perfect-CSI MMSE < aged-CSI MMSE < ZF, at every SNR.

**A note on units.** The stored field `csiAgingPenaltyDb` is 10·log₁₀ of the *BER
ratio*, reaching 10.24 dB at 24 dB. It is not an SNR penalty in dB. State the result as
a 10.6× BER increase, or describe the dB figure explicitly as a log BER ratio. The
perfect-CSI reference uses the same received samples and the same noise realization, so
the comparison isolates CSI aging rather than confounding it with noise.

### 5.12 Other studies

**Pilot spacing.** Channel MSE at 15 dB against comb spacing 2, 4, 8 and 16. LMMSE MSE
is 1.44 × 10⁻³, 1.27 × 10⁻³, 2.67 × 10⁻³ and 1.57 × 10⁻². The frequency-domain sampling
bound 1/(2·τ_max·Δf) evaluates to 13.3 subcarriers, so spacing 16 violates it, and the
order-of-magnitude MSE jump at that spacing is the expected aliasing. Spacing 4 is the
working point used elsewhere.

**PAPR and spectral efficiency.** 99th-percentile PAPR across N = 64 to 512 for QPSK
and 16-QAM, ranging 8.8 to 10.5 dB, with CP-adjusted spectral efficiency.

**MIMO resource allocation.** Water-filling against uniform power over eight fixed
modes, plus a robust variant with 15% gain uncertainty and a finite-alphabet ceiling.
Water-filling capacity is verified never to fall below uniform allocation (check 8).
This is a Gaussian-input Shannon benchmark with perfect CSI, not a link result.

**Reference validation.** The hand-written Gray QAM mapper is checked against the
Communications Toolbox: constellation point-set error 1.1 × 10⁻¹⁶, unit-power error
2.2 × 10⁻¹⁶, round-trip bit errors 0. The bit-to-symbol labelling differs from the
toolbox convention, which is a labelling choice and does not affect BER because the
mapper and demapper are mutually inverse.

---

## 6. Validation

Two independent gates run after every simulation, and results are marked uncertified if
either fails.

**Scientific gate.** Checks physical consistency of the result structures.

**Numerical identity gate.** 46 checks covering transform identities, operator
consistency, statistical bounds, and experimental design. The final run passes 46/46:

```text
[PASS] Scientific validation gate passed basic checks.
[PASS] Numerical identity gate: 46/46 checks passed.
[PASS] Result passed both the scientific and the numerical gate.
```

Representative checks:

| # | Check | Result |
|---:|---|---|
| 1 | OTFS TX/RX identity | relative error < 1e-10 |
| 2 | OTFS useful transform is energy preserving | CP correctly excluded |
| 3 | DD operator matches the channel it generated | relative error < 1e-10 |
| 5 | Frequency-domain noise inflation equals N | measured 256.0 vs N = 256 |
| 12 | Bayesian CRLB not violated beyond Monte-Carlo slack | lowest ratio 0.990 |
| 15 | ICI lies between the Jakes and worst-case asymptotes | implied ratio 0.915 |
| 20 | Cross-waveform receiver is matched | same detector family and settings |
| 24 | Information-symbol budget matches | OFDM 256 × 16 = OTFS 32 × 128 |
| 25 | Waveform duration matches | 4608 samples vs 4608 samples |
| 30 | Wiener attains its CRLB under the diagonal model | worst ratio 1.104 |
| 31 | Diagonal-model MSE does not undercut its bound | lowest ratio 0.947 |
| 44 | Generated Jakes ACF matches Clarke-Jakes | normalized RMSE 0.0232 |

A separate fast smoke test (`main('CHECKS')`) covers the modem, delay resolution,
covariance basis, noise-domain convention, comb-pilot LMMSE against the Bayesian CRLB,
constant-modulus training, the OTFS waveform and DD operator, an AWGN regression against
QPSK theory, message passing on a noiseless single-path channel, and the complexity
hierarchy.

---

## 7. Known limitations

Recorded here rather than buried, because they bound how the results should be read.

1. **Perfect CSI throughout the headline comparison.** The cross-waveform result assumes
   the receiver knows the channel exactly. Realistic estimation would narrow the gap by
   an amount this project does not measure.
2. **Uncoded QPSK.** No forward error correction anywhere. Coded performance can reorder
   waveforms.
3. **The vector Kalman entry in the ICI-free reference column is not meaningful.** That
   reference channel is generated with f_D = 0 while the state transition still uses
   α = J₀(2π f_D T_sym) from the configured Doppler, so the recursion is model-mismatched
   by construction and its MSE diverges with SNR. Only its production-sweep column should
   be read.
4. **PCG-MMSE does not reach its stated tolerance** (Section 5.5). It is a truncated solve.
5. **The delay-Doppler operator is not sparse in the physical experiment** (Section 3.5),
   so sparse-graph detection was disabled and the OTFS result is a linear-detector result.
6. **Small error counts at high SNR.** Several receiver-ladder points rest on fewer than
   30 bit errors. Differences below the stated resolution floors are not resolved.
7. **f_D·T_u = 0.10 and 0.20 exceed terrestrial vehicular Doppler** at 2.4 GHz. They are a
   stress range.
8. **The upper Doppler points are sub-bin for OTFS at f_D·T_u = 0.01,** where Doppler is
   0.18 of a bin. Doppler resolution varies across the sweep and is not held constant.

---

## 8. Running the project

MATLAB is required. Set the current folder to the project directory.

```matlab
main('CHECKS')              % fast configuration and implementation checks
main('SMOKE','wide')        % timing calibration, estimates full runtime
main('AUDIT','wide','RESTART')   % full run, all 16 studies, from scratch
main('AUDIT','wide')             % resume from the last checkpoint
main('PLOTS','wide')             % regenerate figures from saved results
```

A narrow-mode delay-resolution warning during `CHECKS` is expected: that quick path uses
a smaller FFT and lower sampling rate that does not resolve the EVA profile.

The full AUDIT takes roughly 1.5 hours. The OTFS detector study (~60 min) and the
cross-waveform comparison (~20 min) dominate. Each study checkpoints atomically on
completion, so an interrupted run resumes without repeating finished work.

Modes trade runtime against confidence: `SMOKE` and `FAST` for development, `AUDIT` for
the reported results, `FULL` and `MASSIVE` for higher bit counts.

---

## 9. Repository structure

```text
OFDM_OTFS/
│
├── main.m                       entry point: checks, timing, runs, plots
├── timing_probe.m               two-point runtime calibration
├── plot_results.m               figure generation from saved results
│
├── experiments/
│   └── research_suite.m         all 16 studies, checkpointing, statistics
│
├── src/
│   ├── core/physical_core.m     config, channel model, OFDM modem, Monte Carlo
│   ├── otfs/otfs_core.m         ISFFT/SFFT, DD operator, detectors, pilot study
│   ├── receivers/estimation_receiver.m   estimators, equalizers, ICI model
│   └── mimo/mimo_resource_allocation.m   water-filling and capacity
│
├── validation/
│   ├── quick_smoke_test.m       fast correctness assertions
│   └── analysis_tools.m         complexity model, reference checks, 46-check gate
│
└── results/
    ├── audit_wide_results.mat            all numerical results
    ├── validation.mat                    both validation gate outputs
    ├── claim_crosswaveform_metrics.csv   per-point BER, CIs, McNemar
    ├── claimability_summary.txt          scope statement for the primary endpoint
    ├── checkpoints/                      resumable run state
    └── figures/                          the 13 project figures
```
