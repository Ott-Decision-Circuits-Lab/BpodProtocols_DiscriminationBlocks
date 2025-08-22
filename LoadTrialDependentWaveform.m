function LoadTrialDependentWaveform(Player, iTrial, SoundLevel, ClickLength)

global BpodSystem
global TaskParameters

if ~BpodSystem.EmulatorMode
    if nargin <3
        SoundLevel = 1;
    end
    
    if nargin <4
        ClickLength = 2; % in sampling frame
    end

    % load auditory stimuli
    fs = Player.SamplingRate;
    
    if TaskParameters.GUI.AuditoryStimulusType == 1  % Click task
        % Get current block bias from TrialData
        if isfield(BpodSystem.Data.Custom, 'TrialData') && ...
           isfield(BpodSystem.Data.Custom.TrialData, 'BlockNumber') && ...
           iTrial <= length(BpodSystem.Data.Custom.TrialData.BlockNumber)
            currentBlock = BpodSystem.Data.Custom.TrialData.BlockNumber(iTrial);
        else
            currentBlock = 1;  % Fallback
        end

        BlockTableMask = TaskParameters.GUI.BlockTable.BlockNumber == currentBlock;
        CurrentAudBias = TaskParameters.GUI.BlockTable.AudLeftBias(BlockTableMask);

        % Generate click trains with block bias
        [LeftClickTrain, RightClickTrain] = GetClickStimulus(iTrial, TaskParameters.GUI.AuditoryStimulusTime, fs, ClickLength, SoundLevel, 'biasedUniform', CurrentAudBias);

        % Load waveforms
        Player.loadWaveform(3, LeftClickTrain);   % Left channel
        Player.loadWaveform(4, RightClickTrain);  % Right channel
    elseif TaskParameters.GUI.AuditoryStimulusType == 2 % freq task
        warning('Error: Frequency stimulus has not been implemented.');
    end
end

end %LoadTrialDependentWaveform()