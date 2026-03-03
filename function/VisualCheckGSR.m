function VisualCheckGSR(data_path)
    bad_path = fullfile(data_path, '_Excluded');
    if ~exist(bad_path, 'dir'), mkdir(bad_path); end
    
    % Get files
    files = dir(fullfile(data_path, '*.mat'));
    files = files(~contains({files.name}, 'batchmode')); 

    %% 2. Loop
    for i = 1:length(files)
        name = files(i).name;
        full_name = fullfile(data_path, name);
        
        % Load Data
        tmp = load(full_name);
        d = tmp.data;
        a = tmp.analysis;

        % Plot
        h = figure('Name', name, 'Units', 'normalized', 'Position', [0.1 0.1 0.8 0.8]);
        
        % Raw & Tonic
        subplot(3,1,1); 
        plot(d.time, d.conductance, 'k', d.time, a.tonicData, 'g', 'LineWidth', 2);
        title(name, 'Interpreter', 'none'); axis tight;

        % Phasic & Events
        subplot(3,1,2); 
        plot(d.time, a.phasicData, 'b'); hold on;
        yl = ylim;
        for k = 1:length(d.event) % Draw events
            t = d.event(k).time;
            xline(t, 'r--');
            patch([t t+15 t+15 t], [yl(1) yl(1) yl(2) yl(2)], 'r', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
        end
        title('Phasic');

        % Driver
        subplot(3,1,3); 
        stem(d.time, a.driver, 'm', 'Marker', 'none');
        title('Driver'); linkaxes(findall(h, 'type', 'axes'), 'x');

        % Action
        commandwindow;
        choice = input(sprintf('[%d/%d] Keep? (Enter=Yes, n=No, q=Quit): ', i, length(files)), 's');

        if strcmpi(choice, 'n')
            movefile(full_name, bad_path);
            movefile(fullfile(data_path, strrep(name, '.mat', '_era.xls')), bad_path);
            disp('Excluded.');
        elseif strcmpi(choice, 'q')
            close(h); break;
        end
        close(h);
    end
end