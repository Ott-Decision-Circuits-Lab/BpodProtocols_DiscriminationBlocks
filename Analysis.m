function FigHandle = Analysis(DataFile)
global TaskParameters

if nargin < 1
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

if isfield(SessionData, 'nTrialsArray')
    AnalysisType = "pooled";
else
    AnalysisType = "single";
end

AudBin = 7; %Bins for psychometric

if strcmp(AnalysisType, "single")
    Animal = str2double(SessionData.Info.Subject);
    if isnan(Animal)
        Animal = -1;
    end
    dateString = string(SessionData.Info.SessionDate);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


nTrials=SessionData.nTrials;
DV = SessionData.Custom.TrialData.DecisionVariable(1:nTrials-1);
ChoiceLeft = SessionData.Custom.TrialData.ChoiceLeft(1:nTrials-1);
ST = SessionData.Custom.TrialData.SampleLength(1:nTrials-1);
CatchTrial = SessionData.Custom.TrialData.CatchTrial((1:nTrials-1));
Feedback = SessionData.Custom.TrialData.Feedback(1:nTrials-1);
Correct = SessionData.Custom.TrialData.ChoiceCorrect(1:nTrials-1);
BlockNumber = SessionData.Custom.TrialData.BlockNumber(1:nTrials-1);
if isfield(SessionData.Custom,'LaserTrial')
    LaserTrial =  SessionData.Custom.TrialData.LaserTrial(1:nTrials-1);
else
    LaserTrial=false(1,nTrials-1);
end

CompletedTrials = (Feedback&Correct==1) | (Correct==0) | CatchTrial&~isnan(ChoiceLeft);
nTrialsCompleted = sum(CompletedTrials);

%caclulate  grace periods
GracePeriods=[];
GracePeriodsL=[];
GracePeriodsR=[];
for t = 1 : length(ST)
    GracePeriods = [GracePeriods;SessionData.RawEvents.Trial{t}.States.rewarded_Rin_grace(:,2)-SessionData.RawEvents.Trial{t}.States.rewarded_Rin_grace(:,1);SessionData.RawEvents.Trial{t}.States.rewarded_Lin_grace(:,2)-SessionData.RawEvents.Trial{t}.States.rewarded_Lin_grace(:,1)];
    if ChoiceLeft(t) == 1
        GracePeriodsL = [GracePeriodsL;SessionData.RawEvents.Trial{t}.States.rewarded_Lin_grace(:,2)-SessionData.RawEvents.Trial{t}.States.rewarded_Lin_grace(:,1)];
    elseif ChoiceLeft(t)==0
        GracePeriodsR = [GracePeriodsR;SessionData.RawEvents.Trial{t}.States.rewarded_Rin_grace(:,2)-SessionData.RawEvents.Trial{t}.States.rewarded_Rin_grace(:,1)];
    end
end

%laser trials?
if sum(LaserTrial)>0
    LaserCond = [false;true];
else
    LaserCond=false;
end
CondColors={[0,0,0],[.9,.1,.1]};

%%
tiledLayoutHandle = tiledlayout('flow');
tiledLayoutHandle.TileSpacing = 'tight';
tiledLayoutHandle.Padding = 'tight';
if strcmp(AnalysisType, "single")
    figtitle = sprintf("DiscriminationBlocks, R%d on %s with %s %s %s", Animal, dateString, SessionData.Custom.Pharmacology{1}, SessionData.Custom.Pharmacology{2}, SessionData.Custom.Pharmacology{3});
else

end
sgtitle(figtitle, 'FontSize', 14);
% ExperiencedDV=DV;

% First, determine common bin edges across ALL data
AudDV = DV(CompletedTrials);
commonBinEdges = linspace(min(AudDV)-10*eps, max(AudDV)+10*eps, AudBin+1);
binCenters = (commonBinEdges(1:end-1) + commonBinEdges(2:end))/2;

%Psychometric
nexttile(tiledLayoutHandle);
hold on

BinIdx = discretize(AudDV, commonBinEdges);
PsycY = grpstats(ChoiceLeft(CompletedTrials), BinIdx,'mean');
PsycX = grpstats(DV(CompletedTrials), BinIdx,'mean');
plot(PsycX,PsycY,'ok','MarkerFaceColor','k','MarkerEdgeColor','w','MarkerSize',6)
XFit = linspace(min(AudDV)-10*eps,max(AudDV)+10*eps,100);
YFit = glmval(glmfit(AudDV,ChoiceLeft(CompletedTrials)','binomial'), linspace(min(AudDV)-10*eps,max(AudDV)+10*eps, 100),'logit');
plot(XFit,YFit,'Color','k');
xlabel('DV');ylabel('p left')
text(0.95*min(get(gca,'XLim')),0.96*max(get(gca,'YLim')),[num2str(round(nanmean(Correct(CompletedTrials))*100)),'%,n=',num2str(nTrialsCompleted)]);

% bias blocks psychometric, last block gray
nexttile(tiledLayoutHandle);
hold on
CondColors = {'k', 'b', 'r', [0.5 0.5 0.5]};
ChoiceLeftCompleted = ChoiceLeft(CompletedTrials);
BlockNumberCompleted = SessionData.Custom.TrialData.BlockNumber(CompletedTrials);
for iBlock = unique(BlockNumberCompleted)
    CurrentDVs = AudDV(BlockNumberCompleted == iBlock);
    CurrentChoiceLeft = ChoiceLeftCompleted(BlockNumberCompleted == iBlock);
    BinIdx = discretize(CurrentDVs, commonBinEdges);
    PsycY = grpstats(CurrentChoiceLeft,BinIdx, 'mean');
    PsycX = grpstats(CurrentDVs, BinIdx, 'mean');
    plot(PsycX, PsycY, 'o', 'MarkerFaceColor', CondColors{iBlock}, 'MarkerEdgeColor', 'w', 'MarkerSize', 6)
    XFit = linspace(min(CurrentDVs)-10*eps,max(CurrentDVs)+10*eps,100);
    YFit = glmval(glmfit(CurrentDVs,CurrentChoiceLeft','binomial'),linspace(min(CurrentDVs)-10*eps,max(CurrentDVs)+10*eps,100),'logit');
    plot(XFit,YFit, '-', 'Color',CondColors{iBlock});
    xlabel('DV');ylabel('p left')
end
hold off

% bias blocks psychometric
nexttile(tiledLayoutHandle);
hold on
CondColors = {'b', 'k', 'r'};
AudBiasCompleted = SessionData.Custom.TrialData.AudBias(CompletedTrials);
uniqueAudBiases = unique(AudBiasCompleted);
BiasToFitIndexMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
for i = 1:numel(uniqueAudBiases)
    BiasToFitIndexMap(uniqueAudBiases(i)) = i;
end
for blockBias = uniqueAudBiases
    CurrentDVs = AudDV(AudBiasCompleted == blockBias);
    CurrentChoiceLeft = ChoiceLeftCompleted(AudBiasCompleted == blockBias);
    BinIdx = discretize(CurrentDVs, commonBinEdges);
    PsycY = grpstats(CurrentChoiceLeft,BinIdx,'mean');
    PsycX = grpstats(CurrentDVs,BinIdx,'mean');
    plot(PsycX,PsycY, 'o','MarkerFaceColor',CondColors{BiasToFitIndexMap(blockBias)},'MarkerEdgeColor','w','MarkerSize',6)
    XFit = linspace(min(CurrentDVs)-10*eps,max(CurrentDVs)+10*eps,100);
    YFit = glmval(glmfit(CurrentDVs,CurrentChoiceLeft','binomial'),linspace(min(CurrentDVs)-10*eps,max(CurrentDVs)+10*eps,100),'logit');
    plot(XFit,YFit, '-', 'Color',CondColors{BiasToFitIndexMap(blockBias)});
    xlabel('DV');ylabel('p left')
end
hold off

%DV distribution
nexttile(tiledLayoutHandle);
hold on
StartPosition = 1;
EndPosition = 0;
for iBlock = unique(BlockNumber)
    CurrentDVs = DV(BlockNumber == iBlock);
    EndPosition = EndPosition + numel(CurrentDVs);
    plot(StartPosition:EndPosition, CurrentDVs, 'o', 'Color', CondColors{iBlock}, 'MarkerSize', 2)
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

end

function RedoTicks(h)
Chil=get(h,'Children');

for i = 1:length(Chil)
    if strcmp(Chil(i).Type,'axes')
        set(Chil(i),'TickDir','out','TickLength',[0.03 0.03],'box','off')
    end
    if strcmp(Chil(i).Type,'legend')
        set(Chil(i),'box','off')
    end
end
end

function [R,P] = EvaluateVevaiometric(DV,WT)
    % for Vevaiometric (certainty/confidence), part of Analysis()
    R = zeros(1,3);
    P=zeros(1,3);
    if sum(DV<=0)>0
        [R(1),P(1)] = corr(DV(DV<=0)',WT(DV<=0)','type','Spearman');
    end
    if sum(DV>0)>0
        [R(2),P(2)] = corr(DV(DV>0)',WT(DV>0)','type','Spearman');
    end
    if sum(~isnan(DV))>0
        [R(3),P(3)] = corr(abs(DV)',WT','type','Spearman');
    end
end