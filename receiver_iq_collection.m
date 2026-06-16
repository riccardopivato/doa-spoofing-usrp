%% ================== RECEIVER — USRP X310 with IQ Recording ==================
% Two-channel DOA receiver with on-demand IQ data collection.
% Uses save_trigger.m (run from a second MATLAB window) to start recording.
%
% PROCEDURE:
%   1. Start transmitter.m on the TX laptop
%   2. Position TX at 0 degrees (broadside) relative to the antenna array
%   3. Run this script — phase calibration starts automatically (1 second)
%   4. After "Calibration complete", move TX to the desired angle
%   5. From a second MATLAB window, run: save_trigger(30)  % e.g., 30 degrees
%   6. Recording starts automatically for framesPerAngle frames
%   7. Repeat step 4-5 for additional angles, or save_trigger('q') to quit

%% Radio parameters
radioAddress    = '192.168.10.2';
centerFrequency = 2.4e9;
gain            = 30;

radio = comm.SDRuReceiver( ...
    'Platform',          'X310', ...
    'IPAddress',         radioAddress, ...
    'CenterFrequency',   centerFrequency, ...
    'Gain',              gain, ...
    'MasterClockRate',   200e6, ...
    'DecimationFactor',  500, ...
    'SamplesPerFrame',   4096, ...
    'ChannelMapping',    [1 2], ...
    'OutputDataType',    'double');

radio.ReceiveAntennaPort = 'RX2';

%% Recording parameters
saveDir        = './iq_recordings';
framesPerAngle = 100;
flagFile       = './save_cmd.txt';

if ~exist(saveDir, 'dir'), mkdir(saveDir); end
if exist(flagFile, 'file'), delete(flagFile); end

%% Signal parameters
ToneFrequency  = 100e3;
timeCounter    = 0;
radioFrameTime = radio.SamplesPerFrame * radio.DecimationFactor / radio.MasterClockRate;
sampleRate     = radio.MasterClockRate / radio.DecimationFactor;

%% Visualization
spectrumScope = spectrumAnalyzer('SampleRate', sampleRate);
timeScope     = timescope( ...
    'TimeSpan',   4/ToneFrequency, ...
    'SampleRate', sampleRate);

figure;
p = polarplot(0, 1, 'o', 'LineWidth', 2);
rlim([0 1]);
title('Direction of Arrival');

%% Array and MUSIC estimator
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

%% Phase calibration
% TX must be at broadside (0 degrees) during calibration
disp('Phase calibration in progress — keep TX at 0 degrees...');

CalibrationTime  = 1;
numCalFrames     = floor(CalibrationTime / radioFrameTime);
phiCal           = 0;

for k = 1:numCalFrames
    [data, valid] = radio();
    if valid
        phiCal = phiCal + angle(mean(conj(data(:,1)) .* data(:,2)));
    end
end
phiCal = phiCal / numCalFrames;

fprintf('Calibration complete. phiCal = %.2f deg\n', rad2deg(phiCal));
disp('Move TX to desired angle. Use save_trigger(angle_deg) to start recording.');

%% Main loop
StopTime   = 10000;
isSaving   = false;
iqBuffer   = [];
frameCount = 0;
savedAngle = 0;

try
    while timeCounter < StopTime

        % Check flag file for recording trigger
        if ~isSaving && exist(flagFile, 'file')
            raw = strtrim(fileread(flagFile));
            delete(flagFile);
            if strcmpi(raw, 'q')
                disp('Exit command received.');
                break;
            end
            val = str2double(raw);
            if ~isnan(val)
                savedAngle = val;
                isSaving   = true;
                iqBuffer   = [];
                frameCount = 0;
                fprintf('\n>>> Recording started — angle: %+.1f deg — %d frames\n', ...
                    savedAngle, framesPerAngle);
            end
        end

        % Acquire frame
        [data, valid, overrun] = radio();

        if valid && ~overrun

            % Normalize amplitude
            iq_raw    = data ./ max(abs(data(:)));

            % Apply phase calibration
            data      = iq_raw;
            data(:,2) = data(:,2) * exp(-1j * phiCal);

            % Accumulate IQ buffer if recording
            if isSaving
                iqBuffer   = [iqBuffer; data];
                frameCount = frameCount + 1;
                fprintf('  [rec] frame %d/%d\n', frameCount, framesPerAngle);

                if frameCount >= framesPerAngle
                    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
                    fname     = fullfile(saveDir, ...
                        sprintf('iq_angle%+.0fdeg_%s.mat', savedAngle, timestamp));
                    iq_data   = iqBuffer;
                    fc        = centerFrequency;
                    fs        = sampleRate;
                    phi_cal   = phiCal;
                    angle_deg = savedAngle;
                    save(fname, 'iq_data', 'fc', 'fs', 'phi_cal', 'angle_deg');
                    fprintf('>>> Saved: %s (%d samples)\n', fname, size(iqBuffer,1));
                    isSaving   = false;
                    iqBuffer   = [];
                    frameCount = 0;
                    disp('>>> Waiting for next trigger (save_trigger.m)...');
                end
            end

            % DOA estimation and diagnostics
            [~, doas] = estimator(data);
            fase_grezza   = rad2deg(angle(mean(conj(iq_raw(:,1)) .* iq_raw(:,2))));
            fase_corretta = rad2deg(angle(mean(conj(data(:,1))   .* data(:,2))));

            if ~isSaving
                fprintf('raw_phase=%+7.2f deg | corr_phase=%+7.2f deg | DOA=%+6.2f deg\n', ...
                    fase_grezza, fase_corretta, doas);
            end

            if isscalar(doas)
                p.ThetaData = deg2rad(doas);
                p.RData     = 1;
                drawnow limitrate;
            end

            timeScope(data);
            dataMaxLimit = max(max(abs([real(data); imag(data)])));
            timeScope.YLimits = [-1.5*dataMaxLimit, 1.5*dataMaxLimit];
            spectrumScope(data);

            timeCounter = timeCounter + radioFrameTime;
        end
    end

catch ME
    release(radio);
    release(timeScope);
    release(spectrumScope);
    rethrow(ME);
end

%% Cleanup
release(radio);
release(timeScope);
release(estimator);
release(spectrumScope);
