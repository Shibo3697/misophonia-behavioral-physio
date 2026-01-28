% import data
clc
clear
close all
path = 'C:\Users\t243f765\OneDrive - Wichita State University\Project_Misophonia\data_GSRledalab - Copy';

%% --------------------------Processing and CDA--------------------------%%
% path_data = '2025-10-30 CS12';
% Ledalab(path, 'open', 'mat', 'downsample', 10,'filter',[2 5],'smooth', {'gauss', 10}, 'analyze','CDA', 'optimize',6, 'export_era', [1 15 .05 3]);

% Import all mat data from PATH, dowmsamples from 500 to 50Hz (factor 10);
% Butterworth filter [2 5] for a 2rst order low-pass filter with 5Hz cutoff
% Smoothing using the gauss-method and a window width of 10 samples analyzes
% Analyzes them by means of CDA (performing optimization of 6 initial values);
% Reference of optimization: Benedek, M., & Kaernbach, C. (2010). Decomposition of skin conductance data by means of nonnegative deconvolution. psychophysiology, 47(4), 647-658.
% Reference of CDA: Benedek, M. & Kaernbach, C. (2010). A continuous measure of phasic electrodermal activity. Journal of Neuroscience Methods, 190, 80-91.
% Exports the event-related data:
% Response window of 1 to 15 second after each marker
% SCR amplitude threshold of .05 muS (P<0.05)
% Export processed data to excel file as XLS (method 3).
% Save the process step to batchmode_protocol.mat


%% ----------------------------extract data--------------------------%%
% pad XLS data together
files = dir(fullfile(path, '*_era.xls'));
data_all = cell(numel(files),1);

for k = 1:numel(files)
    data_all{k} = import_xls(fullfile(files(k).name)); % import_xls function
    raw = import_xls(fullfile(files(k).name));
    name_parts = split(files(k).name, '_'); 
    sub_id = name_parts{2};
    id_col = repmat({sub_id}, size(raw, 1), 1);
    data_all{k} = [raw, id_col];
end

alldata = vertcat(data_all{:});

%% ---------------------------linear Mixed effect Model-------------------------%%
Condition_Vec = alldata{:, 2}; % Condition 
SCR_Vec       = alldata{:, 4}; % CDA.nSCR
Subject_Vec   = alldata{:, 16};% Subject ID
LMM_Table = table(Subject_Vec, Condition_Vec, SCR_Vec, ...
    'VariableNames', {'Subject', 'Condition', 'SCR'});

LMM_Table.Condition = categorical(LMM_Table.Condition, [4, 2, 8], ...
    {'Neutral', 'Unpleasant', 'Trigger'});

% Run the Linear Mixed-effects Model
model = fitlme(LMM_Table, 'SCR ~ Condition + (1|Subject)');


% Display Coefficients (Shows the difference between Conditions and Neutral)
disp(model.Coefficients);

% Visualization
figure('Color', 'w', 'Name', 'LMM Result');
boxplot(LMM_Table.SCR, LMM_Table.Condition);
title('SCR Amplitude by Condition');
ylabel('SCR Amplitude (\muS)');
xlabel('Condition');
grid on;