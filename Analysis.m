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
    
    % Create a new figure explicitly so it doesn't draw on the Bpod console
    FigHandle = figure('Name', figtitle, 'Position', [50 75 1400 650]);
    
    % Optional: if you want a 3x2 grid to hold your 5 plots:
    nRows = 3;
    nCols = 2;
    
    %% ---- Step 6: Psychometric Plot ----
    
    subplot(3, 2, 1);
    hold on;
        
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
    beta_Left = [];
    beta_Right = [];
    
    for i = 1:4
        if ~isempty(AllDVs{i}) && sum(~isnan(AllDVs{i})) > 4
            BinIdx = discretize(AllDVs{i}, commonBinEdges);
            
            % Remove NaNs before grouping
            validData = ~isnan(AllDVs{i}) & ~isnan(AllChoices{i}) & ~isnan(BinIdx);
            DV_valid = AllDVs{i}(validData);
            Ch_valid = AllChoices{i}(validData);
            Bin_valid = BinIdx(validData);
            
            % Calculate mean and SEM manually per bin
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
            
            % Plot points with vertical and horizontal error bars
            errorbar(PsycX, PsycY, PsycYSEM, PsycXSEM, 'LineStyle', 'none', ...
                 'Marker', 'o', 'MarkerFaceColor', Colors(i,:), ...
                 'MarkerEdgeColor', 'w', 'MarkerSize', 6, ...
                 'Color', Colors(i,:), 'LineWidth', 1);
            
            % Plot Fit and store betas for Left (2) and Right (3) blocks
            XFit = linspace(min(AllDVs{i})-10*eps, max(AllDVs{i})+10*eps, 100);
            beta = glmfit(AllDVs{i}, AllChoices{i}', 'binomial');
            YFit = glmval(beta, XFit, 'logit');
            plot(XFit, YFit, '-', 'Color', Colors(i,:), 'LineWidth', 1.5);
            
            if i == 2 % Left Bias
                beta_Left = beta;
            elseif i == 3 % Right Bias
                beta_Right = beta;
            end
        end
    end
    
    % Calculate and display PSE Shift and ABC
    if ~isempty(beta_Left) && ~isempty(beta_Right)
        % PSE = -intercept / slope
        PSE_L = -beta_Left(1) / beta_Left(2);
        PSE_R = -beta_Right(1) / beta_Right(2);
        deltaPSE = PSE_L - PSE_R;
        
        % Area Between Curves (evaluated from DV -1 to 1)
        x_grid = linspace(-1, 1, 1000);
        y_L = glmval(beta_Left, x_grid, 'logit');
        y_R = glmval(beta_Right, x_grid, 'logit');
        ABC = trapz(x_grid, abs(y_L - y_R));
        
        % Display text in southeast corner
        metricsStr = sprintf('ΔPSE (L-R): %.3f\nABC (L vs R): %.3f', deltaPSE, ABC);
        text(0.98, 0.02, metricsStr, 'Units', 'normalized', ...
             'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
             'FontSize', 9, 'EdgeColor', [0.8 0.8 0.8], 'BackgroundColor', 'w', ...
             'Margin', 2);
    end
    
    xlabel('DV');
    ylabel('p left');
    text(0.95*min(get(gca,'XLim')), 0.96*max(get(gca,'YLim')), ...
         ['n=', num2str(nTrialsCompleted)]);
    hold off

    %% ---- Step 6a: Collapsed Unbiased Psychometric Figure ----
    
    subplot(3, 2, 2);
    hold on
    
    % Initialize 3 buckets: 1=Unbiased (collapsed), 2=Left, 3=Right
    CollapsedDVs = cell(1, 3);
    CollapsedChoices = cell(1, 3);
    for i = 1:3
        CollapsedDVs{i} = [];
        CollapsedChoices{i} = [];
    end
    
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
            
            % Determine bucket (3 buckets: 1=Unbiased, 2=Left, 3=Right)
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
    
    % 3 colors: Black (unbiased), Red (left), Blue (right)
    CollapsedColors = [unbiasedColor; leftBiasColor; rightBiasColor];
    CollapsedNames = {'Unbiased', 'Left Bias', 'Right Bias'};
    
    legendEntries_collapsed = strings(0);
    legendHandles_collapsed = gobjects(0);
    
    for iBlock = 1:3
        if ~isempty(CollapsedDVs{iBlock}) && sum(~isnan(CollapsedDVs{iBlock})) > 4
            BinIdx = discretize(CollapsedDVs{iBlock}, commonBinEdges);
            
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
            
            errorbar(PsycX, PsycY, PsycYSEM, PsycXSEM, 'LineStyle', 'none', ...
                 'Marker', 'o', 'MarkerFaceColor', CollapsedColors(iBlock, :), ...
                 'MarkerEdgeColor', 'w', 'MarkerSize', 6, ...
                 'Color', CollapsedColors(iBlock, :), 'LineWidth', 1);
            
            XFit = linspace(min(CollapsedDVs{iBlock})-10*eps, ...
                            max(CollapsedDVs{iBlock})+10*eps, 100);
            beta = glmfit(CollapsedDVs{iBlock}, CollapsedChoices{iBlock}', 'binomial');
            YFit = glmval(beta, XFit, 'logit');
            hFit = plot(XFit, YFit, '-', 'Color', CollapsedColors(iBlock, :), 'LineWidth', 1.5);
            
            legendEntries_collapsed(end+1) = string(char(CollapsedNames{iBlock}));
            legendHandles_collapsed(end+1) = hFit;
        end
    end
    
    xlabel('DV');
    ylabel('p left');
    title('Psychometric - Collapsed Unbiased Blocks');
    if ~isempty(legendHandles_collapsed)
        legend(legendHandles_collapsed, legendEntries_collapsed, 'Location', 'best', 'FontSize', 8);
    end
    hold off
    
    %% ---- Step 7: DV Distribution Plot ----
    
    subplot(3, 2, 3);
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
        subplot(3, 2, 3 + iBlock);
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

    %% ---- Step 9: Separate DV vs Time figure for single session ----
    
    if nSessions == 1 && isfield(SessionData, 'TrialStartTimestamp')
        % Create separate figure
        FigHandle2 = figure('Name', 'DV Distribution vs Time', 'Position', [200 200 1000 400]);
        
        % Get trial times in minutes
        TrialTimes = SessionData.TrialStartTimestamp(1:nTrials);
        TrialTimesMin = TrialTimes / 60;
        
        % Plot DV distribution on primary axes (trial number on bottom)
        ax1 = axes(FigHandle2);
        hold(ax1, 'on');
        
        for iBlock = unique(BlockNumber)
            blockIdx = (BlockNumber == iBlock);
            currentBias = unique(AudBias(blockIdx));
            
            if isempty(currentBias) || any(isnan(currentBias))
                continue;
            end
            
            if currentBias == 0.5
                if iBlock == 1
                    color = unbiasedColor;
                elseif iBlock == 4
                    color = lastBlockColor;
                else
                    color = unbiasedColor;
                end
            elseif currentBias > 0.5
                color = leftBiasColor;
            elseif currentBias < 0.5
                color = rightBiasColor;
            else
                continue;
            end
            
            CurrentDVs = DV(blockIdx);
            blockIndices = find(blockIdx);
            plot(ax1, blockIndices, CurrentDVs, 'o', 'Color', color, 'MarkerSize', 3);
        end
        
        xlabel(ax1, 'Trial Number');
        ylabel(ax1, 'Aud DV');
        % title(ax1, sprintf('R%d on %s', RatID, dateString));
        hold(ax1, 'off');
        
        % Create overlaid axes for time (minutes) on top
        ax2 = axes(FigHandle2, 'Position', get(ax1, 'Position'), 'Color', 'none');
        ax2.XAxisLocation = 'top';
        ax2.YAxis.Visible = 'off';
        ax2.Color = 'none';
        ax2.Box = 'off';
        
        % Set ax2 limits to match ax1
        ax2.XLim = ax1.XLim;
        ax2.YLim = ax1.YLim;
        
        % Set tick positions to match ax1
        ax2.XTick = ax1.XTick;
        
        % Create time labels for each tick position
        xtickPositions = ax1.XTick;
        timeLabels = cell(numel(xtickPositions), 1);
        for i = 1:numel(xtickPositions)
            trialNum = round(xtickPositions(i));
            if trialNum >= 1 && trialNum <= numel(TrialTimesMin)
                timeLabels{i} = sprintf('%.1f', TrialTimesMin(trialNum));
            else
                timeLabels{i} = '';
            end
        end
        ax2.XTickLabel = timeLabels;
        ax2.XColor = [0.3 0.3 0.3];
        xlabel(ax2, 'Time (min)');
        
        % Link x-axes so they stay synchronized on zoom/pan
        linkaxes([ax1 ax2], 'x');
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