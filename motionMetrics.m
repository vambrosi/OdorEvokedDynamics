function motionMetrics(experimentFolder)
% MOTIONMETRICS Computes mean images, correlation, and crispness of raw and
% motion corrected images. Saves results and plots in the mcor folder.
%
% Syntax
%   MOTIONMETRICS(experimentFolder)
%
% Input Arguments
%   experimentFolder - Path to the experiment folder
%       string scalar | character vector

% TODO 
% 1) fix motion_metrics border (y-axis)
% 2) concatenate all plots
% 3) only plot average images of middle and last files.

arguments
    experimentFolder {mustBeFolder}
end

import NoRMCorre.read_file
import NoRMCorre.motion_metrics
import NoRMCorre.NoRMCorreSetParms

% Assumes the default folder structure for a experiment
imagesFolder = fullfile(experimentFolder, 'raw');
mcorFolder = fullfile(experimentFolder, 'processed', 'mcor');

% Store file paths
files = dir(fullfile(imagesFolder, "*.tif"));
if isempty(files), error("Image folder is empty."); end

% Make sure they are in the right order
[~, ind] = sort({files.name});
files = files(ind);

% String appended to motion corrected files
appendToImages = '_mcor';

% File path where metrics and data are stored
[~, filename1, ~] = fileparts(files(1).name);
[~, filename2, ~] = fileparts(files(end).name);
dataFilename = [filename1 '_' filename2(end-4:end)];

dataPath = fullfile(mcorFolder, [dataFilename '_mcor.mat']);
metricPath = fullfile(mcorFolder, [dataFilename '_metrics.mat']);
correlationPath = fullfile(mcorFolder, [dataFilename '__correlation.png']);
shiftPath = fullfile(mcorFolder, [dataFilename '__shiftRange.png']);

% Load motion correction data to compute shift ranges
load(dataPath, 'mcorData', 'parameters');
maxTotalShift = max(parameters.max_shift + parameters.max_dev);

% Preallocate the struct array mcorMetrics
mcorMetrics(size(files, 1)).filename = [];
mcorMetrics(size(files, 1)).rawCorrelation = [];
mcorMetrics(size(files, 1)).rawCrispness = [];
mcorMetrics(size(files, 1)).mcorCorrelation = [];
mcorMetrics(size(files, 1)).mcorCrispness = [];
mcorMetrics(size(files, 1)).shiftRange = [];

for fileIndex = 1:size(files, 1)
    filename = files(fileIndex).name;
    fprintf('Computing metrics for file %s\n', filename);

    % Get and split path to original file
    filePath = fullfile(files(fileIndex).folder, filename);
    [~, fileroot, extension] = fileparts(filePath);

    % Path to motion corrected file
    mcorFilename = [fileroot appendToImages extension];
    mcorPath = fullfile(mcorFolder, mcorFilename);

    % Creates struct to hold metrics
    mcorMetrics(fileIndex).filename = filename;

    if isfile(mcorPath)
        rawStack = single(read_file(filePath));
        mcorStack = single(read_file(mcorPath));

        lowQuantile = quantile(rawStack(:), 0.005);
        highQuantile = quantile(rawStack(:), 0.995);
        quantiles = [lowQuantile, highQuantile];
        
        % Compute and saves metrics of the raw file
        [rawCorrelation, ~, rawCrispness] = ...
            motion_metrics(rawStack, 10);

        mcorMetrics(fileIndex).rawCorrelation = rawCorrelation;
        mcorMetrics(fileIndex).rawCrispness = rawCrispness;

        % Compute and saves metrics of the motion corrected file
        [mcorCorrelation, ~, mcorCrispness] = ...
            motion_metrics(mcorStack, 10);

        mcorMetrics(fileIndex).mcorCorrelation = mcorCorrelation;
        mcorMetrics(fileIndex).mcorCrispness = mcorCrispness;

        % Computes the shiftRange and saves its plot
        shiftRange = getRanges(mcorData(fileIndex).shiftsUp);
        mcorMetrics(fileIndex).shiftRange = shiftRange;
    end
end

% Saves all metrics
save(metricPath, 'mcorMetrics')

% Concatenate metrics for all files
rawCorrelation = vertcat(mcorMetrics.rawCorrelation);
mcorCorrelation = vertcat(mcorMetrics.mcorCorrelation);
shiftRange = horzcat(mcorMetrics.shiftRange);

% Save plots
saveShiftPlot(shiftRange, maxTotalShift, shiftPath);
saveCorrelationPlot(rawCorrelation, mcorCorrelation, correlationPath);
end

function range = getRanges(arrays)
% GETRANGES computes the min and max absolute entry for each array, for a
% list of arrays. This list of arrays must be given as an (n+1)-dim array,
% with the last dimension representing the list index. It returns a 2 x N
% array where N is the number of arrays in the list.
    absCoordinates = abs(reshape(arrays, [], size(arrays, ndims(arrays))));
    range = [min(absCoordinates); max(absCoordinates)];
end

function saveShiftPlot(shiftRange, maxTotalShift, imagePath)
% SAVESHIFTPLOT saves the default plot of the getShiftRange results
    fig = figure(Visible="off");
    
    nFrames = size(shiftRange, 2);
    plot(1:nFrames, shiftRange.');
    yline(maxTotalShift);
    
    xlabel('Frame Number');
    xlim([1 nFrames]);

    ylabel('Absolute Value of Shift (in Pixels)')
    ylim([0 maxTotalShift + 1]);

    title('Max and Min Coordinate Shift', ...
        'fontsize',14,'fontweight','bold');

    saveas(fig, imagePath);
    
    close(fig);
end

function saveCorrelationPlot(raw, mcor, imagePath)
% SAVECORRELATIONPLOT saves the plot of the correlation of a frame with the
% mean z-projection.
    nFrames = length(raw);
    fig = figure(Visible="off");
    
    plot(1:nFrames, raw, 1:nFrames, mcor);
    
    xlabel('Frame Number');
    ylim([0 1]);
    ylabel('Correlation Coefficient');
    
    legend('raw data', 'non-rigid');
    title('Correlation with the Mean Image', ...
        'fontsize',14,'fontweight','bold');

    saveas(fig, imagePath);
    
    close(fig);
end