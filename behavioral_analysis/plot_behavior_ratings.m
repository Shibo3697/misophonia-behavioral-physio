%% Behavioral ratings: repeated-measures ANOVA and plotting
clc; clear; close all
folder = fileparts(mfilename('fullpath'));
files = dir(fullfile(folder, 'CS*_Fingertapping_*.csv'));
runColumns = ["trials.thisN", "trials_2.thisN", "trials_3.thisN", ...
              "trials_4.thisN", "trials_5.thisN"];
allTrials = table();

%% Extract trial data
for f = 1:numel(files)
    T = readtable(fullfile(files(f).folder, files(f).name), ...
        'VariableNamingRule', 'preserve', 'TextType', 'string');
    subject = string(regexp(files(f).name, 'CS\d+', 'match', 'once'));
    category = lower(strtrim(string(T.("catogory"))));
    keep = ismember(category, ["trigger", "unpleasant", "neutral"]);

    % PsychoPy writes each run's loop counter to a different column.
    runNumber = nan(height(T), 1);
    for r = 1:5
        marker = str2double(string(T.(runColumns(r))));
        runNumber(~isnan(marker)) = r;
    end

    annoyance = str2double(string(T.("slider1.response")));
    antisocial = str2double(string(T.("slider2.response")));
    n = sum(keep);
    allTrials = [allTrials; table( ... %#ok<AGROW>
        repmat(subject, n, 1), runNumber(keep), category(keep), ...
        annoyance(keep), antisocial(keep), ...
        'VariableNames', {'Subject', 'Run', 'Category', ...
        'Annoyance', 'Antisocial'})];
end

allTrials.Category = categorical(allTrials.Category, ...
    ["trigger", "unpleasant", "neutral"], ...
    ["Trigger", "Unpleasant", "Neutral"]);

%% Remove CS05 Run 5
remove = allTrials.Subject == "CS05" & allTrials.Run == 5;
fprintf('\nRemoved %d trial(s) from CS05 Run 5.\n', sum(remove));
allTrials(remove, :) = [];

%% Quality control and subject-condition means
subjects = sort(unique(allTrials.Subject));
conditions = ["Trigger", "Unpleasant", "Neutral"];
nSubjects = numel(subjects);
annoyanceMeans = nan(nSubjects, 3);
antisocialMeans = nan(nSubjects, 3);

fprintf('\nDATA QUALITY CHECK\n');
fprintf('%-9s %6s %8s %10s %12s %9s %11s %12s\n', ...
    'Subject', 'Runs', 'Trials', 'Trigger', 'Unpleasant', 'Neutral', ...
    'MissAnnoy', 'MissAntisoc');

for s = 1:nSubjects
    subjectRows = allTrials.Subject == subjects(s);
    counts = zeros(1, 3);
    for c = 1:3
        rows = subjectRows & string(allTrials.Category) == conditions(c);
        counts(c) = sum(rows);
        annoyanceMeans(s, c) = mean(allTrials.Annoyance(rows), 'omitnan');
        antisocialMeans(s, c) = mean(allTrials.Antisocial(rows), 'omitnan');
    end
    fprintf('%-9s %6d %8d %10d %12d %9d %11d %12d\n', ...
        char(subjects(s)), numel(unique(allTrials.Run(subjectRows))), ...
        sum(subjectRows), counts(1), counts(2), counts(3), ...
        sum(subjectRows & isnan(allTrials.Annoyance)), ...
        sum(subjectRows & isnan(allTrials.Antisocial)));
end

%% Assumptions, ANOVA, and post-hoc tests
annoyanceStats = analyzeRating(annoyanceMeans, 'Annoyance');
antisocialStats = analyzeRating(antisocialMeans, 'Antisocial');

%% Plot both ratings together: mean +/- SEM
figure('Color', 'w', 'Name', 'Behavioral ratings', ...
    'Position', [100, 100, 700, 540]);
plotRatingsTogether(annoyanceMeans, antisocialMeans, ...
    annoyanceStats, antisocialStats);


function result = analyzeRating(values, name)
    alpha = 0.05;
    pairs = [1, 2; 1, 3; 2, 3];
    labels = ["Trigger vs Unpleasant"; ...
              "Trigger vs Neutral"; ...
              "Unpleasant vs Neutral"];

    fprintf('\n============================================================\n');
    fprintf('%s RATING (n = %d)\n', upper(name), size(values, 1));
    fprintf('============================================================\n');
    categoryNames = ["Trigger"; "Unpleasant"; "Neutral"];
    fprintf('\nNormality of each category (Lilliefors test):\n');
    anyRejected = false;
    for k = 1:3
        [rejected, pNormal] = lillietest(values(:, k));
        anyRejected = anyRejected || rejected;
        conclusion = 'not rejected';
        if rejected, conclusion = 'rejected'; end
        fprintf('  %-12s p = %.4g  (normality %s)\n', ...
            char(categoryNames(k)), pNormal, conclusion);
    end
    if anyRejected
        warning('%s: at least one category failed normality.', name);
    end

    wide = array2table(values, ...
        'VariableNames', {'Trigger', 'Unpleasant', 'Neutral'});
    within = table(categorical({'Trigger'; 'Unpleasant'; 'Neutral'}), ...
        'VariableNames', {'Category'});
    model = fitrm(wide, 'Trigger-Neutral ~ 1', 'WithinDesign', within);
    A = ranova(model, 'WithinModel', 'Category');
    M = mauchly(model);

    % ranova also returns the intercept test; select the Category rows.
    rowNames = string(A.Properties.RowNames);
    effectRow = rowNames == "(Intercept):Category";
    errorRow = rowNames == "Error(Category)";
    F = A.F(effectRow);
    df = [A.DF(effectRow), A.DF(errorRow)];
    fprintf('\nMauchly test: W = %.4f, p = %.4g\n', M.W(1), M.pValue(1));

    % Correct the p value and both degrees of freedom if sphericity fails.
    if M.pValue(1) < alpha
        epsilonTable = epsilon(model);
        E = epsilonTable.GreenhouseGeisser(1);
        p = A.pValueGG(effectRow);
        df = df * E;
        correction = 'Greenhouse-Geisser corrected';
    else
        p = A.pValue(effectRow);
        correction = 'sphericity assumed';
    end
    fprintf('Repeated-measures ANOVA (%s):\n', correction);
    fprintf('  F(%.3g, %.3g) = %.4f, p = %.4g\n', df(1), df(2), F, p);

    adjustedP = nan(3, 1);
    stars = repmat("ns", 3, 1);
    if p < alpha
        rawP = nan(3, 1);
        t = nan(3, 1);
        tdf = nan(3, 1);
        for k = 1:3
            [~, rawP(k), ~, test] = ttest( ...
                values(:, pairs(k, 1)), values(:, pairs(k, 2)));
            t(k) = test.tstat;
            tdf(k) = test.df;
        end

        % Bonferroni correction for the three pairwise tests.
        adjustedP = min(rawP * 3, 1);
        stars(adjustedP < 0.05) = "*";
        stars(adjustedP < 0.01) = "**";
        stars(adjustedP < 0.001) = "***";

        fprintf('\nPaired post-hoc comparisons (Bonferroni corrected):\n');
        for k = 1:3
            fprintf('  %-26s t(%d) = %7.3f, raw p = %.4g, Bonferroni p = %.4g %s\n', ...
                char(labels(k)), tdf(k), t(k), rawP(k), adjustedP(k), char(stars(k)));
        end
    else
        fprintf('\nOmnibus ANOVA is not significant; post-hoc tests were not run.\n');
    end

    result = struct('F', F, 'df', df, 'p', p, 'pairs', pairs, ...
        'adjustedP', adjustedP, 'stars', stars);
end


function plotRatingsTogether(annoyance, antisocial, ...
        annoyanceStats, antisocialStats)
    % Blue for annoyance and red for antisocial ratings.
    colors = [0.12, 0.47, 0.71; ...
              0.84, 0.15, 0.16];
    edgeColors = [0.07, 0.29, 0.45; ...
                  0.52, 0.08, 0.09];
    groupMean = [mean(annoyance, 1); mean(antisocial, 1)]';
    groupSEM = [std(annoyance, 0, 1) / sqrt(size(annoyance, 1)); ...
        std(antisocial, 0, 1) / sqrt(size(antisocial, 1))]';

    % Draw the two series at explicit x positions so wider bars retain a
    % visible gap instead of touching or overlapping within each category.
    groupX = 1:3;
    barWidth = 0.40;
    barOffset = [-0.24, 0.24];
    bars = gobjects(2, 1);
    hold on;
    for r = 1:2
        bars(r) = bar(groupX + barOffset(r), groupMean(:, r)', ...
            barWidth, 'FaceColor', colors(r, :), ...
            'EdgeColor', edgeColors(r, :), 'LineWidth', 1.2);
    end

    x = [groupX + barOffset(1); groupX + barOffset(2)];
    for r = 1:2
        errorbar(x(r, :), groupMean(:, r)', groupSEM(:, r)', ...
            'k', 'LineStyle', 'none', 'LineWidth', 1.6, 'CapSize', 10);
    end

    % Stack significant comparisons from the two ratings above the bars.
    statistics = {annoyanceStats, antisocialStats};
    base = max(groupMean(:) + groupSEM(:)) + 0.15;
    level = 0;
    for r = 1:2
        significant = find(statistics{r}.adjustedP < 0.05);
        for k = 1:numel(significant)
            level = level + 1;
            comparison = significant(k);
            pair = statistics{r}.pairs(comparison, :);
            pairX = x(r, pair);
            y = base + (level - 1) * 0.28;
            plot([pairX(1), pairX(1), pairX(2), pairX(2)], ...
                [y, y + 0.06, y + 0.06, y], ...
                'Color', colors(r, :), 'LineWidth', 1.4);
            text(mean(pairX), y + 0.09, ...
                char(statistics{r}.stars(comparison)), ...
                'Color', colors(r, :), 'HorizontalAlignment', 'center', ...
                'FontWeight', 'bold', 'FontSize', 16, ...
                'FontName', 'Arial', 'Interpreter', 'none');
        end
    end

    ylim([0, max(4.2, base + level * 0.28 + 0.18)]);
    xlim([0.4, 3.6]);
    xticks(1:3);
    xticklabels({'Trigger', 'Unpleasant', 'Neutral'});
    xtickangle(0);
    yticks(0:4);
    yLabel = ylabel('Rating (0-4)', 'FontSize', 18, 'FontWeight', 'bold', ...
        'FontName', 'Arial', 'Interpreter', 'none');
    yLabel.Units = 'normalized';
    yLabel.Position(1) = yLabel.Position(1) - 0.015;
    legendHandle = legend(bars, {'Annoyance', 'Antisocial'}, ...
        'Location', 'northwest', 'Box', 'off', 'FontSize', 16, ...
        'TextColor', [0.15, 0.15, 0.15]);
    legendHandle.ItemTokenSize = [24, 14];
    set(gca, 'Box', 'off', 'TickDir', 'out', 'LineWidth', 1.4, ...
        'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Arial', ...
        'TickLabelInterpreter', 'none', 'XColor', 'k', 'YColor', 'k');
end
