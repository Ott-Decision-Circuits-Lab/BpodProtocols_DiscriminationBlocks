function LoadVariables(SourceFolder)
    % LoadVariables.m
    % Takes a folder, gathers all .mat files, and concatenates fields for pooled analysis.
    % Output: 'PooledData.mat' in the source folder containing SessionWiseData and TrialWiseData.
    
    % 1. Gather all .mat files in the folder
    Files = dir(fullfile(SourceFolder, '*.mat'));
    NumFiles = numel(Files);
    
    if NumFiles == 0
        error('No .mat files found in the specified folder.');
    end
    
    fprintf('Found %d data files. Processing...\n', NumFiles);
    
    % Initialize structures for pooled data
    PooledSessionWise = [];
    PooledTrialWise = [];
    
    % Variables for TrialWiseData (fields in SessionData.Custom.TrialData)
    TrialFields = {'DecisionVariable', 'ChoiceLeft', 'SampleLength', ...
                   'CatchTrial', 'Feedback', 'ChoiceCorrect', ...
                   'BlockNumber', 'LaserTrial', 'AudBias'};
    
    % Variables for SessionWiseData (Top-level or Custom/Sub-fields)
    % Note: RawEvents and BlockTable are handled specifically below
    SessionFields = {'Info.Subject', 'Info.SessionDate', 'SettingsFile.GUI.SumRates', ...
                     'SettingsFile.GUI.AuditoryStimulusTime', ...
                     'SettingsFile.GUI.BlockTable.AudLeftBias', ...
                     'SettingsFile.GUI.BlockTable.BlockLen', 'Custom.Pharmacology', ...
                     'Custom.BiasToFitIndexMap', 'Custom.FitIndexToColorMap'};
    
    % Loop through each file
    for iFile = 1:NumFiles
        Filename = fullfile(SourceFolder, Files(iFile).name);
        
        try
            % Load the file
            S = load(Filename);
            if ~isfield(S, 'SessionData')
                warning('File %s does not contain SessionData. Skipping.', Files(iFile).name);
                continue;
            end
            Data = S.SessionData;
            
            %% --- Handle SessionWiseData ---
            
            % 1. Initialize structure if empty
            if isempty(PooledSessionWise)
                % Initialize nSessions
                PooledSessionWise.nSessions = 0;
                
                % Cell arrays for metadata
                PooledSessionWise.Subject = {};
                PooledSessionWise.SessionDate = {};
                PooledSessionWise.SumRates = [];
                PooledSessionWise.AuditoryStimulusTime = [];
                PooledSessionWise.AudLeftBias = [];
                PooledSessionWise.BlockLen = [];
                PooledSessionWise.Pharmacology = {};
                
                % Check for raw events to init variables
                if isfield(Data, 'RawEvents') && ~isempty(Data.RawEvents.Trial)
                    PooledSessionWise.GracePeriods = {};
                    PooledSessionWise.GracePeriodsL = {};
                    PooledSessionWise.GracePeriodsR = {};
                end
            end
            
            % 2. Extract and Append SessionWise fields
            
            % Info
            if isfield(Data, 'Info')
                if isfield(Data.Info, 'Subject')
                    if isempty(PooledSessionWise.Subject)
                        PooledSessionWise.Subject = {Data.Info.Subject};
                    else
                        PooledSessionWise.Subject{end+1} = Data.Info.Subject;
                    end
                end
                if isfield(Data.Info, 'SessionDate')
                    if isempty(PooledSessionWise.SessionDate)
                        PooledSessionWise.SessionDate = {Data.Info.SessionDate};
                    else
                        PooledSessionWise.SessionDate{end+1} = Data.Info.SessionDate;
                    end
                end
            end
            
            % SettingsFile
            if isfield(Data, 'SettingsFile')
                if isfield(Data.SettingsFile, 'GUI')
                    if isfield(Data.SettingsFile.GUI, 'SumRates')
                        PooledSessionWise.SumRates(end+1) = Data.SettingsFile.GUI.SumRates;
                    end
                    if isfield(Data.SettingsFile.GUI, 'AuditoryStimulusTime')
                        PooledSessionWise.AuditoryStimulusTime(end+1) = Data.SettingsFile.GUI.AuditoryStimulusTime;
                    end
                    if isfield(Data.SettingsFile.GUI, 'BlockTable')
                        if isfield(Data.SettingsFile.GUI.BlockTable, 'AudLeftBias')
                            PooledSessionWise.AudLeftBias = cat(1, PooledSessionWise.AudLeftBias, Data.SettingsFile.GUI.BlockTable.AudLeftBias);
                        end
                        if isfield(Data.SettingsFile.GUI.BlockTable, 'BlockLen')
                            PooledSessionWise.BlockLen = cat(1, PooledSessionWise.BlockLen, Data.SettingsFile.GUI.BlockTable.BlockLen);
                        end
                    end
                end
            end
            
            % Custom Fields
            if isfield(Data, 'Custom')
                if isfield(Data.Custom, 'Pharmacology')
                    if isempty(PooledSessionWise.Pharmacology)
                        PooledSessionWise.Pharmacology = {Data.Custom.Pharmacology};
                    else
                        PooledSessionWise.Pharmacology{end+1} = Data.Custom.Pharmacology;
                    end
                end
                if isfield(Data.Custom, 'BiasToFitIndexMap')
                    PooledSessionWise.BiasToFitIndexMap = Data.Custom.BiasToFitIndexMap;
                end
                if isfield(Data.Custom, 'FitIndexToColorMap')
                    PooledSessionWise.FitIndexToColorMap = Data.Custom.FitIndexToColorMap;
                end
            end
            
            % RawEvents (Loop through trials to calculate Grace Periods)
            if isfield(Data, 'RawEvents') && ~isempty(Data.RawEvents.Trial)
                GP = [];
                GPL = [];
                GPR = [];
                % Safe iteration: use min of existing nTrials or RawEvents length
                nRawTrials = length(Data.RawEvents.Trial);
                
                for t = 1:nRawTrials
                    RStates = Data.RawEvents.Trial{t}.States;
                    
                    if isfield(RStates, 'rewarded_Rin_grace')
                        d = RStates.rewarded_Rin_grace(:,2) - RStates.rewarded_Rin_grace(:,1);
                        if ~isempty(d), GP = [GP; d]; end
                    end
                    if isfield(RStates, 'rewarded_Lin_grace')
                        d = RStates.rewarded_Lin_grace(:,2) - RStates.rewarded_Lin_grace(:,1);
                        if ~isempty(d), GP = [GP; d]; end
                    end
                    
                    % Side-specific Grace Periods
                    if isfield(Data.Custom, 'TrialData') && isfield(Data.Custom.TrialData, 'ChoiceLeft')
                        if t <= length(Data.Custom.TrialData.ChoiceLeft)
                            CL = Data.Custom.TrialData.ChoiceLeft(t);
                            if isfield(RStates, 'rewarded_Rin_grace') && CL == 0
                                d = RStates.rewarded_Rin_grace(:,2) - RStates.rewarded_Rin_grace(:,1);
                                if ~isempty(d), GPR = [GPR; d]; end
                            end
                            if isfield(RStates, 'rewarded_Lin_grace') && CL == 1
                                d = RStates.rewarded_Lin_grace(:,2) - RStates.rewarded_Lin_grace(:,1);
                                if ~isempty(d), GPL = [GPL; d]; end
                            end
                        end
                    end
                end
                PooledSessionWise.GracePeriods{end+1} = GP;
                PooledSessionWise.GracePeriodsL{end+1} = GPL;
                PooledSessionWise.GracePeriodsR{end+1} = GPR;
            end
            
            PooledSessionWise.nSessions = PooledSessionWise.nSessions + 1;
            
            %% --- Handle TrialWiseData ---
            
            % Ensure Custom.TrialData exists
            if ~isfield(Data, 'Custom') || ~isfield(Data.Custom, 'TrialData')
                warning('File %s is missing Custom.TrialData. Skipping TrialWise extraction.', Files(iFile).name);
                continue;
            end
            
            TrialData = Data.Custom.TrialData;
            
            % Initialize structure if empty
            if isempty(PooledTrialWise)
                PooledTrialWise.nTrialsArray = [];
                for k = 1:numel(TrialFields)
                    PooledTrialWise.(TrialFields{k}) = [];
                end
            end
            
            % Append fields
            currentNTrials = Data.nTrials;
            
            % Store nTrials for this session
            PooledTrialWise.nTrialsArray(end+1) = currentNTrials;
            
            for k = 1:numel(TrialFields)
                FieldName = TrialFields{k};
                if isfield(TrialData, FieldName)
                    val = TrialData.(FieldName);
                    %val = val(1:currentNTrials-1); % Last trial is aborted
                    % Ensure vectors are row vectors for horizontal concatenation
                    if isvector(val) && ~iscell(val)
                        val = val(:)'; 
                    end
                    PooledTrialWise.(FieldName) = [PooledTrialWise.(FieldName), val];
                else
                    % If field is missing, pad with NaNs (if numeric) or empty (if cell) to maintain structure
                    if isempty(PooledTrialWise.(FieldName))
                        % First file missing field, just leave empty
                    else
                        if iscell(PooledTrialWise.(FieldName))
                            PooledTrialWise.(FieldName) = [PooledTrialWise.(FieldName), cell(1, currentNTrials)];
                        else
                            PooledTrialWise.(FieldName) = [PooledTrialWise.(FieldName), nan(1, currentNTrials)];
                        end
                        warning('Field %s missing in %s. Padding with NaN/Empty.', FieldName, Files(iFile).name);
                    end
                end
            end
            
        catch ME
            warning('Error processing file %s: %s', Files(iFile).name, ME.message);
        end
    end
    
    %% --- Save Output ---
    
    SessionData.SessionWiseData = PooledSessionWise;
    SessionData.TrialWiseData = PooledTrialWise;
    
    OutputFilename = fullfile(SourceFolder, 'SessionData.mat');
    save(OutputFilename, 'SessionData');
    
    fprintf('Processing complete. Saved pooled data to %s\n', OutputFilename);
end