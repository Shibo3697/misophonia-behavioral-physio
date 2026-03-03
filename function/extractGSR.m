
clc; clear; close all;


raw_data_folder = 'C:\Users\admin\Desktop\misophonia data\data_raw';
output_folder   = 'C:\Users\admin\Desktop\misophonia data\data_GSR_test';
if ~exist(output_folder, 'dir'), mkdir(output_folder); end

% Trigger Map: 2 = Unpleasant, 4 = Neutral, 8 = Trigger
trigger_map = containers.Map({2, 4, 8}, {'unpleasant', 'neutral', 'trigger'});

% Calculate Sampling Rate for Triggers
t1 = datetime('14:46:49.170007', 'InputFormat', 'HH:mm:ss.SSSSSS');
t2 = datetime('14:56:30.294098', 'InputFormat', 'HH:mm:ss.SSSSSS');
total_seconds = seconds(t2 - t1);
fq_tri = (5487 - 420) / total_seconds; 

%% Processing
% Find all session folders
session_list = dir(fullfile(raw_data_folder, '2025-*'));
session_list = session_list([session_list.isdir]); 

for s = 1:length(session_list)
    % Session Name (e.g., "2025-10-28 CS11")
    session_name = session_list(s).name;
    session_path = fullfile(raw_data_folder, session_name);
    
    parts = strsplit(session_name, ' '); 
    date_str = parts{1};   % "2025-10-28"
    subj_str = parts{2};   % "CS11"
    
    fprintf('\n===== Processing: %s (%s) =====\n', subj_str, date_str);

    % Find Run Folders inside this session
    run_list = dir(fullfile(session_path, '2025-*_*'));
    run_list = run_list([run_list.isdir]);

    % Loop through runs
    for r = 1:length(run_list)
        run_folder_name = run_list(r).name;
        run_path = fullfile(session_path, run_folder_name);
        
        run_parts = strsplit(run_folder_name, '_');
        run_num = run_parts{end}; % Take the last part ("003")
        
        zip_file = fullfile(run_path, [run_folder_name '.zip']);
        tri_file = fullfile(run_path, [run_folder_name '.tri']);

        %% Unzip and Load WINGS files (GSR)
        temp_dir = fullfile(run_path, '_temp_processing');
        if exist(temp_dir, 'dir'), rmdir(temp_dir, 's'); end 
        mkdir(temp_dir);
        
        try
            unzip(zip_file, temp_dir);
            
            % Find the .wings file
            wings_search = dir(fullfile(temp_dir, '*.wings'));
            if isempty(wings_search), error('No .wings file found'); 
            end
            wings_path = fullfile(wings_search(1).folder, wings_search(1).name);
            
            % Read WINGS file
            raw_table = readtable(wings_path, 'FileType', 'text', 'Delimiter', ';');
            
            % 1. Padding to ensure it starts at 0
            dt = raw_table.SecondsSinceRunStart(2) - raw_table.SecondsSinceRunStart(1);
            n_pad = round(raw_table.SecondsSinceRunStart(1) / dt);
            
            pad_gsr = zeros(n_pad, 1);
            pad_time = (0:dt:(n_pad - 1) * dt)';
            
            final_time = [pad_time; raw_table.SecondsSinceRunStart];
            final_gsr  = [pad_gsr;  raw_table.GSR];

            % 2. Process Triggers (.tri file)
            tri_table = readtable(tri_file, 'FileType', 'text', 'Delimiter', ';', 'ReadVariableNames', false);
            trig_idx = tri_table.Var2;
            trig_val = tri_table.Var5;
            event_times = trig_idx / fq_tri; % Convert sample index to seconds

            % 3. Create Ledalab Structure
            data = struct();
            data.time = final_time;
            data.conductance = final_gsr;
            data.timeoff = 15; 
            
            % Create Events
            num_events = length(event_times);
            data.event = struct('time', [], 'nid', [], 'name', [], 'userdata', []);
            
            for k = 1:num_events
                code = trig_val(k);
                if isKey(trigger_map, code)
                    name_str = trigger_map(code);
                else
                    name_str = 'unknown';
                end
                
                data.event(k).time = event_times(k);
                data.event(k).nid  = double(code);
                data.event(k).name = name_str;
                data.event(k).userdata = [];
            end
            
            % 4. Save File
            new_filename = [date_str '_' subj_str '_' run_num '.mat'];
            save_path = fullfile(output_folder, new_filename);
            save(save_path, 'data');
            fprintf('  Saved: %s\n', new_filename);

        % Clean up temp folder
        if exist(temp_dir, 'dir')
            rmdir(temp_dir, 's');
        end
    end
    end
end
disp(' ');
disp('All Done!');