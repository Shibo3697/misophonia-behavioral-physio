clc; clear;
%% Data folder
data_path = 'C:\Users\t243f765\OneDrive - Wichita State University\Project_Misophonia\misophonia data\data_PPG';
files = dir(fullfile(data_path, '*.mat'));
fs = 500;

segment_duration = 15; % duration 15s
num_files = numel(files);

peaks_all = cell(1, num_files);
HR_all    = cell(1, num_files);
Event_IBI_Results = {}; 

%% main loop
for k = 1:num_files
    load(fullfile(data_path, files(k).name));

    ppg = data.ppg;
    % detect peaks using PhysioNet
    from = 3000; % cut first 6s (6*500=3000)
    to = length(ppg);
    peaks = qppg(ppg, fs, from, to);                      
    peaks_all{k} = peaks;
    
    % SubjectID
    filename = files(k).name;
    parts = split(filename, {' ', '_'}); 
    sub_id = parts{2};

    % Calculate IBI
    global_ibi = diff(peaks) / fs;                     
    HR_all{k} = 60 ./ global_ibi; 
    fprintf('processing file %d: %s...\n', k, files(k).name);

    % --- Event ---
    events = data.event;
        for j = 1:length(events)
            % get events from raw data
            onset = events(j).time;       % onset
            ev_type    = string(events(j).name); % event types
            ID         = events(j).nid;        % event ID
            
            % Start ~ Start + 15s
            % index = time * fs
            idx_start = onset * fs;
            idx_end   = (onset + segment_duration) * fs;
            
            % find all peak of PPG during one event
            peaks_in_segment = peaks(peaks >= idx_start & peaks <= idx_end);
            
            % At least two peaks to calculate the interval (IBI)
            if length(peaks_in_segment) > 1
                segment_ibis = diff(peaks_in_segment) / fs; 
                
                % mean IBI
                mean_ibi = mean(segment_ibis); 
                mean_hr  = 60 / mean_ibi;
            else
                mean_ibi = NaN; 
                mean_hr  = NaN;
            end
            
            % save result (filename, event type, event ID, mean IBI, meanHR)
            Event_IBI_Results(end+1, :) = {filename, sub_id, ev_type, ID, onset, mean_ibi, mean_hr};
        end
end

%% plot
% excluded_files = {};
% figure; 
% 
% for k = 1:numel(files) 
%     load(fullfile(data_path, files(k).name)); 
%     ppg = data.ppg; 
%     peaks = peaks_all{k}; 
%     t = (0:length(ppg)-1)/fs;
% 
%     plot(t, ppg, 'b'); 
%     hold on; 
%     plot(t(peaks), ppg(peaks), 'or');
%     events = data.event;
%     y_lims = ylim;
%     for j = 1:length(events)
%             x_start = events(j).time;     
%             x_end = x_start + segment_duration;
%             patch([x_start x_end x_end x_start], [y_lims(1) y_lims(1) y_lims(2) y_lims(2)], ...
%                   'k', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
%             text(x_start, y_lims(2), events(j).name, 'VerticalAlignment','top');
%     end
%     hold off; 
%     grid on;
%     zoom on;
%     title(sprintf('File %d/%d: %s', k, numel(files), files(k).name), 'Interpreter');
%     xlabel('Time (s)');
%     ylim([10, 20]); 
%     fprintf('Check File %d/%d: %s\n', k, numel(files), files(k).name);
% 
%     choice = input('  Enter is keep, x is remove ', 's');
%     if strcmpi(choice, 'x')
%         excluded_files{end+1} = files(k).name;
%         fprintf(' remove\n');
%     end
% end

%% save in CSV
%mask = ~ismember(Event_IBI_Results(:,1), excluded_files);
ResultTable = cell2table(Event_IBI_Results, ...
    'VariableNames', {'Filename','SubjectID', 'Condition', 'EventID', 'StartTime', 'Mean_IBI_s', 'Mean_HR_bpm'});

savefile = "C:\Users\t243f765\OneDrive - Wichita State University\Project_Misophonia\misophonia data\data_PPG";
save_name = fullfile(savefile, 'Event_Mean_IBI.csv');
writetable(ResultTable, save_name);
fprintf('result in: %s\n', save_name);

%% linear mixed effect model

ResultTable.Condition = categorical(ResultTable.Condition);

ResultTable.SubjectID = categorical(ResultTable.SubjectID);


% linear mixed effects model
lmm = fitlme(ResultTable, 'Mean_HR_bpm ~ Condition + (1|SubjectID)');

% Display Coefficients (Shows the difference between Conditions and Neutral)
disp(lmm.Coefficients);

% 6. Visualization
figure('Color', 'w', 'Name', 'LMM Result');
boxplot(ResultTable.Mean_HR_bpm, ResultTable.Condition);
ylabel('BPM','FontSize',16);
xlabel('Sound categories','FontSize',16);
title('Heart Rate','FontSize',16);
grid on;
