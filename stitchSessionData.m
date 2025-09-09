function joinedData = stitchSessionData(datapath)
% Efficiently concatenates SessionData fields from multiple .mat files into a single struct array.

% Get all .mat files in the specified directory
myFiles = dir(fullfile(datapath, '*DiscriminationConfidence*.mat'));
numFiles = length(myFiles);

% Preallocate the struct array with fields corresponding to SessionData
tempData = load(fullfile(datapath, myFiles(1).name));
fields = fieldnames(tempData.SessionData);
joinedData = repmat(tempData.SessionData, numFiles, 1); % Multiplies SessionData's contents by the number of files, preserving exact structure

% Load and concatenate data from all .mat files
for i = 1:numFiles
    thisFile = load(fullfile(datapath, myFiles(i).name));
    for ii = 1:length(fields)
        joinedData(i).(fields{ii}) = thisFile.SessionData.(fields{ii});
    end
end
end
