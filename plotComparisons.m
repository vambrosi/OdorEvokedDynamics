function plotComparisons(experimentFolder)
% PLOTCOMPARISONS saves two images that compare the mean images of the first
% acquisition with the mean images of the middle and the last acquisition.
%
% Syntax
%   PLOTCOMPARISONS(experimentFolder)
%
% Input Arguments
%   experimentFolder - Path to the experiment folder
%       string scalar | character vector

arguments
    experimentFolder {mustBeFolder}
end

import NoRMCorre.read_file
import NoRMCorre.motion_metrics
import NoRMCorre.NoRMCorreSetParms

% Assumes the default folder structure for a experiment
mcorFolder = fullfile(experimentFolder, 'processed', 'mcor');

% Store file paths
files = dir(fullfile(mcorFolder, "*.tif"));
if isempty(files), error("Image folder is empty."); end

% Make sure they are in the right order
[~, ind] = sort({files.name});
files = files(ind);

% Get 3 files to plot the comparisons
startFile = files(1);
midFile = files(ceil(length(files) / 2));
endFile = files(end);

% Compute mean images the tiff stacks
startStack = single(read_file(fullfile(mcorFolder, startFile.name)));

lowQuantile = double(quantile(startStack(:), 0.005));
highQuantile = double(quantile(startStack(:), 0.995));
quantiles = [lowQuantile, highQuantile];

startMeanImage = mat2gray(mean(startStack, ndims(startStack)), quantiles);
clear("startStack");

midStack = single(read_file(fullfile(mcorFolder, midFile.name)));
midMeanImage = mat2gray(mean(midStack, ndims(midStack)), quantiles);
clear("midStack");

endStack = single(read_file(fullfile(mcorFolder, endFile.name)));
endMeanImage = mat2gray(mean(endStack, ndims(endStack)), quantiles);
clear("endStack");

% Define file names
[~, startFilename, ~] = fileparts(startFile.name);
[~, endFilename, ~] = fileparts(endFile.name);

splitStartFilename = split(string(startFilename), '_');
splitEndFilename = split(string(endFilename), '_');
genericFilename = join([ ...
    join(splitStartFilename(1:end-1), '_') ...
    splitEndFilename(end-1)
], '_');

midComparisonPath = fullfile(mcorFolder, ...
    join([genericFilename 'midComparison.png'], '__'));
endComparisonPath = fullfile(mcorFolder, ...
    join([genericFilename 'endComparison.png'], '__'));

% Build images with startMeanImage in magenta and the other mean image in green
saveComparison(startMeanImage, midMeanImage, midComparisonPath);
saveComparison(startMeanImage, endMeanImage, endComparisonPath);
end

function saveComparison(imageMagenta, imageGreen, savePath)
% SAVEMEANIMAGE saves the mean z-projections to the mcor folder.

    % Magenta is equal parts red and blue, so imageMagenta appears in both red 
    % and the blue channels (1 and 3). The other image appears only in the  
    % green channel (2).
    comparisonImage(:, :, 3) = imageMagenta;
    comparisonImage(:, :, 2) = imageGreen;
    comparisonImage(:, :, 1) = imageMagenta;
    
    fig = figure(Visible="off");
    
    image(comparisonImage);
    axis equal;
    axis tight;
    axis off;

    saveas(fig, savePath);
    
    close(fig);
end