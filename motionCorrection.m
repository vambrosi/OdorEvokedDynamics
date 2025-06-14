function motionCorrection(experimentFolder, options)
% MOTIONCORRECTION - Applies motion correction to '.tif' files in the
% folder experimentFolder/raw. Saves motion corrected images and metadata
% to experimentFolder/processed/mcor (creating this folder if needed).
%
% Syntax
%   MOTIONCORRECTION(experimentFolder)
%   MOTIONCORRECTION(experimentFolder, options)
%
% Input Arguments
%   experimentFolder - Path to the experiment folder
%       string scalar | character vector
%   gridSize - Patch size (in pixels, not including overlaps)
%       32 (default) | positive integer
%   maxShift - Max translation distance (in pixels) for each frame
%       15 (default) | positive integer
%   maxDeviation - Max deviation (in pixels) for each patch
%       3 (default) | positive integer

arguments
   experimentFolder {mustBeFolder}
   options.gridSize {mustBeInteger, mustBePositive} = 32
   options.maxShift {mustBeInteger, mustBePositive} = 15
   options.maxDeviation {mustBeInteger, mustBePositive} = 3
end

import NoRMCorre.read_file
import NoRMCorre.normcorre_batch
import NoRMCorre.NoRMCorreSetParms

% Assumes the default folder structure for a experiment
imagesFolder = fullfile(experimentFolder, 'raw');
saveFolder = fullfile(experimentFolder, 'processed', 'mcor');

% Store file paths
files = dir(fullfile(imagesFolder, "*.tif"));
if isempty(files), error("Image folder is empty."); end

% Make sure they are in the right order
[~, ind] = sort({files.name});
files = files(ind);

% Create motion corrected images folder
if ~isfolder(saveFolder)
    mkdir(saveFolder)
end

% Open first frame of the first file to get dimensions
firstFrame = read_file(fullfile(files(1).folder, files(1).name), 1, 1);

% File path where current state will be saved 
[~, filename1, ~] = fileparts(files(1).name);
[~, filename2, ~] = fileparts(files(end).name);
stateFilename = [filename1 '_' filename2(end-4:end)];
statePath = fullfile(saveFolder, [stateFilename '_mcor.mat']);

if isfile(statePath)
    % Load previous state file to continue processing
    load(statePath, "mcorData", "filename", "template", "parameters");
    startIndex = find(string({files.name}) == filename) + 1;

else
    % If there is no state file use default values
    startIndex = 1;
    template = [];

    parameters = NoRMCorreSetParms( ...
        'd1', size(firstFrame, 1), ...
        'd2', size(firstFrame, 2), ...
        'grid_size', [options.gridSize, options.gridSize], ...
        'mot_uf', 4, ...
        'bin_width', 200, ...
        'max_shift', options.maxShift, ...
        'max_dev', options.maxDeviation, ...
        'us_fac', 50, ...
        'init_batch', 200, ...
        'output_type', 'tiff' ...
    );
end

% String to be append to motion corrected files
appendToImages = '_mcor';

% Start parallel processing
gcp;

% Run motion correction of file using template of the last file
% See github.com/flatironinstitute/NoRMCorre/issues/12 for details

for fileIndex = startIndex:size(files, 1)
    filename = files(fileIndex).name;

    fprintf('=======================================================\n');
    fprintf('Processing file %s\n', filename);
    
    % Get and split path to original file
    filePath = fullfile(files(fileIndex).folder, filename);
    [~, fileroot, extension] = fileparts(filePath);

    % Set destination path to motion corrected file
    mcorFilename = [fileroot appendToImages extension];
    mcorPath = fullfile(saveFolder, mcorFilename);
    parameters.tiff_filename = mcorPath;
    
    % Run motion correction algorithm
    tic;
    [~, shifts, template, parameters] = ...
        normcorre_batch(filePath, parameters, template);
    toc

    % Organizes shift data for later analysis
    mcorData(fileIndex).filename = filename;
    mcorData(fileIndex).shifts = cat(5, shifts.shifts);
    mcorData(fileIndex).shiftsUp = cat(5, shifts.shifts_up);

    % Save current state in case loop is interrupted
    % - filename tells where the loop stopped
    % - template is needed to keep motion correction consistent
    % - parameters stores the initial settings
    % - mcorData stores motion correction data for later analysis
    save(statePath, "mcorData", "filename", "template", "parameters");
end

end