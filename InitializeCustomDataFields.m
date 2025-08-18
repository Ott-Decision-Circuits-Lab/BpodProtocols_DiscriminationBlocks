function InitializeCustomDataFields(iTrial)
%{ 
Initializing data (trial type) vectors and first values
%}

global BpodSystem
global TaskParameters

if iTrial == 1
    BpodSystem.Data.Custom.TrialData = [];
end

TDTemp = BpodSystem.Data.Custom.TrialData; % temporary container

% Ensure BlockNumber and BlockTrial exist for this trial before use
if ~isfield(TDTemp, 'BlockNumber')
    TDTemp.BlockNumber = NaN(iTrial,1);  % Pre-allocate if field missing
end
if ~isfield(TDTemp, 'BlockTrial')
    TDTemp.BlockTrial = NaN(iTrial,1);    % Pre-allocate if field missing
end
if ~isfield(TDTemp, 'AudBias')
    TDTemp.AudBias = NaN(iTrial,1);    % Pre-allocate if field missing
end

% Resize arrays to fit current trial index
if length(TDTemp.BlockNumber) < iTrial
    TDTemp.BlockNumber(iTrial) = NaN; % Add a NaN to the end of the array to match length of iTrial
    TDTemp.BlockTrial(iTrial) = NaN;
    TDTemp.AudBias(iTrial) = NaN;
end

TDTemp.TrialNumber(iTrial) = iTrial;


% ---------------------Sample and Choice variables-------------------- %
TDTemp.EarlyWithdrawal(iTrial) = false;
TDTemp.StimDelay(iTrial) = TaskParameters.GUI.StimDelay;
TDTemp.SampleLength(iTrial) = NaN;  %previously ST

TDTemp.ChoiceLeft(iTrial) = NaN;
TDTemp.MoveTime(iTrial) = NaN; %previously MT
TDTemp.ResolutionTime(iTrial) = NaN;
TDTemp.FixBroke(iTrial) = false;
TDTemp.FixDur(iTrial) = NaN;

TDTemp.Feedback(iTrial) = true;
TDTemp.FeedbackTime(iTrial) = NaN;
TDTemp.FeedbackDelay(iTrial) = TaskParameters.GUI.FeedbackDelay;

% determine if catch trial
if iTrial > TaskParameters.GUI.StartEasyTrials
    TDTemp.CatchTrial(iTrial) = rand(1,1)*100 < TaskParameters.GUI.PercentCatch;
else
    TDTemp.CatchTrial(iTrial) = false;
end

% ---------------------------------------------------------------------- %


% -----------------------Reward variables------------------------------ %
TDTemp.LeftRewarded(iTrial) = rand<0.5;
TDTemp.ChoiceCorrect(iTrial) = NaN;
TDTemp.Rewarded(iTrial) = false;
% ---------------------------------------------------------------------- %


% -----------------------Block-dependent variables---------------------- %
% The block determines the signal priors
if iTrial > 1
    if iTrial > TaskParameters.GUI.StartEasyTrials % Allow block transitions after easy trials
        FinalBlock = max(TaskParameters.GUI.BlockTable.BlockNumber);
        if TDTemp.BlockNumber(iTrial-1) < FinalBlock % First three blocks
            BlockNumberMask = TaskParameters.GUI.BlockTable.BlockNumber == TDTemp.BlockNumber(iTrial-1);
            CurrBlockLength = TaskParameters.GUI.BlockTable.BlockLen(BlockNumberMask);
            if TDTemp.BlockTrial(iTrial-1) >= CurrBlockLength  % Block transition
                TDTemp.BlockNumber(iTrial) = TDTemp.BlockNumber(iTrial-1) + 1;
                TDTemp.BlockTrial(iTrial) = 1;
            else  % Continue in same block
                TDTemp.BlockNumber(iTrial) = TDTemp.BlockNumber(iTrial-1);
                TDTemp.BlockTrial(iTrial) = TDTemp.BlockTrial(iTrial-1) + 1;
            end
        else  % Final block, "sticky"
            TDTemp.BlockNumber(iTrial) = TDTemp.BlockNumber(iTrial-1);
            TDTemp.BlockTrial(iTrial) = TDTemp.BlockTrial(iTrial-1) + 1;
        end
    else
        % Early trials: lock to Block 1
        TDTemp.BlockNumber(iTrial) = 1;
        TDTemp.BlockTrial(iTrial) = iTrial;  % Increment trial count within Block 1
    end
else  % First trial
    TDTemp.BlockNumber(iTrial) = 1;
    TDTemp.BlockTrial(iTrial) = 1;
end

% -----------------------Auditory Bias---------------------- %
% Now that BlockNumber is known, define BlockTableMask
TDTemp.BlockTableMask = TaskParameters.GUI.BlockTable.BlockNumber == TDTemp.BlockNumber(iTrial);

% Get current block's auditory bias
TDTemp.CurrentAudBias = TaskParameters.GUI.BlockTable.AudLeftBias(TDTemp.BlockTableMask);

% Override for early trials (Block 1, AudLeftBias = 0.5)
if iTrial <= TaskParameters.GUI.StartEasyTrials
    TDTemp.CurrentAudBias = 0.5;
end

TDTemp.AudBias(iTrial) = TDTemp.CurrentAudBias;

% ---------------------------------------------------------------------- %

% -----------------------Auditory Bias Randomization---------------------- %
if TaskParameters.GUI.RandomizeBiasBlocks
    % Get the indices for blocks 2 and 3
    biasIndices = 2:3;
    % Randomly permute these indices
    randIndices = randperm(length(biasIndices));
    % Apply the permutation to the AudLeftBias array
    TaskParameters.GUI.BlockTable.AudLeftBias(biasIndices) = TaskParameters.GUI.BlockTable.AudLeftBias(biasIndices(randIndices));
end

TDTemp.RewardMagnitudeL(iTrial) = TaskParameters.GUI.RewardAmount;
TDTemp.RewardMagnitudeR(iTrial) = TaskParameters.GUI.RewardAmount;


% -----------------------Stimulus-specific----------------------------- %
TDTemp.DecisionVariable(iTrial) = NaN;  % e.g., relative click rate

% -----Odor----- %
TDTemp.OdorFracA(iTrial) = NaN; % randsample([min(TaskParameters.GUI.OdorTable.OdorFracA) max(TaskParameters.GUI.OdorTable.OdorFracA)],2)';
TDTemp.OdorID(iTrial) = NaN; % 2 - double(TDTemp.OdorFracA > 50);
TDTemp.OdorPair(iTrial) = NaN; % ones(1,2)*2;

% -----Laser----- %
if iTrial > TaskParameters.GUI.StartEasyTrials
    TDTemp.LaserTrial(iTrial) = rand(1,1) < TaskParameters.GUI.LaserTrials;
else
    TDTemp.LaserTrial(iTrial) = false;
end

TDTemp.LaserTrialTrainStart(iTrial) = NaN;
if TDTemp.LaserTrial(iTrial)  % determine laser stimulus delay
    if TaskParameters.GUI.LaserTrainRandStart
        TDTemp.LaserTrialTrainStart(iTrial) = rand(1,1)*(TaskParameters.GUI.LaserTrainStartMax_s-TaskParameters.GUI.LaserTrainStartMin_s) + TaskParameters.GUI.LaserTrainStartMin_s;
        TDTemp.LaserTrialTrainStart(iTrial) = round(TDTemp.LaserTrialTrainStart(iTrial)*10000)/10000;
    else
        TDTemp.LaserTrialTrainStart(iTrial) = TaskParameters.GUI.LaserTrainStartMin_s;
    end
end

% -----Auditory----- %
TDTemp.AuditoryTrial(iTrial) = rand(1,1) < TaskParameters.GUI.PercentAuditory;
TDTemp.ClickTask(iTrial) = TaskParameters.GUI.AuditoryStimulusType == 1;
TDTemp.AuditoryOmega(iTrial) = NaN;

TDTemp.LeftClickRate(iTrial) = NaN;
TDTemp.RightClickRate(iTrial) = NaN;
TDTemp.LeftClickTrain{iTrial} = [];
TDTemp.RightClickTrain{iTrial} = [];

TDTemp.AudFracHigh(iTrial) = NaN;
TDTemp.AudCloud{iTrial} = [];
TDTemp.AudSound{iTrial} = [];
TDTemp.MinSampleAud(iTrial) = TaskParameters.GUI.MinSampleAud;


%% make auditory stimuli for first trials
% function notused
% switch TaskParameters.GUI.AuditoryStimulusType
%     case 1 %click stimuli
%         for a = 1:5
%             if BpodSystem.Data.Custom.AuditoryTrial(iTrial+a)              
%                 %correct left/right click train
%                 if ~isempty(BpodSystem.Data.Custom.LeftClickTrain{iTrial+a}) && ~isempty(BpodSystem.Data.Custom.RightClickTrain{iTrial+a})
%                     BpodSystem.Data.Custom.LeftClickTrain{iTrial+a}(1) = min(BpodSystem.Data.Custom.LeftClickTrain{iTrial+a}(1),BpodSystem.Data.Custom.RightClickTrain{iTrial+a}(1));
%                     BpodSystem.Data.Custom.RightClickTrain{iTrial+a}(1) = min(BpodSystem.Data.Custom.LeftClickTrain{iTrial+a}(1),BpodSystem.Data.Custom.RightClickTrain{iTrial+a}(1));
%                 elseif  isempty(BpodSystem.Data.Custom.LeftClickTrain{iTrial+a}) && ~isempty(BpodSystem.Data.Custom.RightClickTrain{iTrial+a})
%                     BpodSystem.Data.Custom.LeftClickTrain{iTrial+a}(1) = BpodSystem.Data.Custom.RightClickTrain{iTrial+a}(1);
%                 elseif ~isempty(BpodSystem.Data.Custom.LeftClickTrain{iTrial+a}) &&  isempty(BpodSystem.Data.Custom.RightClickTrain{iTrial+a})
%                     BpodSystem.Data.Custom.RightClickTrain{iTrial+a}(1) = BpodSystem.Data.Custom.LeftClickTrain{iTrial+a}(1);
%                 else
%                     BpodSystem.Data.Custom.LeftClickTrain{iTrial+a} = round(1/BpodSystem.Data.Custom.LeftClickRate*10000)/10000;
%                     BpodSystem.Data.Custom.RightClickTrain{iTrial+a} = round(1/BpodSystem.Data.Custom.RightClickRate*10000)/10000;
%                 end
%                 if length(BpodSystem.Data.Custom.LeftClickTrain{iTrial+a}) > length(BpodSystem.Data.Custom.RightClickTrain{iTrial+a})
%                     BpodSystem.Data.Custom.LeftRewarded(iTrial+a) = 1;
%                 elseif length(BpodSystem.Data.Custom.LeftClickTrain{iTrial+a}) < length(BpodSystem.Data.Custom.RightClickTrain{iTrial+a})
%                     BpodSystem.Data.Custom.LeftRewarded(iTrial+a) = 0;
%                 else
%                     BpodSystem.Data.Custom.LeftRewarded(iTrial+a) = rand<0.5;
%                 end
%             else
%                 BpodSystem.Data.Custom.AuditoryOmega(iTrial+a) = NaN;
%                 BpodSystem.Data.Custom.LeftClickRate(iTrial+a) = NaN;
%                 BpodSystem.Data.Custom.RightClickRate(iTrial+a) = NaN;
%                 BpodSystem.Data.Custom.LeftRewarded(iTrial+a) = NaN;
%                 BpodSystem.Data.Custom.LeftClickTrain{iTrial+a} = [];
%                 BpodSystem.Data.Custom.RightClickTrain{iTrial+a} = [];
%             end %if auditory
%         end %for a=1:5           
%     case 2 %freq stimuli
% 
%         StimulusSettings.SamplingRate = TaskParameters.GUI.Aud_SamplingRate; % Sound card sampling rate;
%         StimulusSettings.ramp = TaskParameters.GUI.Aud_Ramp;
%         StimulusSettings.nFreq = TaskParameters.GUI.Aud_nFreq; % Number of different frequencies to sample from
%         StimulusSettings.ToneOverlap = TaskParameters.GUI.Aud_ToneOverlap;
%         StimulusSettings.ToneDuration = TaskParameters.GUI.Aud_ToneDuration;
%         StimulusSettings.Noevidence=TaskParameters.GUI.Aud_NoEvidence;
%         StimulusSettings.minFreq = TaskParameters.GUI.Aud_minFreq ;
%         StimulusSettings.maxFreq = TaskParameters.GUI.Aud_maxFreq ;
%         StimulusSettings.UseMiddleOctave=TaskParameters.GUI.Aud_UseMiddleOctave;
%         StimulusSettings.Volume=TaskParameters.GUI.Aud_Volume;
%         StimulusSettings.nTones = floor((TaskParameters.GUI.AuditoryStimulusTime-StimulusSettings.ToneDuration*StimulusSettings.ToneOverlap)/(StimulusSettings.ToneDuration*(1-StimulusSettings.ToneOverlap))); %number of tones
%       
%         if iTrial > TaskParameters.GUI.StartEasyTrials
%             newFracHigh = randsample(TaskParameters.GUI.Aud_Levels.AudFracHigh,5,1,TaskParameters.GUI.Aud_Levels.AudPFrac)';
%             %include Fifty50 Trials
%             NewFifty50 = rand(5,1) < TaskParameters.GUI.Percent50Fifty;
%             newFracHigh(NewFifty50) = 50;
%         else
%             EasyProb = zeros(numel(TaskParameters.GUI.Aud_Levels.AudPFrac),1);
%             EasyProb(1) = 0.5; EasyProb(end)=0.5;
%             newFracHigh = randsample(TaskParameters.GUI.Aud_Levels.AudFracHigh,5,1,EasyProb)';
%         end
% 
%         newCloud = cell(1,5);
%         newSound = cell(1,5);
%         for a = 1:5
%             if BpodSystem.Data.Custom.AuditoryTrial(iTrial+a)
%                 [Sound, Cloud, ~] = GenerateToneCloudDual(newFracHigh(a)/100, StimulusSettings);
%                 newCloud{a} = Cloud;
%                 newSound{a} = Sound;
%             end
%         end
% 
%         LeftRewarded = newFracHigh>50;
%         LeftRewarded (newFracHigh==050) = rand<0.5;
%         newFracHigh(~newAuditoryTrial) = nan(sum(~newAuditoryTrial),1);
%         BpodSystem.Data.Custom.AudFracHigh = [BpodSystem.Data.Custom.AudFracHigh, newFracHigh];
%         BpodSystem.Data.Custom.AudCloud = [BpodSystem.Data.Custom.AudCloud, newCloud];
%         BpodSystem.Data.Custom.AudSound = [BpodSystem.Data.Custom.AudSound, newSound];
%         BpodSystem.Data.Custom.LeftRewarded = [BpodSystem.Data.Custom.LeftRewarded, LeftRewarded];
%
% end %switch/case auditory stimulus type
%
%
% switch BpodSystem.Data.Custom.ClickTask(iTrial)
%     case true
%         if BpodSystem.Data.Custom.AuditoryTrial(a)
%                 BpodSystem.Data.Custom.AuditoryOmega(a) = betarnd(TaskParameters.GUI.AuditoryAlpha/4,TaskParameters.GUI.AuditoryAlpha/4,1,1);
%                 BpodSystem.Data.Custom.LeftClickRate(a) = round(BpodSystem.Data.Custom.AuditoryOmega(a)*TaskParameters.GUI.SumRates);
%                 BpodSystem.Data.Custom.RightClickRate(a) = round((1-BpodSystem.Data.Custom.AuditoryOmega(a))*TaskParameters.GUI.SumRates);
%                 BpodSystem.Data.Custom.LeftClickTrain{a} = GeneratePoissonClickTrain(BpodSystem.Data.Custom.LeftClickRate(a), TaskParameters.GUI.AuditoryStimulusTime);
%                 BpodSystem.Data.Custom.RightClickTrain{a} = GeneratePoissonClickTrain(BpodSystem.Data.Custom.RightClickRate(a), TaskParameters.GUI.AuditoryStimulusTime);
%                 %correct left/right click train
%                 if ~isempty(BpodSystem.Data.Custom.LeftClickTrain{a}) && ~isempty(BpodSystem.Data.Custom.RightClickTrain{a})
%                     BpodSystem.Data.Custom.LeftClickTrain{a}(1) = min(BpodSystem.Data.Custom.LeftClickTrain{a}(1),BpodSystem.Data.Custom.RightClickTrain{a}(1));
%                     BpodSystem.Data.Custom.RightClickTrain{a}(1) = min(BpodSystem.Data.Custom.LeftClickTrain{a}(1),BpodSystem.Data.Custom.RightClickTrain{a}(1));
%                 elseif  isempty(BpodSystem.Data.Custom.LeftClickTrain{a}) && ~isempty(BpodSystem.Data.Custom.RightClickTrain{a})
%                     BpodSystem.Data.Custom.LeftClickTrain{a}(1) = BpodSystem.Data.Custom.RightClickTrain{a}(1);
%                 elseif ~isempty(BpodSystem.Data.Custom.LeftClickTrain{1}) &&  isempty(BpodSystem.Data.Custom.RightClickTrain{a})
%                     BpodSystem.Data.Custom.RightClickTrain{a}(1) = BpodSystem.Data.Custom.LeftClickTrain{a}(1);
%                 else
%                     BpodSystem.Data.Custom.LeftClickTrain{a} = round(1/BpodSystem.Data.Custom.LeftClickRate*10000)/10000;
%                     BpodSystem.Data.Custom.RightClickTrain{a} = round(1/BpodSystem.Data.Custom.RightClickRate*10000)/10000;
%                 end
%                 
%             if length(BpodSystem.Data.Custom.LeftClickTrain{a}) > length(BpodSystem.Data.Custom.RightClickTrain{a})
%                 BpodSystem.Data.Custom.LeftRewarded(a) = double(1);
%             elseif length(BpodSystem.Data.Custom.LeftClickTrain{1}) < length(BpodSystem.Data.Custom.RightClickTrain{a})
%                 BpodSystem.Data.Custom.LeftRewarded(a) = double(0);
%             else
%                 BpodSystem.Data.Custom.LeftRewarded(a) = rand<0.5;
%             end
%         else
%             BpodSystem.Data.Custom.AuditoryOmega(a) = NaN;
%             BpodSystem.Data.Custom.LeftClickRate(a) = NaN;
%             BpodSystem.Data.Custom.RightClickRate(a) = NaN;
%             BpodSystem.Data.Custom.LeftClickTrain{a} = [];
%             BpodSystem.Data.Custom.RightClickTrain{a} = [];
%         end
%     case false %frequency task
%         StimulusSettings.SamplingRate = TaskParameters.GUI.Aud_SamplingRate; % Sound card sampling rate;
%         StimulusSettings.ramp = TaskParameters.GUI.Aud_Ramp;
%         StimulusSettings.nFreq = TaskParameters.GUI.Aud_nFreq; % Number of different frequencies to sample from
%         StimulusSettings.ToneOverlap = TaskParameters.GUI.Aud_ToneOverlap;
%         StimulusSettings.ToneDuration = TaskParameters.GUI.Aud_ToneDuration;
%         StimulusSettings.Noevidence=TaskParameters.GUI.Aud_NoEvidence;
%         StimulusSettings.minFreq = TaskParameters.GUI.Aud_minFreq ;
%         StimulusSettings.maxFreq = TaskParameters.GUI.Aud_maxFreq ;
%         StimulusSettings.UseMiddleOctave=TaskParameters.GUI.Aud_UseMiddleOctave;
%         StimulusSettings.Volume=TaskParameters.GUI.Aud_Volume;
%         StimulusSettings.nTones = floor((TaskParameters.GUI.AuditoryStimulusTime-StimulusSettings.ToneDuration*StimulusSettings.ToneOverlap)/(StimulusSettings.ToneDuration*(1-StimulusSettings.ToneOverlap))); %number of tones
%         
%         EasyProb = zeros(numel(TaskParameters.GUI.Aud_Levels.AudPFrac),1);
%         EasyProb(1) = 0.5; EasyProb(end)=0.5;
%         newFracHigh = randsample(TaskParameters.GUI.Aud_Levels.AudFracHigh,1,1,EasyProb);
%         [Sound, Cloud, ~] = GenerateToneCloudDual(newFracHigh/100, StimulusSettings);
%         BpodSystem.Data.Custom.AudFracHigh(a) = newFracHigh;
%         BpodSystem.Data.Custom.AudCloud{a} = Cloud;
%         BpodSystem.Data.Custom.AudSound{a} = Sound;
%         BpodSystem.Data.Custom.LeftRewarded(a)= newFracHigh>50;
% end % switch BpodSystem.Data.Custom.ClickTask(iTrial)

% ---------------------------------------------------------------------- %


% Write temporary data container to Custom Data
BpodSystem.Data.Custom.TrialData = TDTemp;

end %InitializeCustomDataFields
