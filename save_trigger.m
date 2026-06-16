function save_trigger(angle_deg)
% SAVE_TRIGGER  Send a recording command to receiver_iq_collection.m
%
%   save_trigger(30)    Start recording, label data as 30 degrees
%   save_trigger('q')   Stop the receiver main loop
%
% Run this function from a second MATLAB window while
% receiver_iq_collection.m is running in the first window.

    flagFile = './save_cmd.txt';

    if nargin == 0
        disp('Usage: save_trigger(30)  or  save_trigger(''q'')');
        return;
    end

    if ischar(angle_deg) && strcmpi(angle_deg, 'q')
        fid = fopen(flagFile, 'w');
        fprintf(fid, 'q');
        fclose(fid);
        disp('Exit command sent.');
    else
        fid = fopen(flagFile, 'w');
        fprintf(fid, '%.4f', angle_deg);
        fclose(fid);
        fprintf('Recording trigger sent: angle = %+.1f deg\n', angle_deg);
    end
end
