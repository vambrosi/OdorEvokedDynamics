function motionCorrection(experimentFolder, appendToImages)
% MOTIONCORRECTION - Applies motion correction to '.tif' files in the
% folder experimentFolder/raw. Saves motion corrected images and metadata
% to experimentFolder/processed/mcor (creating this folder if needed).
%
% Syntax
%   MOTIONCORRECTION(experimentFolder)
%   MOTIONCORRECTION(experimentFolder, appendToImages)
%
% Input Arguments
%   experimentFolder - Path to the experiment folder
%       string scalar | character vector
%   appendToImages - Text to add at the end of filenames
%       '_mcor' (default) | string scalar | character vector

arguments
   experimentFolder {mustBeFolder}
   appendToImages char = '_mcor'
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

% Create motion corrected images folder
if ~isfolder(saveFolder)
    mkdir(saveFolder)
end

% Open first frame of the first file to get dimensions
firstFrame = read_file(fullfile(files(1).folder, files(1).name), 1, 1);

% Set parameters for the motion correction algorithm
parameters = NoRMCorreSetParms( ...
    'd1', size(firstFrame, 1), ...
    'd2', size(firstFrame, 2), ...
    'grid_size', [32,32], ...
    'mot_uf', 4, ...
    'bin_width', 200, ...
    'max_shift', 15, ...
    'max_dev', 3, ...
    'us_fac', 50, ...
    'init_batch', 200, ...
    'output_type', 'tiff' ...
);

% Run motion correction of file using template of the last file
% See github.com/flatironinstitute/NoRMCorre/issues/12 for details

% File path where current state will be saved 
[~, filename1, ~] = fileparts(files(1).name);
[~, filename2, ~] = fileparts(files(end).name);
stateFilename = [filename1 '_' filename2(end-4:end)];
statePath = fullfile(saveFolder, [stateFilename '.mat']);

% Start parallel processing
gcp;

template = [];
for i = 1:size(files, 1)
    fprintf('=======================================================\n');
    fprintf('Processing file %s\n', files(i).name);
    
    % Get and split path to original file
    filePath = fullfile(files(i).folder, files(i).name);
    [~, filename, extension] = fileparts(filePath);

    % Set destination path to motion corrected file
    mcorPath = fullfile(saveFolder, [filename appendToImages extension]);
    parameters.tiff_filename = mcorPath;
    
    % Run motion correction algorithm
    tic;
    [~, ~, template, parameters] = ...
        normcorre_batch(filePath, parameters, template);
    toc

    % Save current state in case loop is interrupted
    % - filename tells where the loop stopped
    % - template is needed to keep motion correction consistent
    % - parameters stores the initial settings
    save(statePath, 'filename', 'template', 'parameters');
end

end