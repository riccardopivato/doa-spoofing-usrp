%% ================== DOA SPOOFING — POST-PROCESSING ==================
% Applies the DOA spoofing transformation (Xu et al., 2025, Eq. 11)
% to recorded IQ samples and verifies that MUSIC estimates the desired
% ghost angle instead of the real transmitter angle.
%
% REFERENCE:
%   Xu et al., "Ghost of the Navigator: Spoofing Attack Against
%   Direction-of-Arrival Estimation", IEEE IoT Journal, Dec. 2025.
%   DOI: 10.1109/JIOT.2025.3608829
%
% USAGE:
%   Set file_iq and phi_ghost below, then run the script.
%   Output: MUSIC spectra (baseline vs post-spoofing) + ghost angle sweep.

clear; clc;

%% ================== PARAMETERS ==================
file_iq    = 'iq_plus40deg_take3.mat';
phi_ghost  = +50;      % desired ghost angle (degrees)
N_snapshot = 4096;    % number of IQ samples used for each MUSIC estimate

%% ================== LOAD DATA ==================
fprintf('Loading %s...\n', file_iq);
d = load(file_iq);

iq_data         = d.iq_data;
phiCal          = d.phi_cal;
centerFrequency = d.fc;
sampleRate      = d.fs;

fprintf('Total samples: %d x %d channels\n', size(iq_data,1), size(iq_data,2));
fprintf('phiCal: %.2f deg\n', rad2deg(phiCal));

%% ================== PREPROCESSING ==================
Y_full = iq_data;

% Select N_snapshot samples from the central portion of the recording
n_total    = size(Y_full, 1);
idx_start  = floor(n_total/4);
idx_end    = min(idx_start + N_snapshot - 1, n_total);
Y          = Y_full(idx_start:idx_end, :);

fprintf('Snapshots used: %d (samples %d:%d)\n', size(Y,1), idx_start, idx_end);

%% ================== ARRAY AND MUSIC ESTIMATOR ==================
lambda = physconst('LightSpeed') / centerFrequency;

array = phased.ULA( ...
    'NumElements',    2, ...
    'ElementSpacing', lambda/2);

estimator = phased.MUSICEstimator( ...
    'SensorArray',              array, ...
    'OperatingFrequency',       centerFrequency, ...
    'ForwardBackwardAveraging', false, ...
    'DOAOutputPort',            true, ...
    'NumSignalsSource',         'Property', ...
    'NumSignals',               1, ...
    'ScanAngles',               -90:0.5:90);

%% ================== BASELINE DOA ESTIMATE ==================
disp('--- Baseline DOA estimate (no spoofing) ---');
[spectrum_baseline, doa_baseline] = estimator(Y);
fprintf('Estimated DOA: %+.2f deg\n', doa_baseline);

% Use the MUSIC-estimated angle as theta_real (accounts for calibration offset)
theta_real = doa_baseline;

%% ================== SPOOFING TRANSFORMATION ==================
fprintf('\n--- Spoofing towards phi_ghost = %+.0f deg ---\n', phi_ghost);

% Steering vectors (Eq. 1 of Xu et al.)
% a(xi) = [1, exp(j*pi*sin(xi))]^T  for spacing lambda/2
a_theta = [1; exp(1j * pi * sind(theta_real))];   % real angle
a_phi   = [1; exp(1j * pi * sind(phi_ghost))];    % ghost angle

% Step 1: extract source signal by projecting Y onto a(theta) (Eq. 11, left side)
s_hat = Y * conj(a_theta) / (a_theta' * a_theta);   % N_snapshot x 1

% Step 2: reconstruct ghost observation with a(phi) (Eq. 11, right side)
Y_prime = s_hat * a_phi.';                           % N_snapshot x 2

% Estimate DOA on the spoofed signal
[spectrum_spoof, doa_spoof] = estimator(Y_prime);

fprintf('Estimated DOA after spoofing: %+.2f deg (target: %+.0f deg)\n', doa_spoof, phi_ghost);
error_deg = doa_spoof - phi_ghost;
fprintf('Error: %+.2f deg\n', error_deg);

if abs(error_deg) < 1
    fprintf('>>> SPOOFING SUCCESSFUL\n');
end

%% ================== PLOT: BASELINE vs POST-SPOOFING ==================
scan_angles = -90:0.5:90;

figure('Name', 'DOA Spoofing — MUSIC Spectra', 'Position', [100 100 1000 450]);

subplot(1,2,1);
plot(scan_angles, 10*log10(spectrum_baseline / max(spectrum_baseline)), 'b', 'LineWidth', 1.5);
hold on;
xline(theta_real, 'r--', sprintf('DOA = %+.1f°', theta_real), 'LineWidth', 1.5, ...
    'LabelVerticalAlignment', 'bottom');
xlabel('Angle (degrees)');
ylabel('Normalized spectrum (dB)');
title('BASELINE — original signal');
grid on; xlim([-90 90]); ylim([-40 5]);

subplot(1,2,2);
plot(scan_angles, 10*log10(spectrum_spoof / max(spectrum_spoof)), 'b', 'LineWidth', 1.5);
hold on;
xline(phi_ghost,  'r--', sprintf('Ghost target = %+.0f°', phi_ghost), 'LineWidth', 1.5, ...
    'LabelVerticalAlignment', 'bottom');
xline(doa_spoof,  'g:',  sprintf('Estimated DOA = %+.1f°', doa_spoof), 'LineWidth', 1.5);
xline(theta_real, 'k:',  sprintf('Real angle = %+.1f°', theta_real), 'LineWidth', 1);
xlabel('Angle (degrees)');
ylabel('Normalized spectrum (dB)');
title(sprintf('POST-SPOOFING — ghost at %+.0f°', phi_ghost));
grid on; xlim([-90 90]); ylim([-40 5]);

sgtitle(sprintf('DOA Spoofing: %+.1f° \\rightarrow %+.0f° | Error = %+.2f°', ...
    theta_real, phi_ghost, error_deg));

%% ================== GHOST ANGLE SWEEP ==================
disp('--- Ghost angle sweep ---');
phi_sweep = -60:5:60;
doa_sweep = zeros(size(phi_sweep));
errors    = zeros(size(phi_sweep));

for i = 1:length(phi_sweep)
    phi_i   = phi_sweep(i);
    a_phi_i = [1; exp(1j * pi * sind(phi_i))];

    s_hat_i    = Y * conj(a_theta) / (a_theta' * a_theta);
    Y_prime_i  = s_hat_i * a_phi_i.';

    [~, doa_i]   = estimator(Y_prime_i);
    doa_sweep(i) = doa_i;
    errors(i)    = abs(doa_i - phi_i);
end

success_rate = mean(errors < 1) * 100;
fprintf('Success rate (error < 1 deg): %.1f%% over %d angles\n', ...
    success_rate, length(phi_sweep));

figure('Name', 'Ghost Angle Sweep', 'Position', [100 100 560 480]);

plot(phi_sweep, doa_sweep, 'b.-', 'LineWidth', 1.5, 'MarkerSize', 14);
hold on;
plot(phi_sweep, phi_sweep, 'r--', 'LineWidth', 1);
xlabel('Ghost target \phi (degrees)');
ylabel('Estimated DOA (degrees)');
title(sprintf('Spoofing sweep — \\theta_{real} = %+.1f° | N_{snapshot} = %d', ...
    theta_real, N_snapshot));
legend('Estimated', 'Ideal (y=x)', 'Location', 'best');
grid on;

exportgraphics(gcf, '../figures/fig_ghost_sweep.png', 'Resolution', 300);
fprintf('Saved ../figures/fig_ghost_sweep.png\n');

fprintf('\nDone.\n');
