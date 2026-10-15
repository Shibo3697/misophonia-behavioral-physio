clc;
clear;
close all;

%% Paths and settings
script_directory = fileparts(mfilename('fullpath'));
if isempty(script_directory)
    script_directory = pwd;
end

raw_data_path = '/Users/zhoushibo/Desktop/Copy_of_data_GSR_test_raw';
output_path = fullfile(raw_data_path, 'EDA_output');
input_pattern = '2025-*_CS*.mat';

toolbox_path = fullfile(script_directory, 'function_and_toolbox');
ledalab_path = fullfile(toolbox_path, 'ledalab-master');
addpath(toolbox_path);
addpath(genpath(ledalab_path));

trim_seconds = 5;
downsample_factor = 10;       % 500 Hz -> 50 Hz
lowpass_cutoff_hz = 5;
butterworth_order = 1;
response_window = [1, 20];
scr_amplitude_threshold = 0.01;
cda_optimization_starts = 6;

condition_order = {'neutral', 'trigger', 'unpleasant'};
plot_condition_order = {'trigger', 'unpleasant', 'neutral'};
plot_condition_labels = {'Trigger', 'Unpleasant', 'Neutral'};

%% Validate input and prepare an independent output directory
if ~isfolder(raw_data_path)
    error('Raw-data directory does not exist: %s', raw_data_path);
end

raw_files = dir(fullfile(raw_data_path, input_pattern));
if isempty(raw_files)
    error('No CS files matching %s were found in %s.', ...
          input_pattern, raw_data_path);
end

if ~isfolder(output_path)
    mkdir(output_path);
elseif ~isempty(dir(fullfile(output_path, '2025-*.mat'))) || ...
       ~isempty(dir(fullfile(output_path, '*_era.txt')))
    error(['The output directory already contains analysis files. ' ...
           'Use an empty output directory to avoid processing data twice: %s'], ...
          output_path);
end

fprintf('Preparing %d CS run(s). Raw files will not be modified.\n', ...
        numel(raw_files));

%% Discard 5 s, downsample to 50 Hz, then apply 5-Hz low-pass filter
for k = 1:numel(raw_files)
    source_file = fullfile(raw_data_path, raw_files(k).name);
    loaded = load(source_file, 'data');
    data = loaded.data;

    required_fields = {'time', 'conductance', 'event'};
    if ~all(isfield(data, required_fields))
        error('Missing time, conductance, or event in %s.', raw_files(k).name);
    end

    raw_time = double(data.time(:));
    raw_conductance = double(data.conductance(:));
    if numel(raw_time) ~= numel(raw_conductance)
        error('Time and conductance lengths differ in %s.', raw_files(k).name);
    end
    if any(~isfinite(raw_time)) || any(~isfinite(raw_conductance))
        error('Nonfinite time or conductance in %s.', raw_files(k).name);
    end

    raw_fs = 1 / median(diff(raw_time));
    target_fs = raw_fs / downsample_factor;
    if abs(raw_fs - 500) > 2 || abs(target_fs - 50) > 0.2
        error('Expected approximately 500-Hz input in %s; found %.3f Hz.', ...
              raw_files(k).name, raw_fs);
    end

    keep = raw_time >= raw_time(1) + trim_seconds;
    trimmed_time = raw_time(keep);
    trimmed_conductance = raw_conductance(keep);
    if numel(trimmed_time) < downsample_factor * 10
        error('Too little data remain after trimming %s.', raw_files(k).name);
    end

    % Shift the signal and markers together so their relative alignment is
    % unchanged and the prepared file starts close to zero.
    trim_time_shift = trimmed_time(1);
    trimmed_time = trimmed_time - trim_time_shift;
    for e = 1:numel(data.event)
        data.event(e).time = double(data.event(e).time) - trim_time_shift;
    end

    usable_samples = numel(trimmed_time) - ...
                     mod(numel(trimmed_time), downsample_factor);
    trimmed_time = trimmed_time(1:usable_samples);
    trimmed_conductance = trimmed_conductance(1:usable_samples);

    downsampled_time = mean(reshape( ...
        trimmed_time, downsample_factor, []), 1)';
    downsampled_conductance = mean(reshape( ...
        trimmed_conductance, downsample_factor, []), 1)';

    downsample_time_shift = downsampled_time(1);
    downsampled_time = downsampled_time - downsample_time_shift;
    for e = 1:numel(data.event)
        data.event(e).time = data.event(e).time - downsample_time_shift;
    end

    normalized_cutoff = lowpass_cutoff_hz / (target_fs / 2);
    [filter_b, filter_a] = butter( ...
        butterworth_order, normalized_cutoff, 'low');
    filtered_conductance = filtfilt( ...
        filter_b, filter_a, downsampled_conductance);

    event_times = arrayfun(@(x) double(x.time), data.event);
    if any(event_times + response_window(1) < downsampled_time(1)) || ...
       any(event_times + response_window(2) > downsampled_time(end))
        error('At least one 1-20-s event window is incomplete in %s.', ...
              raw_files(k).name);
    end

    data.time = downsampled_time;
    data.conductance = filtered_conductance;
    data.timeoff = trim_time_shift + downsample_time_shift;
    save(fullfile(output_path, raw_files(k).name), 'data');
    fprintf('Prepared %d/%d: %s\n', k, numel(raw_files), raw_files(k).name);
end

%% Adaptive smoothing, CDA, and text export
% Downsampling and filtering were performed explicitly above in manuscript
% order. Ledalab now performs adaptive smoothing and CDA only.
original_directory = pwd;
cd(output_path);
try
    Ledalab(input_pattern, ...
        'open', 'mat', ...
        'smooth', {'adapt'}, ...
        'analyze', 'CDA', ...
        'optimize', cda_optimization_starts, ...
        'export_era', [response_window, scr_amplitude_threshold, 2]);
catch analysis_error
    cd(original_directory);
    rethrow(analysis_error);
end
cd(original_directory);

%% Manual visual review
% Each trial is displayed using its onset and its analyzed 1-20-s window.
review_aborted = VisualCheckGSR(output_path, response_window);
if review_aborted
    error(['Visual review was aborted. Feature combination and statistics ' ...
           'were not run; unreviewed runs were not analyzed statistically.']);
end

%% Combine retained Ledalab event features
era_files = dir(fullfile(output_path, '*_era.txt'));
if isempty(era_files)
    error('No retained *_era.txt files remain after visual review.');
end

data_all = cell(numel(era_files), 1);
for k = 1:numel(era_files)
    era_path = fullfile(output_path, era_files(k).name);
    raw = readLedalabEraText(era_path);
    subject_match = regexp( ...
        era_files(k).name, '_(CS[0-9]+)_', 'tokens', 'once');
    if isempty(subject_match)
        error('Cannot extract SubjectID from %s.', era_files(k).name);
    end

    raw.SubjectID = repmat(string(subject_match{1}), height(raw), 1);
    raw.Filename = repmat(string(era_files(k).name), height(raw), 1);
    data_all{k} = raw;
end
all_data = vertcat(data_all{:});

event_name = findVariableName(all_data.Properties.VariableNames, 'EventName');
n_scr_name = findVariableName(all_data.Properties.VariableNames, 'CDAnSCR');
amp_sum_name = findVariableName(all_data.Properties.VariableNames, 'CDAAmpSum');
tonic_name = findVariableName(all_data.Properties.VariableNames, 'CDATonic');
phasic_max_name = findVariableName( ...
    all_data.Properties.VariableNames, 'CDAPhasicMax');
i_scr_name = findVariableName(all_data.Properties.VariableNames, 'CDAISCR');

LMM_Table = table( ...
    all_data.Filename, all_data.SubjectID, ...
    string(all_data.(event_name)), ...
    all_data.(n_scr_name), all_data.(amp_sum_name), ...
    all_data.(tonic_name), all_data.(phasic_max_name), ...
    all_data.(i_scr_name), ...
    'VariableNames', {'Filename', 'Subject', 'Condition', 'CDA_nSCR', ...
                      'CDA_AmpSum', 'CDA_Tonic', 'CDA_PhasicMax', ...
                      'CDA_iSCR'});

LMM_Table.Condition = categorical( ...
    LMM_Table.Condition, condition_order, condition_order);
LMM_Table.Subject = categorical(LMM_Table.Subject);
writetable(LMM_Table, fullfile(output_path, 'GSR_Event_Features.csv'));

%% Linear mixed-effects models
model_variables = {'CDA_nSCR', 'CDA_AmpSum', 'CDA_Tonic', ...
                   'CDA_PhasicMax', 'CDA_iSCR'};
for m = 1:numel(model_variables)
    variable_name = model_variables{m};
    model_rows = isfinite(LMM_Table.(variable_name));
    model_data = LMM_Table(model_rows, :);
    fprintf('\n====== Model results: %s ======\n', variable_name);
    model = fitlme(model_data, sprintf( ...
        '%s ~ Condition + (1|Subject)', variable_name));
    disp(model);
end

%% Feature distributions
figure('Color', 'w', 'Name', 'EDA event features');
plot_titles = {'CDA.nSCR', 'CDA.AmpSum', 'CDA.Tonic', ...
               'CDA.PhasicMax', 'CDA.iSCR'};
y_labels = {'Count', '\muS', '\muS', '\muS', '\muS \times s'};
plot_conditions = reordercats(LMM_Table.Condition, plot_condition_order);

for v = 1:numel(model_variables)
    subplot(2, 3, v);
    boxplot(LMM_Table.(model_variables{v}), plot_conditions);
    xticklabels(plot_condition_labels);
    title(plot_titles{v}, 'FontSize', 14);
    ylabel(y_labels{v}, 'FontSize', 12);
    xlabel('Condition');
    grid on;
end

fprintf('\nAnalysis complete. Results are in: %s\n', output_path);

%% Local functions
function era_table = readLedalabEraText(era_path)
    era_table = readtable(era_path, ...
        'FileType', 'text', ...
        'Delimiter', '\t', ...
        'VariableNamingRule', 'preserve');
    if isempty(era_table)
        error('Ledalab ERA export is empty: %s', era_path);
    end
end

function variable_name = findVariableName(variable_names, required_text)
    names = string(variable_names);
    normalized_names = regexprep(lower(names), '[^a-z0-9]', '');
    normalized_required = regexprep( ...
        lower(string(required_text)), '[^a-z0-9]', '');
    match = find(contains(normalized_names, normalized_required), 1);
    if isempty(match)
        error('Cannot find a table variable matching %s.', required_text);
    end
    variable_name = char(names(match));
end
