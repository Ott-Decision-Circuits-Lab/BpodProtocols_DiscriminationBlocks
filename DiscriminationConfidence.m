function DiscriminationConfidence
% 2-AFC olfactory and auditory discrimination task implented for Bpod 
% (https://github.com/Ott-Decision-Circuits-Lab/Bpod_Gen2)

global BpodSystem
global TaskParameters

TaskParameters = GUISetup();  % Set experiment parameters in GUISetup.m
BpodSystem.SoftCodeHandlerFunction = 'SoftCodeHandler';

% ------------------------Setup Stimuli--------------------------------%
if ~BpodSystem.EmulatorMode
    if ~isfield(BpodSystem.ModuleUSB, 'WavePlayer1') && ~isfield(BpodSystem.ModuleUSB, 'HiFi1')
        warning('Warning: To run this protocol with sound or laser, you will need to pair an Analog Output Module or a HiFi Module(hardware) with its USB port. Click the USB config button on the Bpod console.')
    else
        if isfield(BpodSystem.ModuleUSB, 'HiFi1')
            [Player, ~] = SetupHiFi(192000); % 192kHz = max sampling rate
        end
        if isfield(BpodSystem.ModuleUSB, 'WavePlayer1')
            ChannelNumber = 4;
            [Player, ~] = SetupWavePlayer(ChannelNumber); % 25kHz =sampling rate of 8Ch with 8Ch fully on
        end
        LoadIndependentWaveform(Player);
        LoadTriggerProfileMatrix(Player);
        % SoundChannels = [3];  % Array of channels for each sound: play on left (1), right (2), or both (3)
        % LoadSoundMessages(SoundChannels);
    end
end
BpodSystem.Data.Custom.SessionMeta.OlfactometerStartup = false;
BpodSystem.Data.Custom.SessionMeta.PsychtoolboxStartup = false;
% ---------------------------------------------------------------------%

if TaskParameters.GUI.Photometry
    [FigNidaq1,FigNidaq2]=InitializeNidaq();
end

try
    if TaskParameters.GUI.PharmacologyOn
        prompt = {'Drug name:','Dose:', 'Dosage unit'};
        dlgtitle = 'Pharmacology';
        dims = [1 35];
        definput = {'1x PBS', '1', 'ml/kg i.p.'};
        drugInfo = inputdlg(prompt,dlgtitle,dims, definput);
        BpodSystem.Data.Custom.Pharmacology = drugInfo;
    end
catch
    warning("Pharmacology setup failed.")
end

InitializePlots();

% --------------------------Main loop------------------------------ %
RunSession = true;
iTrial = 1;

while RunSession
    InitializeCustomDataFields(iTrial); % Initialize data (trial type) vectors and first values
    
    SoundLevel = 1;
    ClickLength = 2;
    if BpodSystem.EmulatorMode
        % EMULATOR MODE: Generate click trains dynamically
        % Fetch current block's auditory bias from TrialData
        BlockTableMask = BpodSystem.Data.Custom.TrialData.BlockTableMask;
        BlockBias = TaskParameters.GUI.BlockTable.AudLeftBias(BlockTableMask);  % Get auditory bias from block struct defined by InitializeCustomDataFields.m
        TotalClicks = TaskParameters.GUI.SumRates;
        [LeftClickTrain, RightClickTrain] = GetClickStimulus(iTrial, TaskParameters.GUI.AuditoryStimulusTime, 25000, ClickLength, SoundLevel, 'beta', BlockBias, TotalClicks);
    else
        LoadTrialDependentWaveform(Player, iTrial, SoundLevel, ClickLength); % Load white noise, stimuli trains, and error sound to wave player if not EmulatorMode
        InitiateOlfactometer(iTrial);
        InitiatePsychtoolbox(iTrial);
    end
    
    TaskParameters = BpodParameterGUI('sync', TaskParameters);
    
    sma = StateMatrix(iTrial);
    SendStateMatrix(sma);
    
    % NIDAQ Get nidaq ready to start
    if TaskParameters.GUI.Photometry
        Nidaq_photometry('WaitToStart');
    end
    
    % Run Trial
    RawEvents = RunStateMatrix;
    
    % NIDAQ Stop acquisition and save data in bpod structure
    if TaskParameters.GUI.Photometry
        Nidaq_photometry('Stop');
        [PhotoData,Photo2Data]=Nidaq_photometry('Save');
        NidaqData=PhotoData;
        if TaskParameters.GUI.DbleFibers || TaskParameters.GUI.RedChannel
            Nidaq2Data=Photo2Data;
        else
            Nidaq2Data=[];
        end
        % save separately per trial (too large/slow to save entire history to disk)
        if BpodSystem.Status.BeingUsed ~= 0 %only when bpod still active (due to how bpod stops a protocol this would be run again after the last trial)
            [DataFolder, DataName, ~] = fileparts(BpodSystem.Path.CurrentDataFile);
            NidaqDataFolder = [DataFolder, '\', DataName];
            if ~isdir(NidaqDataFolder)
                mkdir(NidaqDataFolder)
            end
            fname = fullfile(NidaqDataFolder, ['NidaqData',num2str(iTrial),'.mat']);
            save(fname,'NidaqData','Nidaq2Data')
        end
    end
    
    % Bpod save and update custom data fields for this trial
    if ~isempty(fieldnames(RawEvents))
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents);
        InsertSessionDescription(iTrial);
        UpdateCustomDataFields(iTrial);
        SaveBpodSessionData;
    end
    
    % pause conditions    
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    
    if BpodSystem.Status.BeingUsed == 0
        return
    end
    
    if (BpodSystem.Data.TrialStartTimestamp(iTrial) - BpodSystem.Data.TrialStartTimestamp(1))/60 > TaskParameters.GUI.MaxSessionTime
        TaskParameters.GUI.MaxSessionTime = 1000;
        try
            Notify() % optional notify sript in your MATLAB path (not part of protocol)
        catch
        end
        RunProtocol('StartPause')
    end
            
    
    % update hidden TaskParameter fields
    TaskParameters.Figures.OutcomePlot.Position = BpodSystem.ProtocolFigures.SideOutcomePlotFig.Position;
    TaskParameters.Figures.ParameterGUI.Position = BpodSystem.ProtocolFigures.ParameterGUI.Position;
    
    % update behavior plots
    MainPlot(BpodSystem.GUIHandles.OutcomePlot,'update',iTrial);
    
    % update photometry plots
    if TaskParameters.GUI.Photometry
        PlotPhotometryData(iTrial, FigNidaq1, FigNidaq2, PhotoData, Photo2Data);
    end
    
    iTrial = iTrial + 1;
end

if TaskParameters.GUI.Photometry
    CheckPhotometry(PhotoData, Photo2Data);
end

end %DiscriminationConfidence()