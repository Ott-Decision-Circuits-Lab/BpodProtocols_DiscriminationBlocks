function FigHandle = Analysis(SessionData)

if isfield(SessionData, 'TrialWiseData')
    AnalysisType = "pooled";
else
    AnalysisType = "single";
    if nargin < 1
        global TaskParameters
        global BpodSystem
        if isempty(BpodSystem)
            [datafile, datapath] = uigetfile();
            load(fullfile(datapath, datafile));
            GUISettings = SessionData.SettingsFile.GUI;
        else
            SessionData = BpodSystem.Data;
            GUISettings = TaskParameters.GUI;
        end
    else
        try
            SessionData = DataFile;
        catch
            load(DataFile);
            GUISettings = SessionData.SettingsFile.GUI;
        end
    end
end

AudBin = 7; %Bins for psychometric

if strcmp(AnalysisType, "single")
    Animal = str2double(SessionData.Info.Subject);
    if isnan(Animal)
        Animal = -1;
    end
    dateString = string(SessionData.Info.SessionDate);

    nTrials=SessionData.nTrials;
    DV = SessionData.Custom.TrialData.DecisionVariable(1:nTrials-1);
    ChoiceLeft = SessionData.Custom.TrialData.ChoiceLeft(1:nTrials-1);
    ST = SessionData.Custom.TrialData.SampleLength(1:nTrials-1);
    CatchTrial = SessionData.Custom.TrialData.CatchTrial((1:nTrials-1));
    Feedback = SessionData.Custom.TrialData.Feedback(1:nTrials-1);
    Correct = SessionData.Custom.TrialData.ChoiceCorrect(1:nTrials-1);
    BlockNumber = SessionData.Custom.TrialData.BlockNumber(1:nTrials-1);
    
    CompletedTrials = (Feedback&Correct==1) | (Correct==0) | CatchTrial&~isnan(ChoiceLeft);
    nTrialsCompleted = sum(CompletedTrials);
    
    TotalClicks = SessionData.SettingsFile.GUI.SumRates;
    AudStimTime = num2str(SessionData.SettingsFile.GUI.AuditoryStimulusTime);
    AudLeftBiasString = num2str(SessionData.SettingsFile.GUI.BlockTable.AudLeftBias(1:3, :)');
    AudLeftBiasString = strrep(AudLeftBiasString, "         ", "/");
    FigHandle = tiledlayout('flow');
    FigHandle.TileSpacing = 'tight';
    FigHandle.Padding = 'tight';
    if isfield(SessionData.Custom, "Pharmacology")
        if strcmp(AnalysisType, "single")
            figtitle = sprintf("DiscriminationBlocks, R%d on %s with %s %s %s, TotalClicks = %d, AudStimTime = %s, AudBias = %s", Animal, dateString, SessionData.Custom.Pharmacology{1}, ...
                SessionData.Custom.Pharmacology{2}, SessionData.Custom.Pharmacology{3}, TotalClicks, AudStimTime, AudLeftBiasString);
        else
            figtitle = sprintf("DiscriminationBlocks, R%d on %s with %s %s %s", Animal, SessionData.drugNames{1}, SessionData.drugDoses(1), SessionData.drugDosageUnits{1}); % TO DO: improve this
        end
    else
        if strcmp(AnalysisType, "single")
            figtitle = sprintf("DiscriminationBlocks, R%d on %s, TotalClicks = %d, AudStimTime = %s, AudBias = %s", Animal, dateString, TotalClicks, AudStimTime, AudLeftBiasString);
        else
            figtitle = sprintf("DiscriminationBlocks, R%d", Animal); % TO DO: improve this
        end
    end
    sgtitle(figtitle, 'FontSize', 14);
    % ExperiencedDV=DV; 

else % pooled session analysis
    Animal = unique(SessionData.SessionWiseData.Subject);
    dateString = strcat(string(SessionData.SessionWiseData.SessionDate{1}), " - ", string(SessionData.SessionWiseData.SessionDate{end}));
    nTrials = sum(SessionData.TrialWiseData.nTrialsArray);
    %nTrials = nTrials - SessionData.SessionWiseData.nSessions; % last trials get aborted
    DV = SessionData.TrialWiseData.DecisionVariable;
    ChoiceLeft = SessionData.TrialWiseData.ChoiceLeft;
    Feedback = SessionData.TrialWiseData.Feedback;
    Correct = SessionData.TrialWiseData.ChoiceCorrect;
    BlockNumber = SessionData.TrialWiseData.BlockNumber;
    AudBias = SessionData.TrialWiseData.AudBias;
    CompletedTrials = (Feedback&Correct==1) | (Correct==0);
    nTrialsCompleted = sum(CompletedTrials);
    TotalClicksString = num2str(unique(SessionData.SessionWiseData.SumRates));
    AudStimTimeString = num2str(unique(SessionData.SessionWiseData.AuditoryStimulusTime));
    AudLeftBiasString = num2str(unique(SessionData.SessionWiseData.AudLeftBias));
end

% Determine common bin edges across ALL data
DV_Completed = DV(CompletedTrials);
commonBinEdges = linspace(min(DV_Completed)-10*eps, max(DV_Completed)+10*eps, AudBin+1);
binCenters = (commonBinEdges(1:end-1) + commonBinEdges(2:end))/2;

%% Psychometric Plot
FigHandle = tiledlayout("flow");
nexttile(FigHandle);
hold on

% Define Color Scheme
unbiasedColor = [0, 0, 0];       % Black
leftBiasColor = [1, 0, 0];       % Red
rightBiasColor = [0, 0, 1];      % Blue
lastBlockColor = [0.5, 0.5, 0.5]; % Gray

if strcmp(AnalysisType, "single")
    
    %% --- ORIGINAL SINGLE SESSION ANALYSIS ---
    
    % Plot all data (black dots)
    BinIdx = discretize(DV_Completed, commonBinEdges);
    PsycY = grpstats(ChoiceLeft(CompletedTrials), BinIdx,'mean');
    PsycX = grpstats(DV(CompletedTrials), BinIdx,'mean');
    plot(PsycX,PsycY,'ok','MarkerFaceColor','k','MarkerEdgeColor','w','MarkerSize',6)
    
    % Fit line (black)
    XFit = linspace(min(DV_Completed)-10*eps,max(DV_Completed)+10*eps,100);
    YFit = glmval(glmfit(DV_Completed,ChoiceLeft(CompletedTrials)','binomial'), linspace(min(DV_Completed)-10*eps,max(DV_Completed)+10*eps, 100),'logit');
    plot(XFit,YFit,'Color','k');
    
    % Stats Text
    xlabel('DV');ylabel('p left')
    text(0.95*min(get(gca,'XLim')),0.96*max(get(gca,'YLim')),[num2str(round(nanmean(Correct(CompletedTrials))*100)),'%,n=',num2str(nTrialsCompleted)]);

    % Original Categorized Psychometric (Left/Right/Unbiased)
    AudBiasCompleted = SessionData.Custom.TrialData.AudBias(CompletedTrials);
    uniqueAudBiases = unique(AudBiasCompleted);
    leftBias = uniqueAudBiases(uniqueAudBiases > 0.5);
    unbiased = uniqueAudBiases(uniqueAudBiases == 0.5);
    rightBias = uniqueAudBiases(uniqueAudBiases < 0.5);
    
    ChoiceLeftCompleted = ChoiceLeft(CompletedTrials);
    BlockNumberCompleted = BlockNumber(CompletedTrials);

    % Unbiased at the beginning (black)
    if ~isempty(unbiased)
        CurrentDVs = DV_Completed(BlockNumberCompleted == 1);
        CurrentChoiceLeft = ChoiceLeftCompleted(BlockNumberCompleted == 1);
        BinIdx = discretize(CurrentDVs, commonBinEdges);
        PsycY = grpstats(CurrentChoiceLeft,BinIdx,'mean');
        PsycX = grpstats(CurrentDVs,BinIdx,'mean');
        plot(PsycX,PsycY, 'o','MarkerFaceColor',unbiasedColor,'MarkerEdgeColor','w','MarkerSize',6)
        XFit = linspace(min(CurrentDVs)-10*eps,max(CurrentDVs)+10*eps,100);
        YFit = glmval(glmfit(CurrentDVs,CurrentChoiceLeft','binomial'),linspace(min(CurrentDVs)-10*eps,max(CurrentDVs)+10*eps,100),'logit');
        plot(XFit,YFit, '-', 'Color',unbiasedColor);
    end

    % Left-biased (red)
    if ~isempty(leftBias)
        CurrentDVs = DV_Completed(ismember(AudBiasCompleted, leftBias));
        CurrentChoiceLeft = ChoiceLeftCompleted(ismember(AudBiasCompleted, leftBias));
        BinIdx = discretize(CurrentDVs, commonBinEdges);
        PsycY = grpstats(CurrentChoiceLeft,BinIdx,'mean');
        PsycX = grpstats(CurrentDVs,BinIdx,'mean');
        plot(PsycX,PsycY, 'o','MarkerFaceColor',leftBiasColor,'MarkerEdgeColor','w','MarkerSize',6)
        XFit = linspace(min(CurrentDVs)-10*eps,max(CurrentDVs)+10*eps,100);
        YFit = glmval(glmfit(CurrentDVs,CurrentChoiceLeft','binomial'),linspace(min(CurrentDVs)-10*eps,max(CurrentDVs)+10*eps,100),'logit');
        plot(XFit,YFit, '-', 'Color',leftBiasColor);
    end

    % Right-biased (blue)
    if ~isempty(rightBias)
        CurrentDVs = DV_Completed(ismember(AudBiasCompleted, rightBias));
        CurrentChoiceLeft = ChoiceLeftCompleted(ismember(AudBiasCompleted, rightBias));
        BinIdx = discretize(CurrentDVs, commonBinEdges);
        PsycY = grpstats(CurrentChoiceLeft,BinIdx,'mean');
        PsycX = grpstats(CurrentDVs,BinIdx,'mean');
        plot(PsycX,PsycY, 'o','MarkerFaceColor',rightBiasColor,'MarkerEdgeColor','w','MarkerSize',6)
        XFit = linspace(min(CurrentDVs)-10*eps,max(CurrentDVs)+10*eps,100);
        YFit = glmval(glmfit(CurrentDVs,CurrentChoiceLeft','binomial'),linspace(min(CurrentDVs)-10*eps,max(CurrentDVs)+10*eps,100),'logit');
        plot(XFit,YFit, '-', 'Color',rightBiasColor);
    end

    % Unbiased at the end (gray) - Assuming Block 4 is the last unbiased block based on original code
    if ~isempty(unbiased)
        CurrentDVs = DV_Completed(BlockNumberCompleted == 4);
        CurrentChoiceLeft = ChoiceLeftCompleted(BlockNumberCompleted == 4);
        BinIdx = discretize(CurrentDVs, commonBinEdges);
        PsycY = grpstats(CurrentChoiceLeft,BinIdx,'mean');
        PsycX = grpstats(CurrentDVs,BinIdx,'mean');
        plot(PsycX,PsycY, 'o','MarkerFaceColor',lastBlockColor,'MarkerEdgeColor','w','MarkerSize',6)
        XFit = linspace(min(CurrentDVs)-10*eps,max(CurrentDVs)+10*eps,100);
        YFit = glmval(glmfit(CurrentDVs,CurrentChoiceLeft','binomial'),linspace(min(CurrentDVs)-10*eps,max(CurrentDVs)+10*eps,100),'logit');
        plot(XFit,YFit, '-', 'Color',lastBlockColor);
    end

    nexttile(FigHandle);
    hold on
    StartPosition = 1;
    EndPosition = 0;
    for iBlock = unique(BlockNumber)
        blockIdx = (BlockNumber == iBlock);
        currentBias = unique(SessionData.Custom.TrialData.AudBias(blockIdx));
        fitIndex = SessionData.Custom.BiasToFitIndexMap(currentBias);
        color = SessionData.Custom.FitIndexToColorMap(fitIndex, :);
        CurrentDVs = DV(BlockNumber == iBlock);
        EndPosition = EndPosition + numel(CurrentDVs);
        plot(StartPosition:EndPosition, CurrentDVs, 'o', 'Color', color, 'MarkerSize', 2)
        StartPosition = StartPosition + numel(CurrentDVs);
    end
    BlockLengths = SessionData.SettingsFile.GUI.BlockTable.BlockLen;
    try
        xticks([0 BlockLengths(1) BlockLengths(1)+BlockLengths(2) BlockLengths(1)+BlockLengths(2)+BlockLengths(3) nTrials])
    catch
        try
            xticks([0 BlockLengths(1) BlockLengths(1)+BlockLengths(2) nTrials])
        catch
            xticks([0 BlockLengths(1) nTrials])
        end
    end
    xlim([0 nTrials])
    xlabel("iTrial"); ylabel("Aud DV");
    hold off

elseif strcmp(AnalysisType, "pooled")
    
    %% --- NEW POOLED ANALYSIS ---
    
    % Extract Session boundaries
    SessionIndices = cumsum([0, SessionData.TrialWiseData.nTrialsArray(1:end-1)]);
    nSessions = SessionData.SessionWiseData.nSessions;

    % Initialize vectors to hold aggregated data for each of the 4 types
    % 1: Start Unbiased (Block 1), 2: Left Bias (>0.5), 3: Right Bias (<0.5), 4: End Unbiased (Block 4)
    AllDVs{1} = []; Choices{1} = [];
    AllDVs{2} = []; Choices{2} = [];
    AllDVs{3} = []; Choices{3} = [];
    AllDVs{4} = []; Choices{4} = [];

    % Iterate through each session to extract specific blocks
    for s = 1:nSessions
        % Get trial indices for this session
        if s < nSessions
            currentSessionIdx = (SessionIndices(s)+1) : SessionIndices(s+1);
        else
            currentSessionIdx = (SessionIndices(s)+1) : numel(ChoiceLeft);
        end
        
        % Get values for this session
        SessionBias = AudBias(currentSessionIdx);
        SessionBlockNum = BlockNumber(currentSessionIdx);
        SessionDV = DV(currentSessionIdx);
        SessionChoice = ChoiceLeft(currentSessionIdx);

        SessionCompletedIdx = CompletedTrials(currentSessionIdx);
        SessionDV_Completed = SessionDV(SessionCompletedIdx);
        SessionChoiceCompleted = ChoiceLeft(SessionCompletedIdx); % ChoiceLeft already subset by CompletedTrials logic
        
        % Define colors based on block content within the session
        % Identify blocks in this session
        sessionBlocks = unique(SessionBlockNum);
        
        for b = sessionBlocks
            blockMask = (SessionBlockNum == b);
            blockBias = unique(SessionBias(blockMask));
            
            currentColor = [];
            isUnbiased = (blockBias == 0.5);
            
            % Determine Color
            if isUnbiased
                % Check if this is the first unbiased block (Block 1) or the last (Block 4)
                % We assume block numbers are consistent or relative.
                % Here we check against the standard sequence: 1=Start, 4=End
                if b == 1
                    currentColor = unbiasedColor; % Black
                    blockIdx = 1;
                elseif b == 4
                    currentColor = lastBlockColor; % Gray
                    blockIdx = 4;
                else
                    currentColor = unbiasedColor; % Fallback Black
                end
            elseif blockBias > 0.5
                currentColor = leftBiasColor; % Red
                blockIdx = 2;
            elseif blockBias < 0.5
                currentColor = rightBiasColor; % Blue
                blockIdx = 3;
            else
                continue; % Skip if undefined
            end

            % Aggregate data separated by blocks (for pooled psychometric)
            if ~isempty(blockIdx)
                AllDVs{blockIdx} = [AllDVs{blockIdx}, SessionDV(blockMask)];
                Choices{blockIdx} = [Choices{blockIdx}, SessionChoice(blockMask)];
            end
            
            % Extract data for this specific block
            BlockDVs = SessionDV(blockMask);
            BlockChoices = SessionChoice(blockMask);
            
            if isempty(BlockDVs) || sum(~isnan(BlockDVs)) < 2
                continue;
            end
            
            % Plot Points
            BinIdx = discretize(BlockDVs, commonBinEdges);
            PsycY = grpstats(BlockChoices, BinIdx, 'mean');
            PsycX = grpstats(BlockDVs, BinIdx, 'mean');
            plot(PsycX, PsycY, 'o', 'MarkerFaceColor', currentColor, ...
                 'MarkerEdgeColor', 'w', 'MarkerSize', 6);
            
            % Plot Fit
            if sum(~isnan(BlockChoices)) > 4
                XFit = linspace(min(BlockDVs)-10*eps, max(BlockDVs)+10*eps, 100);
                YFit = glmval(glmfit(BlockDVs, BlockChoices', 'binomial'), XFit, 'logit');
                plot(XFit, YFit, '-', 'Color', currentColor);
            end
        end
    end
    xlabel('DV'); ylabel('p left')
    hold off

    % Plot the 4 aggregated psychometric curves
    nexttile(FigHandle);
    hold on
    Colors = [unbiasedColor; leftBiasColor; rightBiasColor; lastBlockColor];
    for i = 1:4
        if ~isempty(AllDVs{i}) && sum(~isnan(AllDVs{i})) > 4
            BinIdx = discretize(AllDVs{i}, commonBinEdges);
            PsycY = grpstats(Choices{i}, BinIdx, 'mean');
            PsycX = grpstats(AllDVs{i}, BinIdx, 'mean');
            
            % Plot Points
            plot(PsycX, PsycY, 'o', 'MarkerFaceColor', Colors(i,:), ...
                 'MarkerEdgeColor', 'w', 'MarkerSize', 6);
            
            % Plot Fit
            XFit = linspace(min(AllDVs{i})-10*eps, max(AllDVs{i})+10*eps, 100);
            YFit = glmval(glmfit(AllDVs{i}, Choices{i}', 'binomial'), XFit, 'logit');
            plot(XFit, YFit, '-', 'Color', Colors(i,:));
        end
    end
    xlabel('DV'); ylabel('p left')
    hold off
end

hold off
%% End Psychometric Plot