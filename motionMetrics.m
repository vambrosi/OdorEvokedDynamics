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

% TODO fix motion_metrics border

arguments
    experimentFolder {mustBeFolder}
end

import NoRMCorre.read_file
import NoRMCorre.motion_metrics
import NoRMCorre.NoRMCorreSetParms

% Assumes the default folder structure for a experiment
imagesFolder = fullfile(experimentFolder, 'raw');
mcorFolder = fullfile(experimentFolder, 'processed', 'mcor');
metricsFolder = fullfile(mcorFolder, 'metrics');

% Create metrics folder if it doesn't exist
if ~isfolder(metricsFolder)
    mkdir(metricsFolder)
end

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
metricPath = fullfile(metricsFolder, [dataFilename '_metrics.mat']);

% Load motion correction data to compute shift ranges
load(dataPath, 'mcorData', 'parameters');
maxTotalShift = max(parameters.max_shift + parameters.max_dev);

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
        [rawCorrelation, rawMeanImage, rawCrispness] = ...
            motion_metrics(rawStack, 10);

        mcorMetrics(fileIndex).rawCorrelation = rawCorrelation;
        mcorMetrics(fileIndex).rawCrispness = rawCrispness;
        saveMeanImage(rawMeanImage, quantiles, metricsFolder, ...
            fileroot, '_AVG_raw');

        % Compute and saves metrics of the motion corrected file
        [mcorCorrelation, mcorMeanImage, mcorCrispness] = ...
            motion_metrics(mcorStack, 10);

        mcorMetrics(fileIndex).mcorCorrelation = mcorCorrelation;
        mcorMetrics(fileIndex).mcorCrispness = mcorCrispness;
        saveMeanImage(mcorMeanImage, quantiles, metricsFolder, ...
            fileroot, '_AVG_mcor');

        % Saves the plot comparing the correlations of raw
        % and motion corrected files
        saveCorrelationPlot(rawCorrelation, mcorCorrelation, ...
            metricsFolder, fileroot);

        % Computes the shiftRange and saves its plot
        shiftRange = getRanges(mcorData(fileIndex).shiftsUp);
        mcorMetrics(fileIndex).shiftRange = shiftRange;
        
        saveShiftPlot(mcorMetrics(fileIndex).shiftRange, ...
            maxTotalShift, metricsFolder, fileroot)
    end
end

% Saves all metrics
save(metricPath, 'mcorMetrics')
end

function range = getRanges(arrays)
% GETRANGES computes the min and max absolute entry for each array, for a
% list of arrays. This list of arrays must be given as an (n+1)-dim array,
% with the last dimension representing the list index. It returns a 2 x N
% array where N is the number of arrays in the list.
    absCoordinates = abs(reshape(arrays, [], size(arrays, ndims(arrays))));
    range = [min(absCoordinates); max(absCoordinates)];
end

function saveShiftPlot(shiftRange, maxTotalShift, saveFolder, fileroot)
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

    imagePath = fullfile(saveFolder, [fileroot '_shiftRange.png']);
    saveas(fig, imagePath);
    
    close(fig);
end

function saveMeanImage(mean, quantiles, saveFolder, fileroot, appendToFile)
% SAVEMEANIMAGE saves the mean z-projections to the mcor folder.
    fig = figure(Visible="off");
    
    imagesc(mean, quantiles);
    colormap gray;
    axis equal;
    axis tight;
    axis off;

    imagePath = fullfile(saveFolder, [fileroot appendToFile '.png']);
    saveas(fig, imagePath);
    
    close(fig);
end

function saveCorrelationPlot(raw, mcor, saveFolder, fileroot)
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

    imagePath = fullfile(saveFolder, [fileroot '_correlation.png']);
    saveas(fig, imagePath);
    
    close(fig);
end