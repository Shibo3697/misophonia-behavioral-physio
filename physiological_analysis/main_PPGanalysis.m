clc; clear;
%% Data folder
data_path = '/Users/zhoushibo/Library/CloudStorage/OneDrive-WichitaStateUniversity/Project_Misophonia/misophonia data/data_PPG';
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
excluded_files = {};
figure; 

for k = 1:numel(files) 
    load(fullfile(data_path, files(k).name)); 
    ppg = data.ppg; 
    peaks = peaks_all{k}; 
    t = (0:length(ppg)-1)/fs;

    plot(t, ppg, 'b'); 
    hold on; 
    plot(t(peaks), ppg(peaks), 'or');
    events = data.event;
    y_lims = ylim;
    for j = 1:length(events)
            x_start = events(j).time;     
            x_end = x_start + segment_duration;
            patch([x_start x_end x_end x_start], [y_lims(1) y_lims(1) y_lims(2) y_lims(2)], ...
                  'k', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
            text(x_start, y_lims(2), events(j).name, 'VerticalAlignment','top');
    end
    hold off; 
    grid on;
    zoom on;
    title(sprintf('File %d/%d: %s', k, numel(files), files(k).name), 'Interpreter', 'none');
    xlabel('Time (s)');
    ylim([10, 20]); 
    fprintf('Check File %d/%d: %s\n', k, numel(files), files(k).name);

    choice = input('  Enter is keep, x is remove ', 's');
    if strcmpi(choice, 'x')
        excluded_files{end+1} = files(k).name;
        fprintf(' remove\n');
    end
end

%% save in CSV
mask = ~ismember(Event_IBI_Results(:,1), excluded_files);
ResultTable = cell2table(Event_IBI_Results, ...
    'VariableNames', {'Filename','SubjectID', 'Condition', 'EventID', 'StartTime', 'Mean_IBI_s', 'Mean_HR_bpm'});

save_name = fullfile(data_path, 'Event_Mean_IBI.csv');
writetable(ResultTable, save_name);
fprintf('result in: %s\n', save_name);

%% linear mixed effect model

ResultTable.Condition = categorical(ResultTable.Condition);

ResultTable.SubjectID = categorical(ResultTable.SubjectID);


% linear mixed effects model
lmm = fitlme(ResultTable, 'Mean_HR_bpm ~ Condition + (1|SubjectID)');

% Display Coefficients (Shows the difference between Conditions and Neutral)
disp(lmm);
H = [0, 1, -1];
p_trig_unpleas = coefTest(lmm, H);
fprintf('trigger vs unpleasant: p = %.6f\n', p_trig_unpleas);

%% Visualization
figure('Color', 'w', 'Name', 'LMM Result');
boxplot(ResultTable.Mean_HR_bpm, ResultTable.Condition);
ylabel('BPM','FontSize',16);
xlabel('Sound categories','FontSize',16);
title('Heart Rate','FontSize',16);
grid on;
hold on;
conds = categories(ResultTable.Condition);
subs = unique(ResultTable.SubjectID);

for i = 1:length(subs)
    sub_id = subs(i);
    sub_idx = ResultTable.SubjectID == sub_id;
    sub_data = ResultTable(sub_idx, :);
    
    x_vals = [];
    y_vals = [];

    for j = 1:length(conds)
        cond_idx = sub_data.Condition == conds{j};
        if any(cond_idx)
            y_mean = mean(sub_data.Mean_HR_bpm(cond_idx), 'omitnan');
            x_vals(end+1) = j;      
            y_vals(end+1) = y_mean; % average HR in each condition of each subject
        end
    end
    
    if ~isempty(x_vals)
        plot(x_vals, y_vals, '-o', ...
            'Color', [0.6 0.6 0.6], ...     
            'MarkerEdgeColor', [0.3 0.3 0.3], ... 
            'MarkerFaceColor', 'w', ...     
            'LineWidth', 1, ...
            'MarkerSize', 5);
    end
end

% fitted lines
figure('Color', 'w', 'Name', 'LMM Fitted Lines');
hold on;

subs = unique(ResultTable.SubjectID);
n_subs = numel(subs);
colors = lines(n_subs);
conds = {'neutral','trigger','unpleasant'};

fe = fixedEffects(lmm);
fixed_y = [fe(1), fe(1)+fe(2), fe(1)+fe(3)];

[~, ~, re_tbl] = randomEffects(lmm);

for i = 1:n_subs
    idx = strcmp(string(re_tbl.Level), string(subs(i)));
    rand_intercept = re_tbl.Estimate(idx);

    y = fixed_y + rand_intercept;

    plot(1:3, y, '-o', ...
        'Color', colors(i,:), ...
        'LineWidth', 1.5, ...
        'MarkerFaceColor', colors(i,:), ...
        'DisplayName', string(subs(i)));
end

% group fixed effect
plot(1:3, fixed_y, '-s', ...
    'Color', 'k', 'LineWidth', 3, ...
    'MarkerFaceColor', 'k', ...
    'DisplayName', 'Group (Fixed Effect)');

xticks(1:3);
xticklabels(conds);
xlabel('Condition', 'FontSize', 14);
ylabel('Mean HR (bpm)', 'FontSize', 14);
grid on;
legend('Location', 'bestoutside', 'FontSize', 9);

% P-value plot
sig_pairs = [1, 3, 3.3084e-05;   % neutral vs unpleasant
             2, 3, p_trig_unpleas];  % trigger vs unpleasant
y_lim = ylim;
y_top = y_lim(2);
step  = (y_top - y_lim(1)) * 0.06;

for ip = 1:size(sig_pairs, 1)
    a = sig_pairs(ip, 1);
    b = sig_pairs(ip, 2);
    p = sig_pairs(ip, 3);

    if     p < 0.001; lbl = '***';
    elseif p < 0.01;  lbl = '**';
    elseif p < 0.05;  lbl = '*';
    else;             lbl = 'ns';
    end

    y_bar = y_top + (ip - 0.5) * step;

    line([a b], [y_bar y_bar],           'Color','k','LineWidth',1.2,'HandleVisibility','off');
    line([a a], [y_bar-step*0.2, y_bar], 'Color','k','LineWidth',1.2,'HandleVisibility','off');
    line([b b], [y_bar-step*0.2, y_bar], 'Color','k','LineWidth',1.2,'HandleVisibility','off');
    text((a+b)/2, y_bar+step*0.15, lbl, ...
        'HorizontalAlignment','center','FontSize',13,'FontWeight','bold');
end

ylim([y_lim(1), y_top + size(sig_pairs,1)*step + step*0.8]);
hold off;