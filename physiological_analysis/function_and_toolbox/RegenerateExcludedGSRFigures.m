function RegenerateExcludedGSRFigures( ...
        eda_output_path, response_window, selected_file_names)
    if nargin < 1
        eda_output_path = ...
            '/Users/zhoushibo/Desktop/Copy_of_data_GSR_test_raw/EDA_output';
    end
    if nargin < 2
        response_window = [1, 20];
    end
    if nargin < 3
        selected_file_names = strings(0, 1);
    else
        selected_file_names = string(selected_file_names(:));
    end

    excluded_path = fullfile(eda_output_path, '_Excluded');
    figure_path = fullfile(excluded_path, 'Figures');
    backup_path = fullfile(excluded_path, 'Figures_original');
    if ~isfolder(figure_path)
        mkdir(figure_path);
    end
    if ~isfolder(backup_path)
        mkdir(backup_path);
    end

    % Preserve every old PNG before replacing it.
    old_figures = dir(fullfile(figure_path, '*.png'));
    for i = 1:numel(old_figures)
        source = fullfile(figure_path, old_figures(i).name);
        backup = fullfile(backup_path, old_figures(i).name);
        if ~isfile(backup)
            copyfile(source, backup);
        end
    end

    files = dir(fullfile(excluded_path, '2025-*_CS*.mat'));
    if ~isempty(selected_file_names)
        files = files(ismember(string({files.name}), selected_file_names));
    end
    if isempty(files)
        error('No excluded CS MAT files were found in %s.', excluded_path);
    end

    for i = 1:numel(files)
        loaded = load(fullfile(excluded_path, files(i).name), ...
                      'data', 'analysis');
        data = loaded.data;
        analysis = loaded.analysis;

        h = figure('Visible', 'off', 'Color', 'w', ...
            'Units', 'pixels', 'Position', [60, 60, 1800, 1200]);

        subplot(3, 1, 1);
        plot(data.time, data.conductance, 'k', 'LineWidth', 1.4);
        title(files(i).name, 'Interpreter', 'none', ...
              'FontSize', 24, 'FontWeight', 'bold');
        xlim([data.time(1), data.time(end)]);
        ylim([0, 10]);
        grid on;
        set(gca, 'FontSize', 20, 'FontWeight', 'bold', ...
            'LineWidth', 1.5);

        subplot(3, 1, 2);
        plot(data.time, analysis.phasicData, 'b', 'LineWidth', 1.6);
        hold on;
        ylim([0, 2]);
        drawTrials(data.event, response_window);
        yline(0.05, 'k--', '0.05 \muS', ...
              'LabelHorizontalAlignment', 'left', ...
              'HandleVisibility', 'off');
        title('Skin Conductance Response (SCR)', ...
              'FontSize', 24, 'FontWeight', 'bold');
        ylabel('Conductance (\muS)', 'FontSize', 22, ...
               'FontWeight', 'bold');
        xlim([data.time(1), data.time(end)]);
        ylim([0, 2]);
        grid on;
        set(gca, 'FontSize', 20, 'FontWeight', 'bold', ...
            'LineWidth', 1.5);
        hold off;

        subplot(3, 1, 3);
        plot(data.time, analysis.tonicData, ...
             'Color', [0, 0.5, 0], 'LineWidth', 1.8);
        hold on;
        ylim([0, 10]);
        drawTrials(data.event, response_window);
        title('Skin Conductance Level (SCL)', ...
              'FontSize', 24, 'FontWeight', 'bold');
        xlabel('Time (s)', 'FontSize', 22, 'FontWeight', 'bold');
        xlim([data.time(1), data.time(end)]);
        ylim([0, 10]);
        grid on;
        set(gca, 'FontSize', 20, 'FontWeight', 'bold', ...
            'LineWidth', 1.5);
        hold off;

        linkaxes(findall(h, 'Type', 'axes'), 'x');
        [~, stem] = fileparts(files(i).name);
        destination = fullfile(figure_path, [stem, '_excluded.png']);
        exportgraphics(h, destination, 'Resolution', 300);
        close(h);
        fprintf('Regenerated %d/%d: %s\n', ...
                i, numel(files), destination);
    end
end

function drawTrials(events, response_window)
    y_limits = ylim;
    for k = 1:numel(events)
        onset = double(events(k).time);
        window_start = onset + response_window(1);
        window_end = onset + response_window(2);
        patch([window_start, window_end, window_end, window_start], ...
              [y_limits(1), y_limits(1), y_limits(2), y_limits(2)], ...
              'r', 'FaceAlpha', 0.08, 'EdgeColor', 'none', ...
              'HandleVisibility', 'off');
        xline(onset, 'r--', 'HandleVisibility', 'off');
    end
end
