%% MIRAGE v1.1.0
% Figure 2 -- Flat Map of MIRAGE locations
%
% This script creates a map showing the geographic distribution of radio
% locations represented in the MIRAGE MetaCorpus. Bubble size indicates
% the number of captured broadcast events associated with each location.
%
% Data:
%   The MIRAGE MetaCorpus is downloaded automatically from the
%   version-specific Zenodo record if it is not already available locally.
%
% External data:
%   Natural Earth Admin 0 country boundaries.
%
% Outputs:
%   Figure 2 in SVG and PNG formats.



%% SETUP

% Directory containing this script.
codeDir = fileparts(mfilename('fullpath'));

% Root directory of the GitHub analysis repository.
repoDir = fileparts(codeDir);

% Repository directories.
dataDir = fullfile(repoDir, 'data');
figureDir = fullfile(repoDir, 'figures');
naturalEarthDir = fullfile(repoDir, 'NaturalEarth');
resultsDir = fullfile(repoDir, 'results');
validationDir = fullfile(repoDir, 'validation');

% Create directories if they do not already exist.
if ~isfolder(dataDir)
    mkdir(dataDir);
end

if ~isfolder(figureDir)
    mkdir(figureDir);
end

if ~isfolder(resultsDir)
    mkdir(resultsDir);
end

if ~isfolder(validationDir)
    mkdir(validationDir);
end

% MIRAGE data file.
mirageFile = fullfile(dataDir, 'MIRAGE.parquet');

% Natural Earth country boundaries.
countryFile = fullfile(naturalEarthDir, ...
    'ne_10m_admin_0_countries.json');

% Natural Earth first-level administrative boundaries.
admin1File = fullfile(naturalEarthDir, ...
    'ne_10m_admin_1_states_provinces.json');

% Zenodo record for MIRAGE v1.1.0.
zenodoRecord = '21891580';



%% DOWNLOAD NATURAL EARTH DATA

naturalEarthBaseURL = ...
    'https://raw.githubusercontent.com/martynafford/natural-earth-geojson/master/10m/cultural/';

if ~isfile(countryFile)

    fprintf('Natural Earth country boundaries not found locally.\n');
    fprintf('Downloading Natural Earth country boundaries...\n');

    websave( ...
        countryFile, ...
        [naturalEarthBaseURL 'ne_10m_admin_0_countries.json']);

    fprintf('Natural Earth country boundaries downloaded.\n');

end

if ~isfile(admin1File)

    fprintf('Natural Earth first-level administrative boundaries not found locally.\n');
    fprintf('Downloading Natural Earth first-level administrative boundaries...\n');

    websave( ...
        admin1File, ...
        [naturalEarthBaseURL 'ne_10m_admin_1_states_provinces.json']);

    fprintf('Natural Earth first-level administrative boundaries downloaded.\n');

end



%% DOWNLOAD MIRAGE FROM ZENODO

if ~isfile(mirageFile)

    fprintf('MIRAGE data not found locally.\n');
    fprintf('Downloading MIRAGE from Zenodo record %s...\n', ...
        zenodoRecord);

    % Query Zenodo record.
    zenodoAPI = sprintf( ...
        'https://zenodo.org/api/records/%s', zenodoRecord);

    record = webread(zenodoAPI);

    % Find MIRAGE Parquet file.
    fileNames = string({record.files.key});
    fileIndex = find(fileNames == "MIRAGE.parquet", 1);

    if isempty(fileIndex)
        error(['MIRAGE.parquet was not found in Zenodo record %s. ' ...
            'Verify the Zenodo record ID and filename.'], ...
            zenodoRecord);
    end

    % Download MIRAGE.
    downloadURL = record.files(fileIndex).links.self;
    websave(mirageFile, downloadURL);

    fprintf('MIRAGE download complete.\n');

else

    fprintf('Using local MIRAGE data:\n%s\n', mirageFile);

end


%% IMPORT DATA

fprintf('Reading MIRAGE data...\n');

tab = parquetread(mirageFile);

fprintf('MIRAGE data imported: %d rows.\n', height(tab));

% Import Natural Earth country boundaries.
basemap = readgeotable(countryFile);

% Remove Antarctica because it is outside the geographic extent of the
% figure and is not included in the geographic coverage analyses.
basemap(ismember(string(basemap.ADMIN), "Antarctica"), :) = [];


%% CALCULATE EVENTS PER LOCATION

% Identify unique MIRAGE locations and count the number of events
% associated with each location.
[locationIDs, ~, locationIndex] = ...
    unique(tab.Location_MI_ID, 'stable');

eventCounts = accumarray(locationIndex, 1);

% Retrieve location metadata from the first occurrence of each location.
firstLocation = accumarray( ...
    locationIndex, (1:height(tab))', [], @min);

latitude = str2double( ...
    tab.Location_MI_Latitude(firstLocation));

longitude = str2double( ...
    tab.Location_MI_Longitude(firstLocation));

%% SCALE BUBBLE SIZES

% Scale event counts to a range suitable for MATLAB's bubblechart.
% Values below 100 events are assigned the minimum bubble size, and
% values above 10,000 events are capped at the maximum bubble size.
bubbleSize = eventCounts / 100;

bubbleSize(bubbleSize < 1) = 1;
bubbleSize(bubbleSize > 100) = 100;


%% CREATE FIGURE

figureHandle = figure( ...
    'Color', 'white', ...
    'Units', 'inches', ...
    'Position', [1 1 10 6]);

layout = tiledlayout(figureHandle, 1, 1);

gx = geoaxes(layout);

hold(gx, 'on');


%% PLOT COUNTRY BOUNDARIES

countryLayer = geoplot(gx, basemap, ...
    'FaceColor', 'none', ...
    'EdgeColor', [0.6 0.6 0.6]);


%% PLOT MIRAGE LOCATIONS

locationLayer = bubblechart( ...
    gx, latitude, longitude, bubbleSize);

bubblesize([2 10]);

% Use MATLAB's default blue for the location markers.
colororder(gx, 'blue');

locationLayer.MarkerEdgeColor = 'none';


%% FORMAT MAP

geolimits(gx, [-75 75], [-180 180]);

gx.Grid = 'off';
gx.LongitudeAxis.Visible = 'off';
gx.LatitudeAxis.Visible = 'off';
gx.Scalebar.Visible = 'off';
gx.Basemap = 'none';


%% ADD BUBBLE LEGEND

legendHandle = bubblelegend(gx, 'Location', 'SouthWest');

legendHandle.FontName = 'Times New Roman';
legendHandle.FontSize = 10;
legendHandle.LimitLabels = {'1', '', '>100'};
legendHandle.Box = 'off';


%% EXPORT FIGURE

% Export as SVG for publication/editing.
svgFile = fullfile(figureDir, 'Figure_2.svg');

exportgraphics( ...
    figureHandle, ...
    svgFile, ...
    'ContentType', 'vector');

% Export as PNG for convenient viewing.
pngFile = fullfile(figureDir, 'Figure_2.png');

exportgraphics( ...
    figureHandle, ...
    pngFile, ...
    'Resolution', 600);

fprintf('\nFigure 2 exported:\n');
fprintf('  %s\n', svgFile);
fprintf('  %s\n', pngFile);