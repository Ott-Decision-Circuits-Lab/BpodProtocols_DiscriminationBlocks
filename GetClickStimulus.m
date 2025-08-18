function [LeftClickTrain,RightClickTrain] = GetClickStimulus(iTrial, Duration, SamplingRate, ClickLength, SoundLevel, Mode, BlockBias)

global TaskParameters
global BpodSystem

if nargin < 6 || isempty(BlockBias)
    BlockBias = TaskParameters.GUI.LeftBiasAud;  % Fallback for legacy code
end
if nargin<5
    SoundLevel = 0.8;
end
if nargin<4
    ClickLength = 1;
end
if nargin<3
    SamplingRate = 25000; % in Hz
end
if nargin<2
    Duration = 1; % in seconds
end

% draw ClickRate for left and right sound
switch Mode
    case 'uniform'
        rr = rand(1,1)*0.6+0.2;
        LeftClickRate = ceil(rr*100);
        RightClickRate = 100 - LeftClickRate;
        
        LeftClickTrain = GeneratePoissonClickTrain(LeftClickRate, Duration, SamplingRate, ClickLength);
        RightClickTrain = GeneratePoissonClickTrain(RightClickRate, Duration, SamplingRate, ClickLength);

    case 'biasedUniform'

        % Determine the probability of left-leaning and right-leaning signals
        LeftProb = BlockBias;
        RightProb = 1 - BlockBias;

        % Generate a random number to determine the side of the bias
        if rand(1,1) < LeftProb
            % Left-leaning signal
            BiasSide = 'left';
        else
            % Right-leaning signal
            BiasSide = 'right';
        end

        % Generate a uniform distribution of difficulty levels
        DifficultyLevel = rand(1,1);

        % Determine the click rates based on the difficulty level and bias side
        if strcmp(BiasSide, 'left')
            LeftClickRate = ceil(DifficultyLevel * 100);
            RightClickRate = 100 - LeftClickRate;
        else
            RightClickRate = ceil(DifficultyLevel * 100);
            LeftClickRate = 100 - RightClickRate;
        end

        LeftClickTrain = GeneratePoissonClickTrain(LeftClickRate, Duration, SamplingRate, ClickLength);
        RightClickTrain = GeneratePoissonClickTrain(RightClickRate, Duration, SamplingRate, ClickLength);

  
    case 'beta'
        if iTrial > TaskParameters.GUI.StartEasyTrials
            AuditoryAlpha = TaskParameters.GUI.AuditoryAlpha;
        else
            AuditoryAlpha = TaskParameters.GUI.AuditoryAlpha/4;
        end
        
        BetaRatio = min(0.9, max(0.1, BlockBias)) / (1 - min(0.9, max(0.1, BlockBias)));
        %use a = ratio*b to yield E[X] = LeftBiasAud using Beta(a,b) pdf
        %cut off between 0.1-0.9 to prevent extreme values (only one side) and div by zero
        BetaA =  (2*AuditoryAlpha*BetaRatio) / (1+BetaRatio); %make a,b symmetric around AuditoryAlpha to make B symmetric
        BetaB = (AuditoryAlpha-BetaA) + AuditoryAlpha;
        
        if rand(1,1) < TaskParameters.GUI.Percent50Fifty && iTrial > TaskParameters.GUI.StartEasyTrials
            BpodSystem.Data.Custom.TrialData.AuditoryOmega(iTrial) = 0.5;  % 50/50 trials
        else
            BpodSystem.Data.Custom.TrialData.AuditoryOmega(iTrial) = betarnd(max(0,BetaA), max(0,BetaB),1,1);
        end
                
        LeftClickRate = round(BpodSystem.Data.Custom.TrialData.AuditoryOmega(iTrial)*TaskParameters.GUI.SumRates);
        RightClickRate = TaskParameters.GUI.SumRates - LeftClickRate;
        
        LeftClickTrain = GeneratePoissonClickTrain(LeftClickRate, Duration, SamplingRate, ClickLength);
        RightClickTrain = GeneratePoissonClickTrain(RightClickRate, Duration, SamplingRate, ClickLength);
        
        if BpodSystem.Data.Custom.TrialData.AuditoryOmega(iTrial) == 0.5 %make sure 50/50 are true 50/50 trials
            while abs(sum(LeftSound) - sum(RightSound)) >= ClickLength
                LeftClickTrain = GeneratePoissonClickTrain(BpodSystem.Data.Custom.TrialData.LeftClickRate(iTrial), Duration, SamplingRate, ClickLength);
                RightClickTrain = GeneratePoissonClickTrain(BpodSystem.Data.Custom.TrialData.RightClickRate(iTrial), Duration, SamplingRate, ClickLength);
            end
        end
end

LeftClickTrain = LeftClickTrain * SoundLevel;
RightClickTrain = RightClickTrain * SoundLevel;

if sum(LeftClickTrain) - sum(RightClickTrain) >= ClickLength
    BpodSystem.Data.Custom.TrialData.LeftRewarded(iTrial) = double(1);
elseif sum(RightClickTrain) - sum(LeftClickTrain) >= ClickLength
    BpodSystem.Data.Custom.TrialData.LeftRewarded(iTrial) = double(0);
else
    BpodSystem.Data.Custom.TrialData.LeftRewarded(iTrial) = rand<0.5;
end

BpodSystem.Data.Custom.TrialData.LeftClickRate(iTrial) = LeftClickRate;
BpodSystem.Data.Custom.TrialData.RightClickRate(iTrial) = RightClickRate;
BpodSystem.Data.Custom.TrialData.LeftClickTrain{iTrial} = LeftClickTrain;
BpodSystem.Data.Custom.TrialData.RightClickTrain{iTrial} = RightClickTrain;
BpodSystem.Data.Custom.TrialData.DecisionVariable(iTrial) = (sum(LeftClickTrain)-sum(RightClickTrain))./(sum(LeftClickTrain)+sum(RightClickTrain));

end