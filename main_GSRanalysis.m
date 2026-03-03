% import data
clc
clear
close all
path = 'C:\Users\t243f765\OneDrive - Wichita State University\Project_Misophonia\misophonia data\data_GSR';

%% cut baseline
files = dir(fullfile(path, '2025-*.mat'));
for k = 1:numel(files)
    file_path = fullfile(path, files(k).name);
    load(file_path); 
    
    idx = data.time >= 5.0; 
    data.time = data.time(idx);
    data.conductance = data.conductance(idx);
    
    save(file_path, 'data'); 
end
%% Processing and extract CD
% Ledalab(path, 'open', 'mat', 'downsample', 10,'filter',[2 5],'smooth', {'gauss', 10}, 'analyze','CDA', 'optimize',6, 'export_era', [1 15 .01 3]);

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

%% Visual Check
% VisualCheckGSR(path);
%% extract data
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

%% linear Mixed effect Model
Condition_ID = alldata{:, 3}; % Condition 
SubjectID       = alldata{:, 16};% Subject ID
CDA_nSCR        = alldata{:, 4}; 
CDA_AmpSum      = alldata{:, 6};
CDA_Tonic       = alldata{:, 10};
CDA_PhasicMax   = alldata{:, 9};
CDA_iSCR        = alldata{:, 8};

CDA_nSCR      = log1p(CDA_nSCR); 
CDA_AmpSum    = log1p(CDA_AmpSum);
CDA_PhasicMax = log1p(CDA_PhasicMax);
CDA_iSCR      = log1p(CDA_iSCR);
CDA_Tonic     = log1p(CDA_Tonic);

LMM_Table = table(SubjectID, Condition_ID, CDA_nSCR, CDA_AmpSum, CDA_Tonic, CDA_PhasicMax, CDA_iSCR, ...
    'VariableNames', {'Subject', 'Condition', 'CDA_nSCR', 'CDA_AmpSum', 'CDA_Tonic', 'CDA_PhasicMax', 'CDA_iSCR'});

LMM_Table.Condition = categorical(LMM_Table.Condition);

% Run the Linear Mixed-effects Model
% CDA.CDA_nSCR
disp('====== Model Results: CDA_nSCR ======');
% model_nSCR = fitglme(LMM_Table, 'CDA_nSCR ~ Condition + (1|Subject)', 'Distribution', 'Poisson');
model_nSCR = fitlme(LMM_Table, 'CDA_nSCR ~ Condition + (1|Subject)');
disp(model_nSCR.Coefficients);

% 2. CDA.AmpSum
disp('====== Model Results: CDA.AmpSum ======');
model_AmpSum = fitlme(LMM_Table, 'CDA_AmpSum ~ Condition + (1|Subject)');
disp(model_AmpSum.Coefficients);

% 3. CDA.Tonic
disp('====== Model Results: CDA.Tonic ======');
model_Tonic = fitlme(LMM_Table, 'CDA_Tonic ~ Condition + (1|Subject)');
disp(model_Tonic.Coefficients);

% 4. CDA.PhasicMax
disp('====== Model Results: CDA.PhasicMax ======');
model_PhasicMax = fitlme(LMM_Table, 'CDA_PhasicMax ~ Condition + (1|Subject)');
disp(model_PhasicMax.Coefficients);

% 5. CDA.iSCR
disp('====== Model Results: CDA.iSCR ======');
model_iSCR = fitlme(LMM_Table, 'CDA_iSCR ~ Condition + (1|Subject)');
disp(model_iSCR.Coefficients);

%% Visualization
figure('Color', 'w', 'Name', 'LMM Result');

% 1.CDA.nSCR 
subplot(2,3,1)
boxplot(LMM_Table.CDA_nSCR, LMM_Table.Condition);
title('CDA.nSCR','FontSize',16);
ylabel('nSCR','FontSize',16); % the number of significant (above-threshold) SCRs
grid on;

% 2. CDA.AmpSum
subplot(2, 3, 2);
boxplot(LMM_Table.CDA_AmpSum, LMM_Table.Condition);
title('CDA.AmpSum','FontSize',16);
ylabel('\muS', 'FontSize',16);
grid on;

% 3. CDA.Tonic
subplot(2, 3, 3);
boxplot(LMM_Table.CDA_Tonic, LMM_Table.Condition);
title('CDA.Tonic','FontSize',16);
ylabel('\muS','FontSize',16);
grid on;

% 4. CDA.PhasicMax
subplot(2, 3, 4);
boxplot(LMM_Table.CDA_PhasicMax, LMM_Table.Condition);
title('CDA.PhasicMax','FontSize',16);
ylabel('\muS','FontSize',16);
grid on;

% 5. CDA.iSCR
subplot(2, 3, 5);
boxplot(LMM_Table.CDA_iSCR, LMM_Table.Condition);
title('CDA.iSCR','FontSize',16);
ylabel('\muS \times s','FontSize',16);
xlabel('Sound categories','FontSize',16);
grid on;