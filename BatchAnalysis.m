function FigHandle = BatchAnalysis(Folders, DrugNames)
    % BatchAnalysis.m
    % Loads multiple folders and creates a single comparison figure.
    %
    % Inputs:
    %   Folders   - Cell array of folder paths containing individual .mat files
    %   DrugNames - Cell array of drug names for legend/titles
    %
    % Example:
    %   Folders = {'C:\Data\PBS', 'C:\Data\Psilocybin'};
    %   DrugNames = {'PBS', 'Psilocybin'};
    %   BatchAnalysis(Folders, DrugNames);
    
    if nargin < 2
        DrugNames = repmat({''}, size(Folders));
    end
    
    nConditions = numel(Folders);
    
    %% Step 1: Load and concatenate all folders
    AllSessionData = cell(1, nConditions);
    
    for iFolder = 1:nConditions
        SourceFolder = Folders{iFolder};
        fprintf('\n=== Loading Folder %d/%d: %s (%s) ===\n', ...
                iFolder, nConditions, SourceFolder, DrugNames{iFolder});
        AllSessionData{iFolder} = LoadAndConcatenate(SourceFolder);
    end
    
    %% Step 2: Create single comparison figure
    FigHandle = RunComparisonAnalysis(AllSessionData, DrugNames);
    
    fprintf('\nBatch analysis complete.\n');
end

function SessionData = LoadAndConcatenate(SourceFolder)
    % Gather all .mat files in the folder
    Files = dir(fullfile(SourceFolder, '*.mat'));
    Files = Files(~strcmp({Files.name}, 'SessionData.mat'));
    NumFiles = numel(Files);
    
    if NumFiles == 0
        error('No .mat files found in: %s', SourceFolder);
    end
    
    fprintf('Found %d data files. Processing...\n', NumFiles);
    
    PooledSessionWise = [];
    PooledTrialWise = [];
    
    TrialFields = {'DecisionVariable', 'ChoiceLeft', 'SampleLength', ...
                   'CatchTrial', 'Feedback', 'ChoiceCorrect', ...
                   'BlockNumber', 'LaserTrial', 'AudBias'};
    
    for iFile = 1:NumFiles
        Filename = fullfile(SourceFolder, Files(iFile).name);
        
        try
            S = load(Filename);
            if ~isfield(S, 'SessionData')
                continue;
            end
            Data = S.SessionData;
            
            %% --- SessionWiseData ---
            if isempty(PooledSessionWise)
                PooledSessionWise.nSessions = 0;
                PooledSessionWise.Subject = {};
                PooledSessionWise.SessionDate = {};
                PooledSessionWise.SumRates = [];
                PooledSessionWise.AuditoryStimulusTime = [];
                PooledSessionWise.AudLeftBias = [];
                PooledSessionWise.BlockLen = [];
                PooledSessionWise.Pharmacology = {};
            end
            
            if isfield(Data, 'Info')
                if isfield(Data.Info, 'Subject')
                    PooledSessionWise.Subject{end+1} = Data.Info.Subject;
                end
                if isfield(Data.Info, 'SessionDate')
                    PooledSessionWise.SessionDate{end+1} = Data.Info.SessionDate;
                end
            end
            
            if isfield(Data, 'SettingsFile') && isfield(Data.SettingsFile, 'GUI')
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
            
            if isfield(Data, 'Custom')
                if isfield(Data.Custom, 'Pharmacology')
                    PooledSessionWise.Pharmacology{end+1} = Data.Custom.Pharmacology;
                end
                if isfield(Data.Custom, 'BiasToFitIndexMap')
                    PooledSessionWise.BiasToFitIndexMap = Data.Custom.BiasToFitIndexMap;
                end
                if isfield(Data.Custom, 'FitIndexToColorMap')
                    PooledSessionWise.FitIndexToColorMap = Data.Custom.FitIndexToColorMap;
                end
            end
            
            PooledSessionWise.nSessions = PooledSessionWise.nSessions + 1;
            
            %% --- TrialWiseData ---
            if ~isfield(Data, 'Custom') || ~isfield(Data.Custom, 'TrialData')
                continue;
            end
            
            TrialData = Data.Custom.TrialData;
            
            if isempty(PooledTrialWise)
                PooledTrialWise.nTrialsArray = [];
                for k = 1:numel(TrialFields)
                    PooledTrialWise.(TrialFields{k}) = [];
                end
            end
            
            currentNTrials = Data.nTrials;
            PooledTrialWise.nTrialsArray(end+1) = currentNTrials;
            
            for k = 1:numel(TrialFields)
                FieldName = TrialFields{k};
                if isfield(TrialData, FieldName)
                    val = TrialData.(FieldName);
                    if isvector(val) && ~iscell(val)
                        val = val(:)';
                    end
                    PooledTrialWise.(FieldName) = [PooledTrialWise.(FieldName), val];
                else
                    if ~isempty(PooledTrialWise.(FieldName))
                        if iscell(PooledTrialWise.(FieldName))
                            PooledTrialWise.(FieldName) = [PooledTrialWise.(FieldName), cell(1, currentNTrials)];
                        else
                            PooledTrialWise.(FieldName) = [PooledTrialWise.(FieldName), nan(1, currentNTrials)];
                        end
                    end
                end
            end
            
        catch ME
            warning('Error processing %s: %s', Files(iFile).name, ME.message);
        end
    end
    
    SessionData.SessionWiseData = PooledSessionWise;
    SessionData.TrialWiseData = PooledTrialWise;
    
    OutputFilename = fullfile(SourceFolder, 'SessionData.mat');
    save(OutputFilename, 'SessionData');
    fprintf('Saved pooled data to %s\n', OutputFilename);
end

function FigHandle = RunComparisonAnalysis(AllSessionData, DrugNames)
    nConditions = numel(AllSessionData);
    
    %% Setup figure
    FigHandle = figure('Name', 'Drug Comparison', 'Position', [100 100 1200 500]);
    FigHandle = tiledlayout(FigHandle, 'flow');
    FigHandle.TileSpacing = 'tight';
    FigHandle.Padding = 'tight';
    
    %% Build title
    RatIDs = {};
    dateRanges = {};
    for iCond = 1:nConditions
        SD = AllSessionData{iCond};
        RatIDs{end+1} = unique(SD.SessionWiseData.Subject);
        dateRanges{end+1} = strcat(string(SD.SessionWiseData.SessionDate{1}), " - ", ...
                                    string(SD.SessionWiseData.SessionDate{end}));
    end
    
    titleStr = sprintf("DiscriminationBlocks Comparison: ");
    for iCond = 1:nConditions
        if iCond > 1
            titleStr = strcat(titleStr, " vs ");
        end
        titleStr = strcat(titleStr, sprintf("%s (R%d, %s)", DrugNames{iCond}, ...
                     str2double(RatIDs{iCond}{1}), dateRanges{iCond}));
    end
    sgtitle(titleStr, 'FontSize', 12);
    
    %% Define visual styles per condition
    % Block colors (shared across conditions)
    unbiasedColor = [0, 0, 0];        % Black
    leftBiasColor = [1, 0, 0];        % Red
    rightBiasColor = [0, 0, 1];       % Blue
    lastBlockColor = [0.5, 0.5, 0.5];  % Gray
    BlockColors = [unbiasedColor; leftBiasColor; rightBiasColor; lastBlockColor];
    BlockNames = {'Unbiased (Start)', 'Left Bias', 'Right Bias', 'Unbiased (End)'};
    
    % Condition styles (line style, marker, marker face)
    CondLineStyles = {'-', '--', ':', '-.'};
    CondMarkers = {'o', 's', 'd', '^'};
    CondMarkerFace = {'f', 'n', 'f', 'n'}; % 'f' = filled, 'n' = none
    
    %% Psychometric Plot - Comparison
    nexttile(FigHandle);
    hold on
    
    AudBin = 7;
    legendEntries = {};
    legendHandles = {};
    
    for iCond = 1:nConditions
        SD = AllSessionData{iCond};
        
        DV = SD.TrialWiseData.DecisionVariable;
        ChoiceLeft = SD.TrialWiseData.ChoiceLeft;
        Feedback = SD.TrialWiseData.Feedback;
        Correct = SD.TrialWiseData.ChoiceCorrect;
        BlockNumber = SD.TrialWiseData.BlockNumber;
        AudBias = SD.TrialWiseData.AudBias;
        CompletedTrials = (Feedback & Correct == 1) | (Correct == 0);
        
        DV_Completed = DV(CompletedTrials);
        commonBinEdges = linspace(min(DV_Completed) - 10*eps, max(DV_Completed) + 10*eps, AudBin + 1);
        
        % Aggregate by block type
        AllDVs = cell(1, 4);
        Choices = cell(1, 4);
        for i = 1:4
            AllDVs{i} = [];
            Choices{i} = [];
        end
        
        SessionIndices = cumsum([0, SD.TrialWiseData.nTrialsArray]);
        nSessions = SD.SessionWiseData.nSessions;
        
        for s = 1:nSessions
            idxStart = SessionIndices(s) + 1;
            idxEnd = SessionIndices(s + 1);
            currentSessionIdx = idxStart:idxEnd;
            
            SessionBias = AudBias(currentSessionIdx);
            SessionBlockNum = BlockNumber(currentSessionIdx);
            SessionDV = DV(currentSessionIdx);
            SessionChoice = ChoiceLeft(currentSessionIdx);
            
            sessionBlocks = unique(SessionBlockNum);
            
            for b = sessionBlocks
                blockMask = (SessionBlockNum == b);
                blockBias = unique(SessionBias(blockMask));
                
                if isempty(blockBias) || any(isnan(blockBias))
                    continue;
                end
                
                blockIdx = [];
                if all(blockBias == 0.5)
                    if b == 1
                        blockIdx = 1;
                    elseif b == 4
                        blockIdx = 4;
                    else
                        blockIdx = 1;
                    end
                elseif all(blockBias > 0.5)
                    blockIdx = 2;
                elseif all(blockBias < 0.5)
                    blockIdx = 3;
                end
                
                if ~isempty(blockIdx)
                    BlockDVs = SessionDV(blockMask);
                    BlockChoices = SessionChoice(blockMask);
                    validMask = ~isnan(BlockDVs) & ~isnan(BlockChoices);
                    AllDVs{blockIdx} = [AllDVs{blockIdx}, BlockDVs(validMask)];
                    Choices{blockIdx} = [Choices{blockIdx}, BlockChoices(validMask)];
                end
            end
        end
        
        % Plot aggregated curves for this condition
        ls = CondLineStyles{min(iCond, numel(CondLineStyles))};
        mk = CondMarkers{min(iCond, numel(CondMarkers))};
        mf = CondMarkerFace{min(iCond, numel(CondMarkerFace))};

        % Build legend entries as a string array (not a cell array)
        legendEntries = strings(0);
        legendHandles = gobjects(0);
        
        for iBlock = 1:4
            if ~isempty(AllDVs{iBlock}) && sum(~isnan(AllDVs{iBlock})) > 4
                BinIdx = discretize(AllDVs{iBlock}, commonBinEdges);
                PsycY = grpstats(Choices{iBlock}, BinIdx, 'mean');
                PsycX = grpstats(AllDVs{iBlock}, BinIdx, 'mean');
                
                hPoints = plot(PsycX, PsycY, mk, 'MarkerFaceColor', BlockColors(iBlock, :), ...
                     'MarkerEdgeColor', BlockColors(iBlock, :), 'MarkerSize', 6, ...
                     'LineStyle', 'none');
                
                XFit = linspace(min(AllDVs{iBlock}) - 10*eps, max(AllDVs{iBlock}) + 10*eps, 100);
                YFit = glmval(glmfit(AllDVs{iBlock}, Choices{iBlock}', 'binomial'), XFit, 'logit');
                hFit = plot(XFit, YFit, ls, 'Color', BlockColors(iBlock, :), 'LineWidth', 1.5);
                
                % Build legend entry as a string scalar
                entry = [char(DrugNames{iCond}), ' - ', char(BlockNames{iBlock})];
                legendEntries(end+1) = string(entry);
                legendHandles(end+1) = hFit;
            end
        end
    end
    
    xlabel('DV');
    ylabel('p left');
    % Call legend with string array
    if ~isempty(legendHandles)
        legend(legendHandles, legendEntries, 'Location', 'best', 'FontSize', 8);
    end
    hold off
    
    %% Collapsed Unbiased Psychometric Figure
    nexttile(FigHandle);
    hold on
    
    % 3 colors: Black (unbiased), Red (left), Blue (right)
    CollapsedColors = [unbiasedColor; leftBiasColor; rightBiasColor];
    CollapsedNames = {'Unbiased', 'Left Bias', 'Right Bias'};
    
    legendEntries_collapsed = strings(0);
    legendHandles_collapsed = gobjects(0);
    
    for iCond = 1:nConditions
        SD = AllSessionData{iCond};
        
        DV = SD.TrialWiseData.DecisionVariable;
        ChoiceLeft = SD.TrialWiseData.ChoiceLeft;
        Feedback = SD.TrialWiseData.Feedback;
        Correct = SD.TrialWiseData.ChoiceCorrect;
        BlockNumber = SD.TrialWiseData.BlockNumber;
        AudBias = SD.TrialWiseData.AudBias;
        CompletedTrials = (Feedback & Correct == 1) | (Correct == 0);
        
        DV_Completed = DV(CompletedTrials);
        binEdges = linspace(min(DV_Completed) - 10*eps, max(DV_Completed) + 10*eps, AudBin + 1);
        
        % Initialize 3 buckets: 1=Unbiased (collapsed), 2=Left, 3=Right
        CollapsedDVs = cell(1, 3);
        CollapsedChoices = cell(1, 3);
        for i = 1:3
            CollapsedDVs{i} = [];
            CollapsedChoices{i} = [];
        end
        
        SessionIndices = cumsum([0, SD.TrialWiseData.nTrialsArray]);
        nSessions = SD.SessionWiseData.nSessions;
        
        for s = 1:nSessions
            idxStart = SessionIndices(s) + 1;
            idxEnd = SessionIndices(s + 1);
            currentSessionIdx = idxStart:idxEnd;
            
            SessionBias = AudBias(currentSessionIdx);
            SessionBlockNum = BlockNumber(currentSessionIdx);
            SessionDV = DV(currentSessionIdx);
            SessionChoice = ChoiceLeft(currentSessionIdx);
            
            sessionBlocks = unique(SessionBlockNum);
            
            for b = sessionBlocks
                blockMask = (SessionBlockNum == b);
                blockBias = unique(SessionBias(blockMask));
                
                if isempty(blockBias) || any(isnan(blockBias))
                    continue;
                end
                
                blockIdx = [];
                if all(blockBias == 0.5)
                    blockIdx = 1;  % All unbiased blocks go here
                elseif all(blockBias > 0.5)
                    blockIdx = 2;
                elseif all(blockBias < 0.5)
                    blockIdx = 3;
                end
                
                if ~isempty(blockIdx)
                    BlockDVs = SessionDV(blockMask);
                    BlockChoices = SessionChoice(blockMask);
                    validMask = ~isnan(BlockDVs) & ~isnan(BlockChoices);
                    CollapsedDVs{blockIdx} = [CollapsedDVs{blockIdx}, BlockDVs(validMask)];
                    CollapsedChoices{blockIdx} = [CollapsedChoices{blockIdx}, BlockChoices(validMask)];
                end
            end
        end
        
        ls = CondLineStyles{min(iCond, numel(CondLineStyles))};
        mk = CondMarkers{min(iCond, numel(CondMarkers))};
        
        for iBlock = 1:3
            if ~isempty(CollapsedDVs{iBlock}) && sum(~isnan(CollapsedDVs{iBlock})) > 4
                BinIdx = discretize(CollapsedDVs{iBlock}, binEdges);
                
                validData = ~isnan(CollapsedDVs{iBlock}) & ~isnan(CollapsedChoices{iBlock}) & ~isnan(BinIdx);
                DV_valid = CollapsedDVs{iBlock}(validData);
                Ch_valid = CollapsedChoices{iBlock}(validData);
                Bin_valid = BinIdx(validData);
                
                uniqueBins = unique(Bin_valid);
                nBins = numel(uniqueBins);
                PsycX = zeros(nBins, 1);
                PsycY = zeros(nBins, 1);
                PsycXSEM = zeros(nBins, 1);
                PsycYSEM = zeros(nBins, 1);
                
                for ib = 1:nBins
                    mask = Bin_valid == uniqueBins(ib);
                    n = sum(mask);
                    PsycX(ib) = mean(DV_valid(mask));
                    PsycY(ib) = mean(Ch_valid(mask));
                    if n > 1
                        PsycXSEM(ib) = std(DV_valid(mask)) / sqrt(n);
                        PsycYSEM(ib) = std(Ch_valid(mask)) / sqrt(n);
                    end
                end
                
                if iCond == 1
                    errorbar(PsycX, PsycY, PsycYSEM, PsycXSEM, 'LineStyle', 'none', ...
                         'Marker', mk, 'MarkerFaceColor', CollapsedColors(iBlock, :), ...
                         'MarkerEdgeColor', 'w', 'MarkerSize', 6, ...
                         'Color', CollapsedColors(iBlock, :), 'LineWidth', 1);
                else
                    errorbar(PsycX, PsycY, PsycYSEM, PsycXSEM, 'LineStyle', 'none', ...
                         'Marker', mk, 'MarkerFaceColor', 'w', ...
                         'MarkerEdgeColor', CollapsedColors(iBlock, :), 'MarkerSize', 6, ...
                         'Color', CollapsedColors(iBlock, :), 'LineWidth', 1);
                end
                
                XFit = linspace(min(CollapsedDVs{iBlock}) - 10*eps, ...
                                max(CollapsedDVs{iBlock}) + 10*eps, 100);
                beta = glmfit(CollapsedDVs{iBlock}, CollapsedChoices{iBlock}', 'binomial');
                YFit = glmval(beta, XFit, 'logit');
                hFit = plot(XFit, YFit, ls, 'Color', CollapsedColors(iBlock, :), 'LineWidth', 1.5);
                
                legendEntries_collapsed(end+1) = string([char(DrugNames{iCond}), ' - ', char(CollapsedNames{iBlock})]);
                legendHandles_collapsed(end+1) = hFit;
            end
        end
    end
    
    xlabel('DV');
    ylabel('p left');
    title('Psychometric - Collapsed Unbiased Blocks');
    if ~isempty(legendHandles_collapsed)
        legend(legendHandles_collapsed, legendEntries_collapsed, 'Location', 'best', 'FontSize', 8);
    end
    hold off
    
    % %% DV Distribution Plot - Comparison
    % nexttile(FigHandle);
    % hold on
    % 
    % % Initialize StartPosition OUTSIDE the condition loop so it increments continuously
    % GlobalStartPosition = 1; 
    % 
    % for iCond = 1:nConditions
    %     SD = AllSessionData{iCond};
    % 
    %     DV = SD.TrialWiseData.DecisionVariable;
    %     BlockNumber = SD.TrialWiseData.BlockNumber;
    %     AudBias = SD.TrialWiseData.AudBias;
    % 
    %     SessionIndices = cumsum([0, SD.TrialWiseData.nTrialsArray]);
    %     nSessions = SD.SessionWiseData.nSessions;
    % 
    %     for s = 1:nSessions
    %         idxStart = SessionIndices(s) + 1;
    %         idxEnd = SessionIndices(s + 1);
    %         currentSessionIdx = idxStart:idxEnd;
    % 
    %         SessionBias = AudBias(currentSessionIdx);
    %         SessionBlockNum = BlockNumber(currentSessionIdx);
    %         SessionDV = DV(currentSessionIdx);
    % 
    %         sessionBlocks = unique(SessionBlockNum);
    % 
    %         for b = sessionBlocks
    %             blockMask = (SessionBlockNum == b);
    %             blockBias = unique(SessionBias(blockMask));
    % 
    %             if isempty(blockBias) || any(isnan(blockBias))
    %                 continue;
    %             end
    % 
    %             % Determine color
    %             if all(blockBias == 0.5)
    %                 if b == 1
    %                     color = unbiasedColor;
    %                 elseif b == 4
    %                     color = lastBlockColor;
    %                 else
    %                     color = unbiasedColor;
    %                 end
    %             elseif all(blockBias > 0.5)
    %                 color = leftBiasColor;
    %             elseif all(blockBias < 0.5)
    %                 color = rightBiasColor;
    %             else
    %                 continue;
    %             end
    % 
    %             CurrentDVs = SessionDV(blockMask);
    %             EndPosition = GlobalStartPosition + numel(CurrentDVs) - 1;
    % 
    %             % Apply different marker for each condition, but keep true DV on y-axis
    %             mk = CondMarkers{min(iCond, numel(CondMarkers))};
    %             plot(GlobalStartPosition:EndPosition, CurrentDVs, mk, ...
    %                  'Color', color, 'MarkerSize', 3, 'MarkerFaceColor', 'w');
    % 
    %             GlobalStartPosition = EndPosition + 1;
    %         end
    % 
    %         % Session boundary line (dotted gray)
    %         if s < nSessions
    %             xline(GlobalStartPosition - 0.5, ':', 'Color', [0.7, 0.7, 0.7], 'LineWidth', 0.5);
    %         end
    %     end
    % 
    %     % Condition boundary line (dashed dark gray)
    %     if iCond < nConditions
    %         xline(GlobalStartPosition - 0.5, '--', 'Color', [0.3, 0.3, 0.3], 'LineWidth', 1.5);
    %     end
    % end
    % 
    % xlim([0 GlobalStartPosition - 1]);
    % xlabel('iTrial (pooled across sessions)');
    % ylabel('Aud DV');
    % 
    % % Add condition labels at the top of the plot
    % cumTrials = 0;
    % yTop = max(cellfun(@(x) max(x.TrialWiseData.DecisionVariable(~isnan(x.TrialWiseData.DecisionVariable))), AllSessionData));
    % for iCond = 1:nConditions
    %     nTrialsCond = sum(AllSessionData{iCond}.TrialWiseData.nTrialsArray);
    %     xPos = cumTrials + nTrialsCond / 2;
    %     text(xPos, yTop * 1.05, DrugNames{iCond}, 'HorizontalAlignment', 'center', ...
    %          'FontSize', 10, 'FontWeight', 'bold');
    %     cumTrials = cumTrials + nTrialsCond;
    % end
    % 
    % hold off

    %% DV Distribution Histograms with Theoretical Overlays
    blockTypeNames = {'Unbiased (Start)', 'Left Bias', 'Right Bias'};
    
    for iBlock = 1:3
        nexttile(FigHandle);
        hold on
        
        for iCond = 1:nConditions
            SD = AllSessionData{iCond};
            
            DV = SD.TrialWiseData.DecisionVariable;
            BlockNumber = SD.TrialWiseData.BlockNumber;
            AudBias = SD.TrialWiseData.AudBias;
            Feedback = SD.TrialWiseData.Feedback;
            Correct = SD.TrialWiseData.ChoiceCorrect;
            CompletedTrials = (Feedback & Correct == 1) | (Correct == 0);
            
            SessionIndices = cumsum([0, SD.TrialWiseData.nTrialsArray]);
            nSessions = SD.SessionWiseData.nSessions;
            
            % Aggregate DVs for this block type
            BlockDVs = [];
            BlockBiases = [];
            
            for s = 1:nSessions
                idxStart = SessionIndices(s) + 1;
                idxEnd = SessionIndices(s + 1);
                currentSessionIdx = idxStart:idxEnd;
                
                SessionBias = AudBias(currentSessionIdx);
                SessionBlockNum = BlockNumber(currentSessionIdx);
                SessionDV = DV(currentSessionIdx);
                SessionCompleted = CompletedTrials(currentSessionIdx);
                
                sessionBlocks = unique(SessionBlockNum);
                
                for b = sessionBlocks
                    blockMask = (SessionBlockNum == b);
                    blockBias = unique(SessionBias(blockMask));
                    
                    if isempty(blockBias) || any(isnan(blockBias))
                        continue;
                    end
                    
                    % Match block type
                    matchBlock = false;
                    if iBlock == 1 && all(blockBias == 0.5) && b == 1
                        matchBlock = true;
                    elseif iBlock == 2 && all(all(blockBias > 0.5))
                        matchBlock = true;
                    elseif iBlock == 3 && all(all(blockBias < 0.5))
                        matchBlock = true;
                    end
                    
                    if matchBlock
                        validDVs = SessionDV(blockMask & SessionCompleted);
                        validDVs = validDVs(~isnan(validDVs));
                        BlockDVs = [BlockDVs, validDVs];
                        BlockBiases = [BlockBiases, repmat(blockBias, 1, numel(validDVs))];
                    end
                end
            end
            
            if isempty(BlockDVs)
                continue;
            end
            
            % Normalize DV to [0, 1]
            Omega = (BlockDVs + 1) / 2;
            Omega = min(max(Omega, 1e-6), 1 - 1e-6);
            
            % Get block bias (use mean if multiple sessions)
            p = mean(unique(BlockBiases));
            
            % Style for this condition
            ls = CondLineStyles{min(iCond, numel(CondLineStyles))};
            mk = CondMarkers{min(iCond, numel(CondMarkers))};
            
            % Use block-specific color
            blockColor = BlockColors(iBlock, :);
            
            % Adjust color brightness for condition distinction
            if iCond == 1
                histEdgeColor = blockColor;
                curveColor = blockColor;
            else
                histEdgeColor = blockColor * 0.6 + [0.4 0.4 0.4];
                curveColor = blockColor * 0.6 + [0.4 0.4 0.4];
            end
            
            % Plot histogram
            histogram(Omega, 'Normalization', 'pdf', 'BinWidth', 0.05, ...
                      'FaceColor', 'none', 'EdgeColor', histEdgeColor, ...
                      'LineStyle', ls, 'LineWidth', 1);
            
            % Fit Beta distribution
            phat = betafit(Omega);
            alphaFit = phat(1);
            betaFit = phat(2);
            
            % Plot fitted Beta PDF
            x = linspace(0, 1, 200);
            yBeta = betapdf(x, alphaFit, betaFit);
            plot(x, yBeta, ls, 'Color', curveColor, 'LineWidth', 1.5);
            
            % Plot theoretical Biased Uniform PDF (step function)
            yUniform = zeros(size(x));
            yUniform(x < 0.5) = 2 * (1 - p);
            yUniform(x >= 0.5) = 2 * p;
            plot(x, yUniform, ':', 'Color', curveColor, 'LineWidth', 1);
            
            % Calculate NLL for both models
            uniformPDF = 2 * (1 - p) * (Omega < 0.5) + 2 * p * (Omega >= 0.5);
            nllUniform = -sum(log(uniformPDF));
            nllBeta = -sum(log(betapdf(Omega, alphaFit, betaFit)));
            
            % Display NLL values
            yPos = 0.95 - 0.08 * (iCond - 1);
            text(0.02, yPos, ...
                 sprintf('%s: NLL_{U}=%.0f, NLL_{B}=%.0f', ...
                         DrugNames{iCond}, nllUniform, nllBeta), ...
                 'FontSize', 7, 'Color', curveColor, 'Units', 'normalized');
        end
        
        xlabel('\Omega (Left click proportion)');
        ylabel('PDF');
        title(blockTypeNames{iBlock});
        xlim([0 1]);
        ylim([0 4]);
        hold off
    end

end