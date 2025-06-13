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

% Assumes the default folder structure for a experiment
imagesFolder = fullfile(experimentFolder, 'raw');
saveFolder = fullfile(experimentFolder, 'processed', 'mcor');

% Store file paths
files = dir(fullfile(imagesFolder, "*.tif"));
if isempty(files), error("Image folder is empty."); end

% Make sure they are in the right order
[~, ind] = sort({files.name});
files = files(ind);

% String appended to motion corrected files
appendToImages = '_mcor';

for fileIndex = 1:size(files, 1)
    filename = files(fileIndex).name;
    fprintf('Computing metrics for file %s\n', filename);

    % Get and split path to original file
    filePath = fullfile(files(fileIndex).folder, filename);
    [~, fileroot, extension] = fileparts(filePath);

    % Path to motion corrected file
    mcorFilename = [fileroot appendToImages extension];
    mcorPath = fullfile(saveFolder, mcorFilename);

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
        saveMeanImage(rawMeanImage, quantiles, saveFolder, ...
            fileroot, '_AVG_raw');

        % Compute and saves metrics of the motion corrected file
        [mcorCorrelation, mcorMeanImage, mcorCrispness] = ...
            motion_metrics(mcorStack, 10);

        mcorMetrics(fileIndex).mcorCorrelation = mcorCorrelation;
        mcorMetrics(fileIndex).mcorCrispness = mcorCrispness;
        saveMeanImage(mcorMeanImage, quantiles, saveFolder, ...
            fileroot, '_AVG_mcor');

        % Saves the plot comparing the correlations of raw
        % and motion corrected files
        saveCorrelationPlot(rawCorrelation, mcorCorrelation, ...
            saveFolder, fileroot);

    end
end

% File path where metrics will be stored
[~, filename1, ~] = fileparts(files(1).name);
[~, filename2, ~] = fileparts(files(end).name);
stateFilename = [filename1 '_' filename2(end-4:end)];
statePath = fullfile(saveFolder, [stateFilename '_metrics.mat']);

save(statePath, 'mcorMetrics')
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
    
    xlabel('Frame Number')
    ylim([0 1]);
    ylabel('Correlation Coefficient')
    
    legend('raw data', 'non-rigid');
    title('Correlation with the Mean Image', ...
        'fontsize',14,'fontweight','bold');

    imagePath = fullfile(saveFolder, [fileroot '_correlation.png']);
    saveas(fig, imagePath);
    
    close(fig);
end



