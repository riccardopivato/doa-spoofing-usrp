# DOA Spoofing — Hardware Validation on USRP SDR

MATLAB implementation of a post-processing DOA spoofing attack validated on real RF measurements collected with USRP software-defined radios.

This work is a hardware validation of the attack proposed by Xu et al. (2025). Due to the constraint of a single transmit antenna (M=1), the spoofing transformation is applied in post-processing on recorded IQ samples rather than over the air.

## Hardware

| Device | Role |
|---|---|
| USRP X310 + 2× UBX daughterboards | Receiver (2-element ULA) |
| USRP B200 | Transmitter (single antenna) |

Carrier frequency: 2.4 GHz — Tone offset: 100 kHz — RX sample rate: 400 kHz

## Files

| File | Description |
|---|---|
| `transmitter.m` | Tone transmitter for USRP B200 (run on TX laptop) |
| `receiver_iq_collection.m` | Two-channel IQ receiver with on-demand data recording (run on RX laptop) |
| `save_trigger.m` | Helper function to trigger IQ recording from a second MATLAB window |
| `doa_spoofing_postprocessing.m` | Post-processing spoofing transformation (Eq. 11 of Xu et al.) applied to recorded IQ data |
| `DOA_Spoofing_Hardware_Validation.pdf` | Full project report (PDF) |

## Usage

**Data collection:**
1. Run `transmitter.m` on the TX laptop
2. Run `receiver_iq_collection.m` on the RX laptop (keep TX at broadside during the 1-second calibration)
3. Move TX to desired angle, then trigger recording from a second window: `save_trigger(30)`
4. IQ data is saved as `.mat` files in `./iq_recordings/`

**Post-processing spoofing:**
1. Open `doa_spoofing_postprocessing.m`
2. Set `file_iq` to your recorded `.mat` file and `phi_ghost` to the desired ghost angle
3. Run the script — outputs MUSIC spectra (baseline vs post-spoofing) and a full ghost angle sweep

The script runs out of the box on the provided dataset (`file_iq = 'iq_plus40deg_take3.mat'`,
`phi_ghost = +50`).

## Dataset

`iq_plus40deg_take3.mat` is included for reproduction. It is a ~1-second recording
(409,600 samples, two channels) with the transmitter placed by hand at an approximate
azimuth of +40°; the MUSIC estimator reads it as a clean peak at about -40°.

Each `.mat` file contains `iq_data`, `fc`, `fs`, `phi_cal`, `angle_deg`. The IQ data is
stored **already phase-calibrated**: `receiver_iq_collection.m` estimates the inter-channel
phase offset against a broadside reference during the 1-second calibration window and applies
it before saving. The post-processing script therefore does **not** re-apply calibration.

Two practical notes on the hardware measurements:
- Transmitter positions were set manually and are approximate; the meaningful quantity is the
  **MUSIC-estimated DOA**, which is used as the ground-truth angle `theta` for the spoofing
  transformation.
- Wide-angle estimates show a consistent **left–right sign inversion** (e.g. a transmitter at
  about +40° is estimated near -40°), attributed to the physical ordering of the two
  antennas relative to the assumed ULA geometry. This does not affect the spoofing result,
  which only relies on the estimated angle.

## Method

The spoofing transformation follows Eq. (11) of Xu et al., simplified for M=1, N=2, L=1:

```
s_hat   = Y * conj(a_theta) / norm(a_theta)^2   % extract source signal
Y_prime = s_hat * a_phi'                          % reconstruct at ghost angle
```

where `a_theta` and `a_phi` are the ULA steering vectors for the real and ghost angles respectively, and `Y` is the recorded IQ matrix (N_samples × 2).

## Results

The MUSIC estimator is successfully redirected to any desired ghost angle in [-60°, +60°] with 100% success rate (error < 1°) across all tested configurations on real hardware.

## Report

The full project report, describing the methodology, the hardware setup, and the measured
results, is available as [`DOA_Spoofing_Hardware_Validation.pdf`](DOA_Spoofing_Hardware_Validation.pdf).

## Reference

S. Xu, A. Brighente, B. Chen, M. Conti, and S. Peng,
"Ghost of the Navigator: Spoofing Attack Against Direction-of-Arrival Estimation,"
*IEEE Internet of Things Journal*, vol. 12, no. 23, pp. 49932–49941, Dec. 2025.
DOI: [10.1109/JIOT.2025.3608829](https://doi.org/10.1109/JIOT.2025.3608829)

## Authors

Gioia Anello, Riccardo Pivato, Thomas Rigoni — University of Padua, MSc CyberSecurity
Course: Computer and Networks Security: Advanced Topics — A.Y. 2024-2025
Supervisor: Prof. Alessandro Brighente
