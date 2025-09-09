function SessionData = getAnalysisValues(joinedData, cutTimeMin)

% Get analysis values for discrimination blocks from joinedData struct, make it into a linear SessionData struct

if nargin < 2
    cutTimeMin = [NaN, NaN];
end

% Calculate needed array sizes
%nTrialsArray = [joinedData.nTrials];
%nTrials = sum(nTrialsArray);

% Arrays to be filled loop by loop
DecisionVariable = [];
ChoiceLeft = [];
SampleLength = [];
CatchTrial = [];
Feedback = [];
ChoiceCorrect = [];
BlockNumber = [];
FixDur = [];
allRawEvents = [];
allTrialStartTimesSec_Concatenated = [];
sessionStartIdxs = 1;

% For pre-allocation
% DecisionVariable = nan(1, nTrials);
% ChoiceLeft = nan(1, nTrials);
% ST = nan(1, nTrials);
% CatchTrial = nan(1, nTrials);
% Feedback = nan(1, nTrials);
% Correct = nan(1, nTrials);
% BlockNumber = nan(1, nTrials);

ratIDs = nan(1, height(joinedData));
date = NaT(1, height(joinedData)); % Requires NaT instead of NaN
allTrialsStartTimesSec = nan(length(joinedData), max([joinedData.nTrials]-1)); % Columns = sessions, rows = trials, last trial is aborted
nTrialsArray = nan(1, height(joinedData));
behavioralValidations = nan(1, height(joinedData));
allRawEventsMatrix = cell(size(allTrialsStartTimesSec));

drugNames = cell(1, height(joinedData));
drugDoses = nan(1, height(joinedData));
drugDosageUnits = cell(1, height(joinedData));

nEasyTrials = nan(1, height(joinedData));

% TO DO: pre-allocate to avoid copying with each iteration
for n = 1:size(joinedData, 1)

    ratIDs(n) = str2double(joinedData(n).Info.Subject);
    date(n) = datetime(joinedData(n).Info.SessionDate);
    
    try
        behavioralValidations(n) = joinedData(n).Custom.SessionMeta.BehaviouralValidation;
    catch
        fprintf('No behavioral validation available for session R%s on %s\n', [string(ratIDs(n)); string(date(n))])
    end
    
    %% Cut time implementation + exclusion of missed trials at the end of session due to prolonged inactivity
    allCin = ~isnan(joinedData(n).Custom.TrialData.FixDur); % Array indicating whether there was a center poke
    if all(~isnan(cutTimeMin)) % Lower and upper cut time specified
        %nTrials = sum(joinedData(n).TrialStartTimestamp/60 <= cutTimeMin);
        firstTrialIdx = find(joinedData(n).TrialStartTimestamp/60 >= cutTimeMin(1), 1); % Get index of first trial after the lower cut time
        lastTrialIdx = find(joinedData(n).TrialStartTimestamp/60 <= cutTimeMin(2), 1, 'Last'); % Get index of last trial before the upper cut time
    elseif isnan(cutTimeMin(1)) && ~isnan(cutTimeMin(2)) % Second cut time only, analyse everything up to there
        firstTrialIdx = 1;
        lastTrialIdx = find(joinedData(n).TrialStartTimestamp/60 <= cutTimeMin(2), 1, 'Last');
    elseif ~isnan(cutTimeMin(1)) && isnan(cutTimeMin(2)) % First cut time only, analyse everything starding from there
        firstTrialIdx = find(joinedData(n).TrialStartTimestamp/60 >= cutTimeMin(1), 1);
        for idx = 1:joinedData(n).nTrials % Loop backward to find last valid trial
            if allCin(end-idx) == 0
                continue
            else
                lastTrialIdx = joinedData(n).nTrials - idx; % Exclude missed trials at the end of each session
                break
            end
        end   
    else % cutTimeMin = [NaN, NaN]
        %nTrials = joinedData(n).nTrials-1; % the last trial is aborted
        firstTrialIdx = 1;
        if n == 7
            pause = "pause";
        end
        for idx = 1:joinedData(n).nTrials % Loop backward to find last valid trial
            if ~allCin(end-idx) || ~allCin(end-idx-1)
                continue
            else
                lastTrialIdx = joinedData(n).nTrials - idx; % Exclude missed trials at the end of each session
                break
            end
        end     
    end
    
    % In case the cut time exceeds the maximum in the session
    if lastTrialIdx >= length(joinedData(n).Custom.TrialData.ChoiceLeft)
       lastTrialIdx = lastTrialIdx - 1; % Last trial is aborted
    end
    
    nTrials = lastTrialIdx - firstTrialIdx + 1;
    nTrialsArray(n) = nTrials;
    
    % Find indices of first trial of each session in the concatenated data
    sessionStartIdxs = [sessionStartIdxs, sessionStartIdxs(n) + nTrials];
    if n == length(joinedData) % For the very last session, 
        sessionStartIdxs = sessionStartIdxs(1:end-1); % chop off the last value so its length matches the number of sessions
    end

    %% Pharmacology / treatment condition
    if isfield(joinedData(n).Custom, 'Pharmacology')
        drugName = joinedData(n).Custom.Pharmacology{1}; % E.g. '1x PBS'
        drugDose = joinedData(n).Custom.Pharmacology{2}; % E.g. 1
        drugDosageUnit = joinedData(n).Custom.Pharmacology{3}; % E.g. 'ml/kg i.p.'
        drugNames{n} = drugName;
        if isstring(drugDose) | ischar(drugDose)
            drugDoses(n) = str2double(drugDose);
        else
            drugDoses(n) = drugDose;
        end
        drugDosageUnits{n} = drugDosageUnit;
    else % Pharmacology off
        drugNames{n} = {};
    end
    
    %% Exclusion of easy trials
    nEasyTrials(n) = joinedData(n).SettingsFile.GUI.StartEasyTrials;
    %signalChoices = [signalChoices, joinedData(n).Custom.TrialData.ResponseLeft(1:nTrials)]; % No filtering. Requires filtering of easy trials later
    %signalChoices = [signalChoices, nan(1, nEasyTrials(n)), joinedData(n).Custom.TrialData.ResponseLeft(nEasyTrials(n)+1:nTrials)]; % Filtering out easy trials here
    joinedData(n).Custom.TrialData.ResponseLeft(1:nEasyTrials(n)) = NaN; % Warning: directly erases first 30 responses in the original array. TO DO: MUST RETURN JOINED DATA TO SAVE CHANGES

    %% Populate trial-by-trial variables by appending data from one session at a time
    % Trial-by-trial variables, indexed by subsection of trials selected by cutTime and exclusion of inactive trials at the end of a session
    
    % Complicated to pre-allocate.
    DecisionVariable = [DecisionVariable, joinedData(n).Custom.TrialData.DecisionVariable(firstTrialIdx:lastTrialIdx)];
    ChoiceLeft = [ChoiceLeft, joinedData(n).Custom.TrialData.ChoiceLeft(firstTrialIdx:lastTrialIdx)];
    SampleLength = [SampleLength, joinedData(n).Custom.TrialData.SampleLength(firstTrialIdx:lastTrialIdx)];
    CatchTrial = [CatchTrial, joinedData(n).Custom.TrialData.CatchTrial(firstTrialIdx:lastTrialIdx)];
    Feedback = [Feedback, joinedData(n).Custom.TrialData.Feedback(firstTrialIdx:lastTrialIdx)];
    ChoiceCorrect = [ChoiceCorrect, joinedData(n).Custom.TrialData.ChoiceCorrect(firstTrialIdx:lastTrialIdx)];
    BlockNumber = [BlockNumber, joinedData(n).Custom.TrialData.BlockNumber(firstTrialIdx:lastTrialIdx)];
    FixDur = [FixDur, joinedData(n).Custom.TrialData.FixDur(firstTrialIdx:lastTrialIdx)];

    % Raw events
    allRawEvents = [allRawEvents, joinedData(n).RawEvents.Trial(firstTrialIdx:lastTrialIdx)]; % An array
    allRawEventsMatrix(n, 1:nTrialsArray(n)) = joinedData(n).RawEvents.Trial(firstTrialIdx:lastTrialIdx);

    % Timestamps of initiated trials
    allTrialStartTimesSec_Concatenated = [allTrialStartTimesSec_Concatenated, joinedData(n).TrialStartTimestamp(firstTrialIdx:lastTrialIdx)]; % An array
    allTrialsStartTimesSec(n, 1:nTrialsArray(n)) = joinedData(n).TrialStartTimestamp(firstTrialIdx:lastTrialIdx); % A matrix

end

nTrials = sum(nTrialsArray);

TDTemp.DecisionVariable = DecisionVariable;
TDTemp.ChoiceLeft = ChoiceLeft;
TDTemp.SampleLength = SampleLength;
TDTemp.CatchTrial = CatchTrial;
TDTemp.Feedback = Feedback;
TDTemp.ChoiceCorrect = ChoiceCorrect;
TDTemp.BlockNumber = BlockNumber;
TDTemp.FixDur = FixDur;
TDTemp.allTrialStartTimesSec_Concatenated = allTrialStartTimesSec_Concatenated;

valueNames = {'date', 'nTrials' 'nTrialsArray', 'ratIDs', 'allRawEventsMatrix', 'allTrialsStartTimesSec', ...,
    'nEasyTrials', 'drugNames', 'drugDoses', 'drugDosageUnits', ...,
    'behavioralValidations'};

values = {date, nTrials, nTrialsArray, ratIDs, allRawEventsMatrix, allTrialsStartTimesSec, ...,
    nEasyTrials, drugNames, drugDoses, drugDosageUnits, ...,
    behavioralValidations};

SessionData = cell2struct(values, valueNames, 2);

SessionData.Custom.TrialData = TDTemp;
SessionData.RawEvents.Trial = allRawEvents;

elapsedTime = toc;
fprintf('getAnalysisValues: %.2f seconds\n', elapsedTime);

end
