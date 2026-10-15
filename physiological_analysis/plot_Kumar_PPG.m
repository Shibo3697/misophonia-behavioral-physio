clc;
clear;
close all;

%% Settings
data_path = ['/Users/zhoushibo/Library/CloudStorage/' ...
    'OneDrive-WichitaStateUniversity/Project_Misophonia/' ...
    'misophonia_physiological_data/data_PPG'];
files = dir(fullfile(data_path, '2025-*CS*_PPG.mat'));

fs = 500;
time = -5:0.1:20;                  % 10-Hz time axis
baseline = time >= -5 & time < 0;
condition_names = ["trigger", "unpleasant", "neutral"];
condition_labels = ["Trigger", "Unpleasant", "Neutral"];
colors = [0.88, 0.15, 0.12; ...   % Trigger: red
          0.25, 0.62, 0.18; ...   % Unpleasant: green
          0.10, 0.32, 0.68];      % Neutral: blue

%% Create continuous HR and extract each trial
trial_data = [];
trial_subject = strings(0, 1);
trial_condition = [];

for f = 1:numel(files)
    load(fullfile(files(f).folder, files(f).name), 'data');

    ppg = data.ppg(:);
    ppg_time = data.time(:);

    % Match the existing PPG analysis: remove the first 6 s before qppg.
    first_sample = round(6 * fs) + 1;
    ppg = ppg(first_sample:end);
    ppg_time = ppg_time(first_sample:end);

    peaks = qppg(ppg, fs, 1, numel(ppg));
    peak_times = ppg_time(peaks);

    ibi = diff(peak_times);
    instantaneous_hr = 60 ./ ibi;

    % Each IBI-derived HR value is assigned to the second pulse.
    hr_time = peak_times(2:end);

    % Match the physiological range used by Kumar et al.
    valid = instantaneous_hr >= 45 & instantaneous_hr <= 120;
    instantaneous_hr = instantaneous_hr(valid);
    hr_time = hr_time(valid);

    % Interpolate the irregular HR samples to a continuous 10-Hz series.
    continuous_time = hr_time(1):0.1:hr_time(end);
    continuous_hr = interp1( ...
        hr_time, instantaneous_hr, continuous_time, 'spline');

    token = regexp(files(f).name, '(CS[0-9]+)', 'tokens', 'once');
    subject = string(token{1});

    for e = 1:numel(data.event)
        condition = find(condition_names == string(data.event(e).name));
        event_time = data.event(e).time + time;

        if event_time(1) < continuous_time(1) || ...
                event_time(end) > continuous_time(end)
            continue
        end

        hr = interp1(continuous_time, continuous_hr, event_time, 'linear');
        hr = hr - mean(hr(baseline));

        trial_data(end + 1, :) = hr; %#ok<SAGROW>
        trial_subject(end + 1, 1) = subject; %#ok<SAGROW>
        trial_condition(end + 1, 1) = condition; %#ok<SAGROW>
    end
end

%% Average trials within each subject and condition
subjects = unique(trial_subject);
subject_mean = nan(numel(subjects), numel(condition_names), numel(time));

for s = 1:numel(subjects)
    for c = 1:numel(condition_names)
        rows = trial_subject == subjects(s) & trial_condition == c;
        subject_mean(s, c, :) = mean(trial_data(rows, :), 1);
    end
end

group_mean = squeeze(mean(subject_mean, 1));
group_sem = squeeze(std(subject_mean, 0, 1)) ./ sqrt(numel(subjects));

%% Plot mean and SEM
figure('Color', 'w', 'Position', [100, 100, 1000, 700]);
hold on;

lines = gobjects(1, numel(condition_names));
for c = 1:numel(condition_names)
    lower = group_mean(c, :) - group_sem(c, :);
    upper = group_mean(c, :) + group_sem(c, :);

    fill([time, fliplr(time)], [lower, fliplr(upper)], colors(c, :), ...
        'FaceAlpha', 0.22, 'EdgeColor', 'none', ...
        'HandleVisibility', 'off');
    lines(c) = plot(time, group_mean(c, :), ...
        'Color', colors(c, :), 'LineWidth', 3);
end

yline(0, '-', 'Color', [0.7, 0.7, 0.7], ...
    'HandleVisibility', 'off');
xline(0, 'k-', 'Sound onset', 'LineWidth', 2, ...
    'LabelVerticalAlignment', 'top', ...
    'FontSize', 20, 'FontWeight', 'bold', ...
    'HandleVisibility', 'off');
xline(15, 'k-', 'Sound offset', 'LineWidth', 2, ...
    'LabelVerticalAlignment', 'top', ...
    'FontSize', 20, 'FontWeight', 'bold', ...
    'HandleVisibility', 'off');

xlim([-5, 20]);
xlabel('Time (s)', 'FontSize', 20, 'FontWeight', 'bold');
ylabel('Heart Rate (bpm)', 'FontSize', 20, 'FontWeight', 'bold');
legend(lines, condition_labels, 'Location', 'northeast', ...
    'Box', 'off', 'FontSize', 16);
set(gca, 'FontName', 'Arial', 'FontSize', 18, ...
    'FontWeight', 'bold', 'LineWidth', 1.5, ...
    'TickDir', 'out', 'Box', 'off');
hold off;
