clc;
clear;
close all;

%% Settings
data_path = '/Users/zhoushibo/Desktop/Copy_of_data_GSR_test_raw/EDA_output';
files = dir(fullfile(data_path, '2025-*_CS*.mat'));

time = -5:0.02:20;                 % 50-Hz sample rate
baseline = time >= -5 & time < 0;
condition_names = ["trigger", "unpleasant", "neutral"];
condition_labels = ["Trigger", "Unpleasant", "Neutral"];
colors = [0.88, 0.15, 0.12; ...   % Trigger: red
          0.25, 0.62, 0.18; ...   % Unpleasant: green
          0.10, 0.32, 0.68];      % Neutral: blue

%% Extract and baseline-correct each trial
trial_data = [];
trial_subject = strings(0, 1);
trial_condition = [];

for f = 1:numel(files)
    load(fullfile(files(f).folder, files(f).name), 'data');

    token = regexp(files(f).name, '_(CS[0-9]+)_', 'tokens', 'once');
    subject = string(token{1});

    for e = 1:numel(data.event)
        condition = find(condition_names == string(data.event(e).name));
        event_time = data.event(e).time + time;

        % Six first trials start less than 5 s after the prepared data
        % begin and therefore do not have a complete baseline.
        if event_time(1) < data.time(1)
            continue
        end

        gsr = interp1(data.time, data.conductance, event_time, 'linear');
        gsr = gsr - mean(gsr(baseline));

        trial_data(end + 1, :) = gsr; %#ok<SAGROW>
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

% mean and SEM
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
ylabel('Skin Conductance (\muS)', ...
    'FontSize', 20, 'FontWeight', 'bold');
legend(lines, condition_labels, 'Location', 'northeast', ...
    'Box', 'off', 'FontSize', 16);
set(gca, 'FontName', 'Arial', 'FontSize', 18, ...
    'FontWeight', 'bold', 'LineWidth', 1.5, ...
    'TickDir', 'out', 'Box', 'off');
hold off;
