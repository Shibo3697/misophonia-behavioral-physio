clc;
clear;
close all;

%% ---------------------- User settings ---------------------- %%
% Root folder of raw Misophonia data (wings + tri)
rawRootDir = 'C:\Users\admin\Desktop\misophonia data\data_raw';

% Root folder where all Ledalab-ready PPG .mat files will be saved
ppgOutputRoot = 'D:\OneDrive - Wichita State University\Project_Misophonia\misophonia data\data_PPG';

% Create output root folder if it does not exist
if ~exist(ppgOutputRoot, 'dir')
    mkdir(ppgOutputRoot);
end

% Map trigger codes to condition names
triggerCodeMap = containers.Map( ...
    {2,          4,          8}, ...
    {'unpleasant','neutral', 'trigger'} ...
);

% Sampling rate of tri triggers (Hz)
t1 = datetime('14:46:49.170007', 'InputFormat', 'HH:mm:ss.SSSSSS');
t2 = datetime('14:56:30.294098', 'InputFormat', 'HH:mm:ss.SSSSSS');
dt_tri = t2 - t1;
totalSeconds = seconds(dt_tri);
sample = 5487 - 420;
fq_tri = sample / totalSeconds;

%% ---------------------- Find sessions ---------------------- %%
% Sessions look like: "2025-10-03 CS03"
sessionInfo = dir(fullfile(rawRootDir, '2025-*'));
sessionInfo = sessionInfo([sessionInfo.isdir]);  % keep only folders


%% ---------------------- Loop over sessions ---------------------- %%
for s = 1:numel(sessionInfo)
    sessionName = sessionInfo(s).name;
    sessionPath = fullfile(rawRootDir, sessionName);

    fprintf('\n===== Session: %s =====\n', sessionName);

    % Each run folder looks like: "2025-10-03_001"
    runInfo = dir(fullfile(sessionPath, '2025-*_*'));
    runInfo = runInfo([runInfo.isdir]);

    %% ---------------------- Loop over runs ---------------------- %%
    for r = 1:numel(runInfo)
        runName = runInfo(r).name;
        runPath = fullfile(sessionPath, runName);

        fprintf('  --- Run: %s ---\n', runName);

        % File paths for this run
        zipFilePath = fullfile(runPath, [runName '.zip']);
        triFilePath = fullfile(runPath, [runName '.tri']);

        % Check presence of zip and tri files
        if ~exist(zipFilePath, 'file')
            fprintf('    [Skip] Zip file not found: %s\n', zipFilePath);
            continue;
        end
        

        %% ---------- Unzip WINGS file to a temporary folder ---------- %%
        tempUnzipDir = fullfile(runPath, '_temp_unzip');

        % Clean previous temp folder if it exists
        if exist(tempUnzipDir, 'dir')
            rmdir(tempUnzipDir, 's');
        end
        mkdir(tempUnzipDir);

        % Unzip the current run zip
        unzip(zipFilePath, tempUnzipDir);

        % Expect a file named "<runName>.wings" inside the zip
        wingsFilePath = fullfile(tempUnzipDir, [runName '.wings']);
        if ~exist(wingsFilePath, 'file')
            % Fallback: search any .wings at the first level inside tempUnzipDir
            wingsList = dir(fullfile(tempUnzipDir, '*.wings'));
            if ~isempty(wingsList)
                wingsFilePath = fullfile(wingsList(1).folder, wingsList(1).name);
            e lse
                fprintf('    [Skip] No .wings file found after unzip.\n');
                rmdir(tempUnzipDir, 's');
                continue;
            end
        end

        %% ---------------------- Load WINGS (PPG) ---------------------- %%
        % Read WINGS as a table and keep time + PPG columns
        wingsTable = readtable(wingsFilePath, ...
            'FileType', 'text', ...
            'Delimiter', ';');

        % Ensure we only keep the needed columns
        wingsTable = wingsTable(:, {'SecondsSinceRunStart', 'PPG'});

        % Compute sampling interval dt based on first two samples
        dt = wingsTable.SecondsSinceRunStart(2) - wingsTable.SecondsSinceRunStart(1);

        % Number of zeros needed to pad from time 0 to first real sample
        nPadSamples = round(wingsTable.SecondsSinceRunStart(1) / dt);
        fprintf('dt = %.6f s, padding samples = %d\n', dt, nPadSamples);

        % Create padding table starting from t=0
        padTable = table();
        padTable.SecondsSinceRunStart = (0:dt:(nPadSamples - 1) * dt)';
        padTable.PPG = zeros(nPadSamples, 1);

        % Concatenate padding + real data
        wingsTable = [padTable; wingsTable];

        %% ------------------ Build Ledalab data struct ------------------ %%
        data = struct();
        data.time        = wingsTable.SecondsSinceRunStart;   % time vector in seconds
        data.ppg = wingsTable.PPG;                    % PPG signal
        data.timeoff     = 15;                                % constant offset (your setting)

        %% ---------------------- Load TRI triggers ---------------------- %%
        triTable = readtable(triFilePath, ...
            'FileType', 'text', ...
            'Delimiter', ';', ...
            'ReadVariableNames', false);

        % Var2: sample index of trigger, Var5: trigger code
        triggerSampleIndex = triTable.Var2;
        triggerCode        = triTable.Var5;

        % Convert trigger sample indices to seconds (tri time base)
        eventTimeSec = triggerSampleIndex / fq_tri;

        %% ------------------- Build data.event array ------------------- %%
        nEvents = numel(eventTimeSec);
        data.event = repmat( ...
            struct('time', [], 'nid', [], 'name', '', 'userdata', []), ...
            nEvents, 1);

        for e = 1:nEvents
            thisCode = triggerCode(e);
            thisName = 'unknown';

            if isKey(triggerCodeMap, thisCode)
                thisName = triggerCodeMap(thisCode);
            end

            data.event(e).time     = eventTimeSec(e);  % event onset (sec)
            data.event(e).nid      = double(thisCode); % numeric ID
            data.event(e).name     = thisName;         % condition label
            data.event(e).userdata = [];               % empty for now
        end

        %% -------------------------- Save output -------------------------- %%
        % Save into: C:\Users\...\data_PPG\<SessionName>\<RunName>_PPG_ledalab.mat
        outputFileName = [sessionName '_' runName '_PPG.mat'];
        outputFilePath = fullfile(ppgOutputRoot, outputFileName);
        
        save(outputFilePath, 'data');
        fprintf('    Saved file: %s\n', outputFileName);

        %% ------------------ Clean up temporary unzip dir ------------------ %%
        if exist(tempUnzipDir, 'dir')
            rmdir(tempUnzipDir, 's');
        end
    end
end

