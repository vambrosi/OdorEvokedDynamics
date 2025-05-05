%% User Input (folder with images to motion correct)

experimentFolder = '../OdorEvokedDynamicsData/20250321/Experiment1';

% Default folder settings
imagesFolder = fullfile(experimentFolder, 'Raw');
saveFolder = fullfile(experimentFolder, 'Processed', 'Mcor');
appendToImages = '_mcor';

%% Motion Correction

% Start parallel processing for later
gcp;

% Store file names
files = dir(fullfile(imagesFolder, "*.tif"));

% Make sure they are in the right order
[~, ind] = sort({files.name});
files = files(ind);

% Create motion corrected images folder
if ~isfolder(saveFolder)
    mkdir(saveFolder)
end

% Open first frame of the first file to get dimensions
assert(~isempty(files), "Image folder is empty.");
firstFrame = read_file(fullfile(files(1).folder, files(1).name), 1, 1);

% Set options for the motion correction algorithm.
options = NoRMCorreSetParms( ...
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
% See github.com/flatironinstitute/NoRMCorre/issues/12 for details.

template = [];
for i = 1:size(files, 1)
    fprintf('=======================================================\n');
    fprintf('Processing file %s\n', files(i).name);
    
    % Get and split path to original file
    filePath = fullfile(files(i).folder, files(i).name);
    [~, filename, extension] = fileparts(filePath);

    % Set destination path to motion corrected file
    mcorPath = fullfile(saveFolder, [filename appendToImages extension]);
    options.tiff_filename = mcorPath;
    
    % Run motion correction algorithm
    tic;
    [~, ~, template, options] = ...
        normcorre_batch(filePath, options, template);
    toc
end

% Save options and final template
[~, filename1, ~] = fileparts(files(1).name);
[~, filename2, ~] = fileparts(files(end).name);

filename = [filename1 '_' filename2(end-4:end)];
optionsPath = fullfile(saveFolder, [filename '.mat']);
save(optionsPath, 'template', 'options');