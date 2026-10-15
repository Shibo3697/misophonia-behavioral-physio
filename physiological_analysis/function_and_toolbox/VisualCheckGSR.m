function review_aborted = VisualCheckGSR(data_path, response_window)
    if nargin < 2
        response_window = [1, 20];
    end

    review_aborted = false;
    excluded_path = fullfile(data_path, '_Excluded');
    if ~isfolder(excluded_path)
        mkdir(excluded_path);
    end
    excluded_figure_path = fullfile(excluded_path, 'Figures');
    if ~isfolder(excluded_figure_path)
        mkdir(excluded_figure_path);
    end

    files = dir(fullfile(data_path, '2025-*_CS*.mat'));
    if isempty(files)
        error('No processed CS MAT files were found in %s.', data_path);
    end

    % Fixed y-axis ranges are used for every run and exported figure.
    y_limits.raw = [0, 10];
    y_limits.phasic = [0, 2];
    y_limits.tonic = [0, 10];

    for i = 1:numel(files)
        name = files(i).name;
        mat_path = fullfile(data_path, name);
        loaded = load(mat_path, 'data', 'analysis');
        if ~isfield(loaded, 'data') || ~isfield(loaded, 'analysis')
            error('Processed data or CDA analysis is missing from %s.', name);
        end
        data = loaded.data;
        analysis = loaded.analysis;

        figure_handle = figure('Name', name, 'Color', 'w', ...
            'Units', 'pixels', 'Position', [60, 60, 1800, 1200]);

        subplot(3, 1, 1);
        plot(data.time, data.conductance, 'k', 'LineWidth', 1.4);
        title(name, 'Interpreter', 'none', 'FontSize', 24, ...
              'FontWeight', 'bold');
        axis tight;
        ylim(y_limits.raw);
        grid on;
        set(gca, 'FontSize', 20, 'FontWeight', 'bold', ...
            'LineWidth', 1.5);

        subplot(3, 1, 2);
        plot(data.time, analysis.phasicData, 'b', 'LineWidth', 1.6);
        hold on;
        ylim(y_limits.phasic);
        drawTrials(data.event, response_window);
        yline(0.05, 'k--', '0.05 \muS', ...
              'LabelHorizontalAlignment', 'left', ...
              'HandleVisibility', 'off');
        title('Skin Conductance Response (SCR)', ...
              'FontSize', 24, 'FontWeight', 'bold');
        ylabel('Conductance (\muS)', 'FontSize', 22, ...
               'FontWeight', 'bold');
        xlim([data.time(1), data.time(end)]);
        ylim(y_limits.phasic);
        grid on;
        set(gca, 'FontSize', 20, 'FontWeight', 'bold', ...
            'LineWidth', 1.5);
        hold off;

        subplot(3, 1, 3);
        plot(data.time, analysis.tonicData, ...
             'Color', [0, 0.5, 0], 'LineWidth', 1.8);
        hold on;
        ylim(y_limits.tonic);
        drawTrials(data.event, response_window);
        title('Skin Conductance Level (SCL)', ...
              'FontSize', 24, 'FontWeight', 'bold');
        xlabel('Time (s)', 'FontSize', 22, 'FontWeight', 'bold');
        xlim([data.time(1), data.time(end)]);
        ylim(y_limits.tonic);
        grid on;
        set(gca, 'FontSize', 20, 'FontWeight', 'bold', ...
            'LineWidth', 1.5);
        hold off;

        linkaxes(findall(figure_handle, 'Type', 'axes'), 'x');
        commandwindow;
        choice = input(sprintf( ...
            '[%d/%d] Keep %s? Enter=yes, n=exclude, q=abort: ', ...
            i, numel(files), name), 's');

        if strcmpi(strtrim(choice), 'n')
            era_name = strrep(name, '.mat', '_era.txt');
            era_path = fullfile(data_path, era_name);
            if ~isfile(era_path)
                close(figure_handle);
                error('Cannot find the paired ERA file: %s', era_path);
            end

            [~, figure_stem] = fileparts(name);
            figure_path = fullfile( ...
                excluded_figure_path, [figure_stem, '_excluded.png']);
            if isfile(figure_path)
                close(figure_handle);
                error('Excluded-run figure already exists: %s', figure_path);
            end
            exportgraphics(figure_handle, figure_path, 'Resolution', 300);

            movefile(mat_path, fullfile(excluded_path, name));
            try
                movefile(era_path, fullfile(excluded_path, era_name));
            catch move_error
                movefile(fullfile(excluded_path, name), mat_path);
                close(figure_handle);
                rethrow(move_error);
            end
            fprintf('Excluded: %s\nSaved figure: %s\n', name, figure_path);
        elseif strcmpi(strtrim(choice), 'q')
            review_aborted = true;
            close(figure_handle);
            return;
        end
        close(figure_handle);
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
