function FigHandle = Analysis(SessionData)
% Analysis.m
% Handles three cases:
%   1) Automatic on rig: Analysis() - uses global BpodSystem
%   2) Manual single: Analysis('filepath.mat') - loads one session
%   3) Manual pooled: Analysis(SessionData) or Analysis('pooledfile.mat')

    %% ---- Step 1: Get SessionData into workspace ----
    
    if nargin < 1
        % Case 1: Automatic on rig
        global BpodSystem
        global TaskParameters
        if isempty(BpodSystem)
            [datafile, datapath] = uigetfile();
            loaded = load(fullfile(datapath, datafile));
            SessionData = loaded.SessionData;
        else
            SessionData = BpodSystem.Data;
            SessionData.SettingsFile.GUI = TaskParameters.GUI;
        end
    elseif ischar(SessionData) || isstring(SessionData)
        % Case 2 or 3: File path provided
        loaded = load(SessionData);
        SessionData = loaded.SessionData;
    end
    % else: SessionData is already a struct (Case 3)
    
    %% ---- Step 2: Normalize to unified format ----
    
    if ~isfield(SessionData, 'TrialWiseData')
        SessionData = NormalizeSingleSession(SessionData);
    end
    
    %% ---- Step 3: Extract unified variables ----
    
    nSessions = SessionData.SessionWiseData.nSessions;
    nTrials = sum(SessionData.TrialWiseData.nTrialsArray);
    
    DV = SessionData.TrialWiseData.DecisionVariable;
    ChoiceLeft = SessionData.TrialWiseData.ChoiceLeft;
    Feedback = SessionData.TrialWiseData.Feedback;
    Correct = SessionData.TrialWiseData.ChoiceCorrect;
    BlockNumber = SessionData.TrialWiseData.BlockNumber;
    AudBias = SessionData.TrialWiseData.AudBias;
    CompletedTrials = (Feedback & Correct == 1) | (Correct == 0);
    nTrialsCompleted = sum(CompletedTrials);
    
    %% ---- Step 4: Build title ----
    
    RatIDs = unique(SessionData.SessionWiseData.Subject);
    RatID = str2double(RatIDs{1});
    if isnan(RatID), RatID = -1; end
    
    if nSessions == 1
        dateString = string(SessionData.SessionWiseData.SessionDate{1});
        TotalClicks = SessionData.SessionWiseData.SumRates(1);
        AudStimTime = SessionData.SessionWiseData.AuditoryStimulusTime(1);
        AudLeftBias = SessionData.SessionWiseData.AudLeftBias(1:3, :)';
        AudLeftBiasString = strrep(num2str(AudLeftBias), "         ", "/");
        
        if isfield(SessionData.SessionWiseData, 'Pharmacology') && ~isempty(SessionData.SessionWiseData.Pharmacology)
            pharm = SessionData.SessionWiseData.Pharmacology{1};
            figtitle = sprintf("DiscriminationBlocks, R%d on %s with %s %s %s, TotalClicks = %d, AudStimTime = %s, AudBias = %s", ...
                RatID, dateString, pharm{1}, pharm{2}, pharm{3}, TotalClicks, num2str(AudStimTime), AudLeftBiasString);
        else
            figtitle = sprintf("DiscriminationBlocks, R%d on %s, TotalClicks = %d, AudStimTime = %s, AudBias = %s", ...
                RatID, dateString, TotalClicks, num2str(AudStimTime), AudLeftBiasString);
        end
    else
        dateString = strcat(string(SessionData.SessionWiseData.SessionDate{1}), " - ", ...
                           string(SessionData.SessionWiseData.SessionDate{end}));
        figtitle = sprintf("DiscriminationBlocks: R%d on %s (%d sessions, n=%d trials)", ...
            RatID, dateString, nSessions, nTrialsCompleted);
    end
    
    %% ---- Step 5: Setup figure ----
    
    FigHandle = tiledlayout('flow');
    FigHandle.TileSpacing = 'tight';
    FigHandle.Padding = 'tight';
    sgtitle(figtitle, 'FontSize', 14);
    
    %% ---- Step 6: Psychometric Plot ----
    
    nexttile(FigHandle);
    hold on
    
    AudBin = 7;
    DV_Completed = DV(CompletedTrials);
    commonBinEdges = linspace(min(DV_Completed)-10*eps, max(DV_Completed)+10*eps, AudBin+1);
    
    % Color scheme
    unbiasedColor = [0, 0, 0];
    leftBiasColor = [1, 0, 0];
    rightBiasColor = [0, 0, 1];
    lastBlockColor = [0.5, 0.5, 0.5];
    Colors = [unbiasedColor; leftBiasColor; rightBiasColor; lastBlockColor];
    
    % Initialize aggregation arrays: 1=Start Unbiased, 2=Left, 3=Right, 4=End Unbiased
    AllDVs = cell(1, 4);
    AllChoices = cell(1, 4);
    for i = 1:4
        AllDVs{i} = [];
        AllChoices{i} = [];
    end
    
    % Session boundaries
    SessionIndices = cumsum([0, SessionData.TrialWiseData.nTrialsArray]);
    
    % Iterate through each session
    for s = 1:nSessions
        idxStart = SessionIndices(s) + 1;
        if s < nSessions
            idxEnd = SessionIndices(s + 1);
        else
            idxEnd = numel(DV);
        end
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
            
            % Determine bucket index
            blockIdx = [];
            if blockBias == 0.5
                if b == 1
                    blockIdx = 1;
                elseif b == 4
                    blockIdx = 4;
                else
                    blockIdx = 1;
                end
            elseif blockBias > 0.5
                blockIdx = 2;
            elseif blockBias < 0.5
                blockIdx = 3;
            end
            
            if ~isempty(blockIdx)
                BlockDVs = SessionDV(blockMask);
                BlockChoices = SessionChoice(blockMask);
                validMask = ~isnan(BlockDVs) & ~isnan(BlockChoices);
                AllDVs{blockIdx} = [AllDVs{blockIdx}, BlockDVs(validMask)];
                AllChoices{blockIdx} = [AllChoices{blockIdx}, BlockChoices(validMask)];
            end
        end
    end
    
    % Plot aggregated psychometric curves
    for i = 1:4
        if ~isempty(AllDVs{i}) && sum(~isnan(AllDVs{i})) > 4
            BinIdx = discretize(AllDVs{i}, commonBinEdges);
            PsycY = grpstats(AllChoices{i}, BinIdx, 'mean');
            PsycX = grpstats(AllDVs{i}, BinIdx, 'mean');
            
            plot(PsycX, PsycY, 'o', 'MarkerFaceColor', Colors(i,:), ...
                 'MarkerEdgeColor', 'w', 'MarkerSize', 6);
            
            XFit = linspace(min(AllDVs{i})-10*eps, max(AllDVs{i})+10*eps, 100);
            YFit = glmval(glmfit(AllDVs{i}, AllChoices{i}', 'binomial'), XFit, 'logit');
            plot(XFit, YFit, '-', 'Color', Colors(i,:), 'LineWidth', 1.5);
        end
    end
    
    xlabel('DV');
    ylabel('p left');
    text(0.95*min(get(gca,'XLim')), 0.96*max(get(gca,'YLim')), ...
         ['n=', num2str(nTrialsCompleted)]);
    hold off
    
    %% ---- Step 7: DV Distribution Plot ----
    
    nexttile(FigHandle);
    hold on
    
    GlobalStartPosition = 1;
    
    for s = 1:nSessions
        idxStart = SessionIndices(s) + 1;
        if s < nSessions
            idxEnd = SessionIndices(s + 1);
        else
            idxEnd = numel(DV);
        end
        currentSessionIdx = idxStart:idxEnd;
        
        SessionBias = AudBias(currentSessionIdx);
        SessionBlockNum = BlockNumber(currentSessionIdx);
        SessionDV = DV(currentSessionIdx);
        
        sessionBlocks = unique(SessionBlockNum);
        
        for b = sessionBlocks
            blockMask = (SessionBlockNum == b);
            blockBias = unique(SessionBias(blockMask));
            
            if isempty(blockBias) || any(isnan(blockBias))
                continue;
            end
            
            if blockBias == 0.5
                if b == 1
                    color = unbiasedColor;
                elseif b == 4
                    color = lastBlockColor;
                else
                    color = unbiasedColor;
                end
            elseif blockBias > 0.5
                color = leftBiasColor;
            elseif blockBias < 0.5
                color = rightBiasColor;
            else
                continue;
            end
            
            CurrentDVs = SessionDV(blockMask);
            EndPosition = GlobalStartPosition + numel(CurrentDVs) - 1;
            plot(GlobalStartPosition:EndPosition, CurrentDVs, 'o', ...
                 'Color', color, 'MarkerSize', 2);
            GlobalStartPosition = EndPosition + 1;
        end
        
        if s < nSessions
            xline(GlobalStartPosition - 0.5, ':', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
        end
    end
    
    xlim([0 GlobalStartPosition - 1]);
    xlabel('iTrial');
    ylabel('Aud DV');
    hold off
    
    %% ---- Step 8: DV Distribution Histograms ----
    
    blockTypeNames = {'Unbiased (Start)', 'Left Bias', 'Right Bias'};
    
    for iBlock = 1:3
        nexttile(FigHandle);
        hold on
        
        BlockDVs = [];
        BlockBiases = [];
        
        for s = 1:nSessions
            idxStart = SessionIndices(s) + 1;
            if s < nSessions
                idxEnd = SessionIndices(s + 1);
            else
                idxEnd = numel(DV);
            end
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
                
                matchBlock = false;
                if iBlock == 1 && blockBias == 0.5 && b == 1
                    matchBlock = true;
                elseif iBlock == 2 && blockBias > 0.5
                    matchBlock = true;
                elseif iBlock == 3 && blockBias < 0.5
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
            title(sprintf('%s (no data)', blockTypeNames{iBlock}));
            continue;
        end
        
        Omega = (BlockDVs + 1) / 2;
        Omega = min(max(Omega, 1e-6), 1 - 1e-6);
        
        p = mean(unique(BlockBiases));
        blockColor = Colors(iBlock, :);
        
        histogram(Omega, 'Normalization', 'pdf', 'BinWidth', 0.05, ...
                  'FaceColor', [0.7 0.7 0.7], 'EdgeColor', blockColor, 'LineWidth', 1);
        
        phat = betafit(Omega);
        x = linspace(0, 1, 200);
        yBeta = betapdf(x, phat(1), phat(2));
        plot(x, yBeta, '-', 'Color', blockColor, 'LineWidth', 1.5);
        
        yUniform = zeros(size(x));
        yUniform(x < 0.5) = 2 * (1 - p);
        yUniform(x >= 0.5) = 2 * p;
        plot(x, yUniform, ':', 'Color', blockColor, 'LineWidth', 1);
        
        uniformPDF_vals = 2 * (1 - p) * (Omega < 0.5) + 2 * p * (Omega >= 0.5);
        nllUniform = -sum(log(uniformPDF_vals));
        nllBeta = -sum(log(betapdf(Omega, phat(1), phat(2))));
        aicUniform = 2 * 1 + 2 * nllUniform;
        aicBeta = 2 * 2 + 2 * nllBeta;
        
        if aicUniform < aicBeta
            winner = 'UNIFORM';
            winColor = [0 0.6 0];
        else
            winner = 'BETA';
            winColor = [0.8 0 0];
        end
        
        text(0.02, 0.95, sprintf('AIC_U=%.0f, AIC_B=%.0f → %s', ...
             aicUniform, aicBeta, winner), ...
             'FontSize', 8, 'Color', winColor, 'Units', 'normalized');
        
        xlabel('\Omega');
        ylabel('PDF');
        title(blockTypeNames{iBlock});
        xlim([0 1]);
        ylim([0 4]);
        hold off
    end

end % Analysis()


%% ---- Helper Function: Normalize single session to pooled format ----

function SessionData = NormalizeSingleSession(SessionData)
% Converts a single-session struct into the same TrialWiseData/SessionWiseData
% format used by pooled analysis, enabling unified downstream code.

    nTrials = SessionData.nTrials;
    
    % --- TrialWiseData ---
    TD = SessionData.Custom.TrialData;
    fields = {'DecisionVariable', 'ChoiceLeft', 'SampleLength', ...
              'CatchTrial', 'Feedback', 'ChoiceCorrect', ...
              'BlockNumber', 'LaserTrial', 'AudBias'};
    
    TrialWiseData.nTrialsArray = nTrials - 1;  % Last trial typically aborted
    
    for k = 1:numel(fields)
        f = fields{k};
        if isfield(TD, f)
            val = TD.(f);
            if isvector(val) && ~iscell(val)
                val = val(:)';
            end
            TrialWiseData.(f) = val(1:end-1);
        else
            if iscell(val)
                TrialWiseData.(f) = cell(1, nTrials - 1);
            else
                TrialWiseData.(f) = nan(1, nTrials - 1);
            end
        end
    end
    
    % --- SessionWiseData ---
    SessionWiseData.nSessions = 1;
    SessionWiseData.Subject = {SessionData.Info.Subject};
    SessionWiseData.SessionDate = {SessionData.Info.SessionDate};
    SessionWiseData.SumRates = SessionData.SettingsFile.GUI.SumRates;
    SessionWiseData.AuditoryStimulusTime = SessionData.SettingsFile.GUI.AuditoryStimulusTime;
    
    if isfield(SessionData.SettingsFile.GUI, 'BlockTable')
        SessionWiseData.AudLeftBias = SessionData.SettingsFile.GUI.BlockTable.AudLeftBias;
        if isfield(SessionData.SettingsFile.GUI.BlockTable, 'BlockLen')
            SessionWiseData.BlockLen = SessionData.SettingsFile.GUI.BlockTable.BlockLen;
        end
    end
    
    if isfield(SessionData.Custom, 'Pharmacology')
        SessionWiseData.Pharmacology = {SessionData.Custom.Pharmacology};
    else
        SessionWiseData.Pharmacology = {};
    end
    
    if isfield(SessionData.Custom, 'BiasToFitIndexMap')
        SessionWiseData.BiasToFitIndexMap = SessionData.Custom.BiasToFitIndexMap;
    end
    if isfield(SessionData.Custom, 'FitIndexToColorMap')
        SessionWiseData.FitIndexToColorMap = SessionData.Custom.FitIndexToColorMap;
    end
    
    % --- Merge ---
    SessionData.TrialWiseData = TrialWiseData;
    SessionData.SessionWiseData = SessionWiseData;
end