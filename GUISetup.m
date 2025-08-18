function TaskParameters = GUISetup()
global BpodSystem

%% Task parameters
TaskParameters = BpodSystem.ProtocolSettings;
if isempty(fieldnames(TaskParameters))
    %% General
    TaskParameters.GUI.EphysSession = false;
    TaskParameters.GUIMeta.EphysSession.Style = 'checkbox';
    TaskParameters.GUI.PharmacologyOn = false;
    TaskParameters.GUIMeta.PharmacologyOn.Style = 'checkbox';
    TaskParameters.GUI.RandomizeBiasBlocks = false;
    TaskParameters.GUIMeta.RandomizeBiasBlocks.Style = 'checkbox';
    TaskParameters.GUIMeta.RandomizeBiasBlocks.String = 'Randomize blocks 2 and 3';
    TaskParameters.GUI.SessionDescription = 'abc';
    TaskParameters.GUIMeta.SessionDescription.Style = 'edittext';
    TaskParameters.GUI.ITI = 1; 
    TaskParameters.GUI.PreITI = 0; 
    TaskParameters.GUI.CenterWaitMax = 20; 
    TaskParameters.GUI.RewardAmount = 20;
    TaskParameters.GUI.DrinkingTime = 5;
    TaskParameters.GUI.DrinkingGrace = 0.1;
    TaskParameters.GUI.ChoiceDeadLine = 3;
    TaskParameters.GUI.TimeOutIncorrectChoice = 0; % (s)
    TaskParameters.GUI.TimeOutBrokeFixation = 3; % (s)
    TaskParameters.GUI.TimeOutEarlyWithdrawal = 3; % (s)
    TaskParameters.GUI.TimeOutSkippedFeedback = 0; % (s)
    TaskParameters.GUI.PercentAuditory = 1;
    TaskParameters.GUI.StartEasyTrials = 30;
    TaskParameters.GUI.Percent50Fifty = 0;
    TaskParameters.GUI.PercentCatch = 0;
    TaskParameters.GUI.CatchError = false;
    TaskParameters.GUIMeta.CatchError.Style = 'checkbox';
    TaskParameters.GUI.Ports_LMR = 123;
    TaskParameters.GUI.MaxSessionTime = 180;
    TaskParameters.GUI.PortLEDs = true;
    TaskParameters.GUIMeta.PortLEDs.Style = 'checkbox';
    TaskParameters.GUIPanels.General = {'EphysSession','PharmacologyOn','SessionDescription',...
                                        'MaxSessionTime','CenterWaitMax','ITI',...
                                        'PreITI','RewardAmount','DrinkingTime','DrinkingGrace',...
                                        'ChoiceDeadLine','TimeOutIncorrectChoice',...
                                        'TimeOutBrokeFixation','TimeOutEarlyWithdrawal',...
                                        'TimeOutSkippedFeedback','PercentAuditory',...
                                        'StartEasyTrials','Percent50Fifty','PercentCatch',...
                                        'CatchError','Ports_LMR','PortLEDs'};
    
    %% BiasControl
    TaskParameters.GUI.TrialSelection = 3;
    TaskParameters.GUIMeta.TrialSelection.Style = 'popupmenu';
    TaskParameters.GUIMeta.TrialSelection.String = {'Flat','Manual','BiasCorrecting','Competitive'};
    TaskParameters.GUIPanels.BiasControl = {'TrialSelection'};
    
    %% StimDelay
    TaskParameters.GUI.StimDelayAutoincrement = 0;
    TaskParameters.GUIMeta.StimDelayAutoincrement.Style = 'checkbox';
    TaskParameters.GUIMeta.StimDelayAutoincrement.String = 'Auto';
    TaskParameters.GUI.StimDelayMin = 0.2;
    TaskParameters.GUI.StimDelayMax = 0.4;
    TaskParameters.GUI.StimDelayIncr = 0.01;
    TaskParameters.GUI.StimDelayDecr = 0.01;
    TaskParameters.GUI.StimDelay = TaskParameters.GUI.StimDelayMin;
    TaskParameters.GUIMeta.StimDelay.Style = 'text';
    TaskParameters.GUIPanels.StimDelay = {'StimDelayAutoincrement','StimDelayMin','StimDelayMax',...
                                          'StimDelayIncr','StimDelayDecr','StimDelay'};
    
    %% FeedbackDelay
    TaskParameters.GUI.FeedbackDelaySelection = 1;
    TaskParameters.GUIMeta.FeedbackDelaySelection.Style = 'popupmenu';
    TaskParameters.GUIMeta.FeedbackDelaySelection.String = {'Fix','AutoIncr','TruncExp'};
    TaskParameters.GUI.FeedbackDelayMin = 0.5;
    TaskParameters.GUI.FeedbackDelayMax = 0;
    TaskParameters.GUI.FeedbackDelayIncr = 0.01;
    TaskParameters.GUI.FeedbackDelayDecr = 0.01;
    TaskParameters.GUI.FeedbackDelayTau = 1.5;
    TaskParameters.GUI.FeedbackDelayGrace = 0;
    TaskParameters.GUI.IncorrectChoiceFeedbackType = 2;
    TaskParameters.GUIMeta.IncorrectChoiceFeedbackType.Style = 'popupmenu';
    TaskParameters.GUIMeta.IncorrectChoiceFeedbackType.String = {'None','Tone','PortLED'};
    TaskParameters.GUI.SkippedFeedbackFeedbackType = 2;
    TaskParameters.GUIMeta.SkippedFeedbackFeedbackType.Style = 'popupmenu';
    TaskParameters.GUIMeta.SkippedFeedbackFeedbackType.String = {'None','Tone','PortLED'};
    TaskParameters.GUI.FeedbackDelay = TaskParameters.GUI.FeedbackDelayMin;
    TaskParameters.GUIMeta.FeedbackDelay.Style = 'text';
    TaskParameters.GUIPanels.FeedbackDelay = {'FeedbackDelaySelection','FeedbackDelayMin',...
                                              'FeedbackDelayMax','FeedbackDelayIncr',...
                                              'FeedbackDelayDecr','FeedbackDelayTau',...
                                              'FeedbackDelayGrace','FeedbackDelay',...
                                              'IncorrectChoiceFeedbackType',...
                                              'SkippedFeedbackFeedbackType'};
    
    %% OdorParams
    TaskParameters.GUI.OdorA_bank = 3;
    TaskParameters.GUI.OdorB_bank = 4;
    TaskParameters.GUIPanels.Olfactometer = {'OdorA_bank', 'OdorB_bank'};
    
%     TaskParameters.GUI.OdorSettings = 0;
%     TaskParameters.GUIMeta.OdorSettings.Style = 'pushbutton';
%     TaskParameters.GUIMeta.OdorSettings.String = 'Odor settings';
%     TaskParameters.GUIMeta.OdorSettings.Callback = @GUIOdorSettings;
    
    TaskParameters.GUI.OdorTable.OdorFracA = 50+[-1; 1]*round(logspace(log10(6),log10(90),3)/2);
    TaskParameters.GUI.OdorTable.OdorFracA = sort(TaskParameters.GUI.OdorTable.OdorFracA(:));
    TaskParameters.GUI.OdorTable.OdorFracA = [5, 30, 45, 55, 70, 95]';
    TaskParameters.GUI.OdorTable.OdorProb = ones(size(TaskParameters.GUI.OdorTable.OdorFracA))/numel(TaskParameters.GUI.OdorTable.OdorFracA);
    TaskParameters.GUIMeta.OdorTable.Style = 'table';
    TaskParameters.GUIMeta.OdorTable.String = 'Odor probabilities';
    TaskParameters.GUIMeta.OdorTable.ColumnLabel = {'a = Frac Odor A','P(a)'};
    TaskParameters.GUI.OdorStimulusTimeMin = 0;
    TaskParameters.GUIPanels.OlfStimuli = {'OdorTable','OdorStimulusTimeMin'};
    
    %% Auditory Params
    %clicks
    TaskParameters.GUI.AuditoryAlpha = 1;
    TaskParameters.GUI.LeftBiasAud = 0.5;
    TaskParameters.GUIMeta.LeftBiasAud.Style = 'text';
    TaskParameters.GUI.SumRates = 100;
    
    %zador freq stimuli
    TaskParameters.GUI.Aud_nFreq = 18;
    TaskParameters.GUI.Aud_NoEvidence = 0;
    TaskParameters.GUI.Aud_minFreq = 200;
    TaskParameters.GUI.Aud_maxFreq = 20000;
    TaskParameters.GUI.Aud_Volume = 70;
    TaskParameters.GUI.Aud_ToneDuration = 0.03;
    TaskParameters.GUI.Aud_ToneOverlap = 0.6667;
    TaskParameters.GUI.Aud_Ramp = 0.003;
    TaskParameters.GUI.Aud_SamplingRate = 192000;
    TaskParameters.GUI.Aud_UseMiddleOctave=0;
    TaskParameters.GUI.Aud_Levels.AudFracHigh = [5, 30, 45, 55, 70, 95]';
    TaskParameters.GUI.Aud_Levels.AudPFrac = ones(size(TaskParameters.GUI.Aud_Levels.AudFracHigh))/numel(TaskParameters.GUI.Aud_Levels.AudFracHigh);
    TaskParameters.GUIMeta.Aud_Levels.Style = 'table';
    TaskParameters.GUIMeta.Aud_Levels.String = 'Freq probabilities';
    TaskParameters.GUIMeta.Aud_Levels.ColumnLabel = {'a = Frac high','P(a)'};
    
    %min auditory stimulus and general stuff
    TaskParameters.GUI.AuditoryStimulusTime = 0.35;
    TaskParameters.GUI.AuditoryStimulusType = 1;
    TaskParameters.GUIMeta.AuditoryStimulusType.Style = 'popupmenu';
    TaskParameters.GUIMeta.AuditoryStimulusType.String = {'Clicks','Freqs'};
    
    TaskParameters.GUI.MinSampleAudMin = 0.35;
    TaskParameters.GUI.MinSampleAudMax = 0.35;
    TaskParameters.GUI.MinSampleAudAutoincrement = false;
    TaskParameters.GUIMeta.MinSampleAudAutoincrement.Style = 'checkbox';
    TaskParameters.GUI.MinSampleAudIncr = 0.05;
    TaskParameters.GUI.MinSampleAudDecr = 0.02;
    TaskParameters.GUI.MinSampleAud = TaskParameters.GUI.MinSampleAudMin;
    TaskParameters.GUIMeta.MinSampleAud.Style = 'text';
    TaskParameters.GUIPanels.AudGeneral = {'AuditoryStimulusType','AuditoryStimulusTime'};
    TaskParameters.GUIPanels.AudClicks = {'AuditoryAlpha','LeftBiasAud','SumRates'};
    TaskParameters.GUIPanels.AudFreq = {'Aud_nFreq','Aud_NoEvidence','Aud_minFreq','Aud_maxFreq','Aud_Volume','Aud_ToneDuration','Aud_ToneOverlap','Aud_Ramp','Aud_SamplingRate','Aud_UseMiddleOctave'};
    TaskParameters.GUIPanels.AudFreqLevels = {'Aud_Levels'};
    TaskParameters.GUIPanels.AudMinSample= {'MinSampleAudMin','MinSampleAudMax','MinSampleAudAutoincrement','MinSampleAudIncr','MinSampleAudDecr','MinSampleAud'};
    
    %% Block structure
    TaskParameters.GUI.BlockTable.BlockNumber = [1, 2, 3, 4]';
    TaskParameters.GUI.BlockTable.BlockLen = ones(4,1)*5000;
    TaskParameters.GUI.BlockTable.AudLeftBias = [0.5, 0.7, 0.3, 0.5]';  % Left bias per block
    %TaskParameters.GUI.BlockTable.RewL = [1 randsample([1 .6],2) 1]';
    %TaskParameters.GUI.BlockTable.RewR = flipud(TaskParameters.GUI.BlockTable.RewL);
    TaskParameters.GUIMeta.BlockTable.Style = 'table';
    TaskParameters.GUIMeta.BlockTable.String = 'Block structure';
    TaskParameters.GUIMeta.BlockTable.ColumnLabel = {'Block#','Block Length','Aud Left Bias'};
    TaskParameters.GUIPanels.BlockStructure = {'BlockTable', 'RandomizeBiasBlocks'};
    
    %% Plots
    %Show Plots
    TaskParameters.GUI.ShowPsycOlf = 0;
    TaskParameters.GUIMeta.ShowPsycOlf.Style = 'checkbox';

    TaskParameters.GUI.ShowPsycAud = 1;
    TaskParameters.GUIMeta.ShowPsycAud.Style = 'checkbox';

    TaskParameters.GUI.ShowVevaiometric = 1;
    TaskParameters.GUIMeta.ShowVevaiometric.Style = 'checkbox';

    TaskParameters.GUI.ShowTrialRate = 1;
    TaskParameters.GUIMeta.ShowTrialRate.Style = 'checkbox';

    TaskParameters.GUI.ShowFix = 1;
    TaskParameters.GUIMeta.ShowFix.Style = 'checkbox';

    TaskParameters.GUI.ShowSampleLength = 1;
    TaskParameters.GUIMeta.ShowSampleLength.Style = 'checkbox';

    TaskParameters.GUI.ShowFeedback = 1;
    TaskParameters.GUIMeta.ShowFeedback.Style = 'checkbox';

    TaskParameters.GUIPanels.ShowPlots = {'ShowPsycOlf','ShowPsycAud','ShowVevaiometric','ShowTrialRate','ShowFix','ShowSampleLength','ShowFeedback'};
    
    %Vevaiometric
    TaskParameters.GUI.VevaiometricMinWT = 2;
    TaskParameters.GUI.VevaiometricNBin = 8;
    TaskParameters.GUI.VevaiometricShowPoints = 1;
    TaskParameters.GUIMeta.VevaiometricShowPoints.Style = 'checkbox';
    TaskParameters.GUIPanels.Vevaiometric = {'VevaiometricMinWT','VevaiometricNBin','VevaiometricShowPoints'};
    
    %% Laser
    TaskParameters.GUI.LaserTrials = false;
    TaskParameters.GUI.LaserSoftCode = false;
    TaskParameters.GUIMeta.LaserSoftCode.Style='checkbox';
    TaskParameters.GUI.LaserAmp = 5;
    TaskParameters.GUI.LaserStimFreq = 0;
    TaskParameters.GUI.LaserPulseDuration_ms = 1;
    TaskParameters.GUI.LaserTrainDuration_ms = 0;
    TaskParameters.GUI.LaserRampDuration_ms = 0;
    TaskParameters.GUI.LaserTrainRandStart = false;
    TaskParameters.GUIMeta.LaserTrainRandStart.Style='checkbox';
    TaskParameters.GUI.LaserTrainStartMin_s = 0;
    TaskParameters.GUI.LaserTrainStartMax_s = 5;
    TaskParameters.GUI.LaserITI = 0; TaskParameters.GUIMeta.LaserITI.Style = 'checkbox';
    TaskParameters.GUI.LaserPreStim = 0; TaskParameters.GUIMeta.LaserPreStim.Style = 'checkbox';
    TaskParameters.GUI.LaserStim = 0; TaskParameters.GUIMeta.LaserStim.Style = 'checkbox';
    TaskParameters.GUI.LaserMov = 0; TaskParameters.GUIMeta.LaserMov.Style = 'checkbox';
    TaskParameters.GUI.LaserTimeInvestment = 1; TaskParameters.GUIMeta.LaserTimeInvestment.Style = 'checkbox';
    TaskParameters.GUI.LaserRew = 0; TaskParameters.GUIMeta.LaserRew.Style = 'checkbox';
    TaskParameters.GUI.LaserFeedback = 0; TaskParameters.GUIMeta.LaserFeedback.Style = 'checkbox';
    TaskParameters.GUIPanels.LaserGeneral = {'LaserTrials','LaserSoftCode','LaserAmp','LaserStimFreq','LaserPulseDuration_ms'};
    TaskParameters.GUIPanels.LaserTrain = {'LaserTrainDuration_ms','LaserTrainRandStart','LaserRampDuration_ms','LaserTrainStartMin_s','LaserTrainStartMax_s'};
    TaskParameters.GUIPanels.LaserTaskEpochs = {'LaserITI','LaserPreStim','LaserStim','LaserMov','LaserTimeInvestment','LaserRew','LaserFeedback'};
    
    %% Video
    TaskParameters.GUI.Wire1VideoTrigger = false;
    TaskParameters.GUIMeta.Wire1VideoTrigger.Style = 'checkbox';
    TaskParameters.GUI.VideoTrials = 1;
    TaskParameters.GUIMeta.VideoTrials.Style = 'popupmenu';
    TaskParameters.GUIMeta.VideoTrials.String = {'Investment','All'};
    TaskParameters.GUIPanels.VideoGeneral = {'Wire1VideoTrigger','VideoTrials'};
    
    %% Photometry
    %photometry general
    TaskParameters.GUI.Photometry=false;
    TaskParameters.GUIMeta.Photometry.Style='checkbox';
    TaskParameters.GUI.DbleFibers=0;
    TaskParameters.GUIMeta.DbleFibers.Style='checkbox';
    TaskParameters.GUIMeta.DbleFibers.String='Auto';
    TaskParameters.GUI.Isobestic405=0;
    TaskParameters.GUIMeta.Isobestic405.Style='checkbox';
    TaskParameters.GUIMeta.Isobestic405.String='Auto';
    TaskParameters.GUI.RedChannel=1;
    TaskParameters.GUIMeta.RedChannel.Style='checkbox';
    TaskParameters.GUIMeta.RedChannel.String='Auto';    
    TaskParameters.GUIPanels.PhotometryRecording={'Photometry','DbleFibers','Isobestic405','RedChannel'};
    
    %plot photometry
    TaskParameters.GUI.TimeMin=-4;
    TaskParameters.GUI.TimeMax=4;
    TaskParameters.GUI.NidaqMin=-5;
    TaskParameters.GUI.NidaqMax=10;
    TaskParameters.GUI.PhotoPlotSidePokeIn=true;
	TaskParameters.GUIMeta.PhotoPlotSidePokeIn.Style='checkbox';
    TaskParameters.GUI.PhotoPlotSidePokeLeave=true;
	TaskParameters.GUIMeta.PhotoPlotSidePokeLeave.Style='checkbox';
    TaskParameters.GUI.PhotoPlotReward=true;
	TaskParameters.GUIMeta.PhotoPlotReward.Style='checkbox';    
    TaskParameters.GUI.BaselineBegin=0.1;
    TaskParameters.GUI.BaselineEnd=1.1;
    TaskParameters.GUIPanels.PhotometryPlot={'TimeMin','TimeMax','NidaqMin','NidaqMax','PhotoPlotSidePokeIn','PhotoPlotSidePokeLeave','PhotoPlotReward','BaselineBegin','BaselineEnd'};
    
    %% Nidaq and Photometry
    TaskParameters.GUI.PhotometryVersion=1;
    TaskParameters.GUI.Modulation=true;
    TaskParameters.GUIMeta.Modulation.Style='checkbox';
    TaskParameters.GUIMeta.Modulation.String='Auto';
	TaskParameters.GUI.NidaqDuration=4;
    TaskParameters.GUI.NidaqSamplingRate=6100;
    TaskParameters.GUI.DecimateFactor=610;
    TaskParameters.GUI.LED1_Name='Fiber1 470-A1';
    TaskParameters.GUIMeta.LED1_Name.Style='edittext';
    TaskParameters.GUI.LED1_Amp=2;
    TaskParameters.GUI.LED1_Freq=211;
    TaskParameters.GUI.LED2_Name='Fiber1 405 / 565';
    TaskParameters.GUIMeta.LED2_Name.Style='edittext';
    TaskParameters.GUI.LED2_Amp=2;
    TaskParameters.GUI.LED2_Freq=531;
    TaskParameters.GUI.LED1b_Name='Fiber2 470-mPFC';
    TaskParameters.GUIMeta.LED1b_Name.Style='edittext';
    TaskParameters.GUI.LED1b_Amp=2;
    TaskParameters.GUI.LED1b_Freq=531;

    TaskParameters.GUIPanels.PhotometryNidaq={'PhotometryVersion','Modulation','NidaqDuration',...
                            'NidaqSamplingRate','DecimateFactor',...
                            'LED1_Name','LED1_Amp','LED1_Freq',...
                            'LED2_Name','LED2_Amp','LED2_Freq',...
                            'LED1b_Name','LED1b_Amp','LED1b_Freq'};

    % rig-specific
    TaskParameters.GUI.nidaqDev='Dev2';
    TaskParameters.GUIMeta.nidaqDev.Style='edittext';

    TaskParameters.GUIPanels.PhotometryRig={'nidaqDev'};      
                        
    %%
    TaskParameters.GUI = orderfields(TaskParameters.GUI);
    %% Tabs
    TaskParameters.GUITabs.General = {'General','StimDelay','BiasControl','FeedbackDelay'};
    TaskParameters.GUITabs.Block = {'BlockStructure'};
    TaskParameters.GUITabs.Odor = {'Olfactometer','OlfStimuli'};
    TaskParameters.GUITabs.Auditory = {'AudGeneral','AudMinSample','AudClicks','AudFreq','AudFreqLevels'};
    TaskParameters.GUITabs.Plots = {'ShowPlots','Vevaiometric'};
    TaskParameters.GUITabs.Laser = {'LaserGeneral','LaserTrain','LaserTaskEpochs'};
    TaskParameters.GUITabs.Video = {'VideoGeneral'};
    TaskParameters.GUITabs.Photometry = {'PhotometryRecording','PhotometryNidaq','PhotometryPlot','PhotometryRig'};
    
    % Reorder tabs for clarity
    TaskParameters.GUITabs = orderfields(TaskParameters.GUITabs, ...
        {'General', 'Block', 'Odor', 'Auditory', 'Plots', 'Laser', 'Video', 'Photometry'});
    
    %%Non-GUI Parameters (but saved)
    % Setting TaskParameters.Figures.ParameterGUI.Position causes GUI
    % issues on Linux using opengl
    TaskParameters.Figures.OutcomePlot.Position = [200, 200, 1000, 400];
    
end
BpodParameterGUI('init', TaskParameters);
end