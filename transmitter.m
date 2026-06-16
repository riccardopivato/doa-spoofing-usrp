%% ================== TRANSMITTER — USRP B200 ==================
% Transmits a continuous complex tone at 100 kHz offset on 2.4 GHz.
% Run this script on the TX laptop BEFORE starting the receiver.

%% Radio parameters
centerFrequency  = 2.4e9;
gain             = 50;
ToneFrequency    = 100e3;

%% Sample rate
MasterClockRate  = 20e6;   % B200 default
InterpolFactor   = 20;
sampleRate       = MasterClockRate / InterpolFactor;   % 1 MHz
SamplesPerFrame  = 4e4;

%% Generate complex tone
t    = (0:SamplesPerFrame-1).' / sampleRate;
tone = exp(1j * 2 * pi * ToneFrequency * t);

%% Radio object
radio = comm.SDRuTransmitter( ...
    'Platform',            'B200', ...
    'CenterFrequency',     centerFrequency, ...
    'Gain',                gain, ...
    'MasterClockRate',     MasterClockRate, ...
    'InterpolationFactor', InterpolFactor);

%% Transmission loop
disp('Transmitter started. Press Ctrl+C to stop.');
try
    while true
        radio(tone);
    end
catch ME
    release(radio);
    if ~strcmp(ME.identifier, 'MATLAB:interrupt')
        rethrow(ME);
    end
end

release(radio);
disp('Transmitter stopped.');
