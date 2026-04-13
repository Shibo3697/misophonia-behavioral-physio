% import data
clc
clear
close all
path = 'C:\Users\admin\Desktop\data_GSR_test_raw';

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
Ledalab(path, 'open', 'mat', 'downsample', 10,'filter',[1 5],'smooth', {'adapt'}, 'analyze','CDA', 'optimize',6, 'export_era', [1 20 .01 3]);

% Import all mat data from PATH, dowmsamples from 500 to 50Hz (factor 10);
% Butterworth filter [2 5] for a 2rst order low-pass filter with 5Hz cutoff
% Smoothing using the gauss-method and a window width of 10 samples analyzes
% Analyzes them by means of CDA (performing optimization of 6 initial values);
% Reference of optimization: Benedek, M., & Kaernbach, C. (2010). Decomposition of skin conductance data by means of nonnegative deconvolution. psychophysiology, 47(4), 647-658.
% Reference of CDA: Benedek, M. & Kaernbach, C. (2010). A continuous measure of phasic electrodermal activity. Journal of Neuroscience Methods, 190, 80-91.
% Exports the event-related data:
% Response window of 1 to 18 second after each markers
% SCR amplitude threshold of .01 muS
% Export processed data to excel file as XLS (method 3).
% Save the process step to batchmode_protocol.mat

%% Visual Check
% VisualCheckGSR(path);
%% extract data
% pad XLS data together
files = dir(fullfile(path, '*_era.xls'));
data_all = cell(numel(files), 1);

for k = 1:numel(files)
    raw = readtable(fullfile(path, files(k).name), 'Sheet', 'CDA');
    name_parts = split(files(k).name, '_');
    raw.SubjectID = repmat(string(name_parts{2}), size(raw, 1), 1);
    data_all{k} = raw;
end

alldata = vertcat(data_all{:});

%% Build LMM Table
LMM_Table = table( ...
    alldata.SubjectID, ...
    alldata.Event_Name, ...
    alldata.CDA_nSCR, ...
    alldata.CDA_AmpSum_muS_, ...
    alldata.CDA_Tonic_muS_, ...
    alldata.CDA_PhasicMax_muS_, ...
    alldata.CDA_ISCR_muSxs_, ...
    'VariableNames', {'Subject','Condition','CDA_nSCR','CDA_AmpSum','CDA_Tonic','CDA_PhasicMax','CDA_iSCR'});
%% linear Mixed effect Model
models = {'CDA_nSCR','CDA_AmpSum','CDA_Tonic','CDA_PhasicMax','CDA_iSCR'};
for m = 1:numel(models)
    fprintf('====== Model Results: %s ======\n', models{m});
    mdl = fitlme(LMM_Table, sprintf('%s ~ Condition + (1|Subject)', models{m}));
    disp(mdl.Coefficients);
end

%% Visualization
figure('Color', 'w', 'Name', 'LMM Result');
vars    = {'CDA_nSCR','CDA_AmpSum','CDA_Tonic','CDA_PhasicMax','CDA_iSCR'};
titles  = {'CDA.nSCR','CDA.AmpSum','CDA.Tonic','CDA.PhasicMax','CDA.iSCR'};
ylabels = {'nSCR', '\muS', '\muS', '\muS', '\muS \times s'};

for v = 1:numel(vars)
    subplot(2, 3, v);
    boxplot(LMM_Table.(vars{v}), LMM_Table.Condition);
    title(titles{v}, 'FontSize', 16);
    ylabel(ylabels{v}, 'FontSize', 16);
    grid on;
end

%% plot2
% 
% figure('Color', 'w', 'Name', 'Data Distribution Scatter', 'Position', [100, 100, 1200, 800]);
% 
% vars    = {'CDA_nSCR','CDA_AmpSum','CDA_Tonic','CDA_PhasicMax','CDA_iSCR'};
% titles  = {'CDA.nSCR','CDA.AmpSum','CDA.Tonic','CDA.PhasicMax','CDA.iSCR'};
% ylabels = {'Count', '\muS', '\muS', '\muS', '\muS \times s'};
% 
% cond_cats = categories(LMM_Table.Condition);
% cond_idx  = grp2idx(LMM_Table.Condition); 
% 
% for v = 1:numel(vars)
%     subplot(2, 3, v);
% 
% 
%     swarmchart(cond_idx, LMM_Table.(vars{v}), 15, 'filled', ...
%         'MarkerFaceAlpha', 0.4, 'XJitterWidth', 0.6);
%     hold on;
% 
%     boxplot(LMM_Table.(vars{v}), cond_idx, 'Colors', 'k', 'Symbol', '', 'Positions', 1:numel(cond_cats));
% 
% 
%     xticks(1:numel(cond_cats));
%     xticklabels(cond_cats);
% 
%     title(titles{v}, 'FontSize', 16, 'FontWeight', 'bold');
%     ylabel(ylabels{v}, 'FontSize', 14);
% 
%         yl = ylim;
%     ylim([min(0, yl(1)) - 0.5, yl(2) + 0.5]); 
%     grid on;
%     hold off;
% end
% 
% subplot(2, 3, 5);
% xlabel('Sound categories', 'FontSize', 16);