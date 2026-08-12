%% Behavior-brain relationship for the left and right hemispheres
% Each observation is one subject x condition x hemisphere.

clc; clear; close all;

%% Paths and analysis choices
dataFolder = '/Volumes/shibo/misophonia fnirs/control_real/control 3';
behaviorFolder = ['/Users/zhoushibo/Library/CloudStorage/' ...
    'OneDrive-WichitaStateUniversity/Project_Misophonia/miso_behavior data'];

subjects = ["CS02", "CS03", "CS05", "CS06", "CS07", ...
    "CS08", "CS09", "CS10", "CS11", "CS12"];
% Column order in processedAV(s).HbO.
conditions = ["Unpleasant", "Neutral", "Trigger"];
hemispheres = ["Left", "Right"];
annoyanceColor = [31, 120, 181] / 255;

%% Load brain and behavioral results
load(fullfile(dataFolder, 'processed_data_NeuroDOT.mat'), 'nirs');
processedAV = nirs.processed_AV;
retainedVertices = nirs.Sensitivity_orig.brain_vertices( ...
    nirs.Sensitivity_orig.indices, :);
clear nirs;
trials = read_psychopy(behaviorFolder);

%% Identify retained vertices in each hemisphere
brain_mid_point = 131;

% atlasViewer orientation is LIA, so larger x values are on the left.
hemisphereMasks = {retainedVertices(:, 1) >= brain_mid_point, ...
    retainedVertices(:, 1) < brain_mid_point};

fprintf('Retained vertices: left = %d, right = %d, total = %d\n', ...
    sum(hemisphereMasks{1}), sum(hemisphereMasks{2}), ...
    size(retainedVertices, 1));

%% Pair one mean rating with one hemispheric mean HbO response
% HbO is averaged across retained vertices within each hemisphere and then
% converted from M to uM.
nSubjects = numel(subjects);
nConditions = numel(conditions);
nHemispheres = numel(hemispheres);
nObservations = nSubjects * nConditions * nHemispheres;

Subject = strings(nObservations, 1);
Condition = strings(nObservations, 1);
Hemisphere = strings(nObservations, 1);
MeanRating = nan(nObservations, 1);
MeanBrainResponse = nan(nObservations, 1);

row = 0;
for s = 1:nSubjects
    for c = 1:nConditions
        trialRows = trials.Subject == subjects(s) & ...
            trials.Condition == conditions(c);
        meanRating = mean(trials.Annoyance(trialRows), 'omitnan');

        for h = 1:nHemispheres
            row = row + 1;
            Subject(row) = subjects(s);
            Condition(row) = conditions(c);
            Hemisphere(row) = hemispheres(h);
            MeanRating(row) = meanRating;
            MeanBrainResponse(row) = mean( ...
                processedAV(s).HbO(hemisphereMasks{h}, c), ...
                'omitnan') * 1e6;
        end
    end
end

pairTable = table(Subject, Condition, Hemisphere, MeanRating, ...
    MeanBrainResponse);

%% Scatter plots with separate least-squares fits
for h = 1:nHemispheres
    scatterFigure = figure('Color', 'w', ...
        'Position', [80 + 60 * (h - 1), 120, 720, 560]);
    scatterAxes = axes('Parent', scatterFigure);
    hold(scatterAxes, 'on');
    rows = pairTable.Hemisphere == hemispheres(h) & ...
        isfinite(pairTable.MeanRating) & ...
        isfinite(pairTable.MeanBrainResponse);
    xData = pairTable.MeanRating(rows);
    yData = pairTable.MeanBrainResponse(rows);

    scatter(scatterAxes, xData, yData, 65, ...
        annoyanceColor, 'filled', 'MarkerFaceAlpha', 0.75);

    % The p-value tests H0: the regression slope equals zero.
    linearModel = fitlm(xData, yData);
    intercept = linearModel.Coefficients.Estimate(1);
    slope = linearModel.Coefficients.Estimate(2);
    rSquared = linearModel.Rsquared.Ordinary;
    pValue = linearModel.Coefficients.pValue(2);

    xFit = linspace(min(xData), max(xData), 200)';
    yFit = predict(linearModel, xFit);
    plot(scatterAxes, xFit, yFit, ...
        'k-', 'LineWidth', 2.2);

    pLabel = sprintf('= %.3f', pValue);

    xlim(scatterAxes, [0, 4]);
    xlabel(scatterAxes, 'Annoyance rating');
    ylabel(scatterAxes, 'HbO response (\muM)', 'Interpreter', 'tex');
    text(scatterAxes, 0.05, 0.95, ...
        sprintf('%s: R^2 = %.3f, p %s', ...
        hemispheres(h), rSquared, pLabel), ...
        'Units', 'normalized', 'VerticalAlignment', 'top', ...
        'FontName', 'Arial', 'FontSize', 15);
    format_axes(scatterAxes);
    scatterAxes.YAxis.Exponent = -3;

    fprintf(['%s hemisphere fit: HbO = %.6f x rating %+.6f, ' ...
        'R^2 = %.4f, slope p = %.6g, N = %d\n'], ...
        hemispheres(h), slope, intercept, rSquared, pValue, ...
        linearModel.NumObservations);
end



% Local function
function format_axes(ax)
    set(ax, 'Box', 'off', 'TickDir', 'out', 'LineWidth', 1.3, ...
        'FontName', 'Arial', 'FontSize', 16, ...
        'XColor', 'k', 'YColor', 'k');
    ax.XLabel.FontSize = 18;
    ax.XLabel.FontWeight = 'bold';
    ax.YLabel.FontSize = 18;
    ax.YLabel.FontWeight = 'bold';
end


function trials = read_psychopy(folder)
    files = dir(fullfile(folder, 'CS*_Fingertapping_*.csv'));
    runColumns = ["trials.thisN", "trials_2.thisN", ...
        "trials_3.thisN", "trials_4.thisN", "trials_5.thisN"];
    trialTables = cell(numel(files), 1);

    for f = 1:numel(files)
        T = readtable(fullfile(files(f).folder, files(f).name), ...
            'VariableNamingRule', 'preserve', 'TextType', 'string');

        subject = string(regexp(files(f).name, ...
            'CS\d+', 'match', 'once'));
        category = lower(strtrim(string(T.("catogory"))));
        keep = ismember(category, ["unpleasant", "neutral", "trigger"]);

        runNumber = nan(height(T), 1);
        for r = 1:5
            marker = str2double(string(T.(runColumns(r))));
            runNumber(~isnan(marker)) = r;
        end

        condition = category(keep);
        condition(condition == "unpleasant") = "Unpleasant";
        condition(condition == "neutral") = "Neutral";
        condition(condition == "trigger") = "Trigger";
        annoyance = str2double(string(T.("slider1.response")));

        nTrials = sum(keep);
        trialTables{f} = table(repmat(subject, nTrials, 1), ...
            runNumber(keep), condition, annoyance(keep), ...
            'VariableNames', {'Subject', 'Run', 'Condition', 'Annoyance'});
    end

    trials = vertcat(trialTables{:});
    % CS05 run 5 was recorded without sound.
    trials(trials.Subject == "CS05" & trials.Run == 5, :) = [];
end
