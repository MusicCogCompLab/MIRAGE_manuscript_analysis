%% MIRAGE v1.1.0
% Technical Validation -- Build Validation Table for Review
%
% This script demonstrates the sampling procedure used to construct the
% MIRAGE metadata review table for Technical Validation.
%
% For each metadata source (GE, MB, WD, SP), the script:
%
%   1. Divides events into ten match-confidence deciles.
%   2. Samples up to 50 events from each decile.
%   3. Preserves the approximate geographic-region distribution of the
%      events within each source/decile.
%   4. Samples at most one event per radio station during each
%      source/decile sampling step.
%
% The resulting review table contains the events selected for manual
% inspection, along with their source-specific artist and track metadata.
%
% The random-number generator is seeded so that the same review sample can
% be reproduced from the same version of the MIRAGE dataset.
%
% Output:
%   Validation_ReviewTable.csv
%
% Data:
%   MIRAGE v1.1.0, downloaded automatically from Zenodo if necessary.



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



%% DOWNLOAD MIRAGE DATA FROM ZENODO

if ~isfile(mirageFile)

    fprintf('MIRAGE data not found locally.\n');
    fprintf('Downloading MIRAGE from Zenodo record %s...\n', ...
        zenodoRecord);

    zenodoAPI = sprintf( ...
        'https://zenodo.org/api/records/%s', zenodoRecord);

    record = webread(zenodoAPI);

    % Locate the Parquet dataset.
    fileNames = string({record.files.key});
    fileIndex = find(fileNames == "MIRAGE.parquet", 1);

    if isempty(fileIndex)
        error(['MIRAGE.parquet was not found in Zenodo record %s. ' ...
            'Verify the Zenodo record ID and filename.'], ...
            zenodoRecord);
    end

    downloadURL = record.files(fileIndex).links.self;

    websave(mirageFile, downloadURL);

    fprintf('MIRAGE download complete.\n');

else

    fprintf('Using local MIRAGE data:\n%s\n', mirageFile);

end


%% IMPORT MIRAGE

fprintf('Reading MIRAGE data...\n');

tab = parquetread(mirageFile);

fprintf('Imported %d MIRAGE events.\n', height(tab));


%% SAMPLING PARAMETERS
rng(12345, 'twister');

sources = ["GE", "MB", "WD", "SP"];
nDeciles = 10;
nPerDecile = 50;


%% REPRODUCE ORIGINAL EVENT ORDER

% The original validation sample was generated from a table ordered by
% radio station and event sequence. In v1.0, Event_MA_ID encoded the
% within-station event sequence. In v1.1.0, Event_MI_ID is a globally
% sequential MIRAGE event identifier.
%
% Sort first by Radio Garden station, then by MIRAGE event ID, to recreate
% the event ordering used by the original sampling procedure.

eventID = string(tab.Event_MI_ID);

% Extract the numeric portion of Event_MI_ID.
eventNumber = str2double( ...
    extractAfter(eventID, "EVT_"));

% Sort by station and then event number.
[~, sortOrder] = sortrows( ...
    [string(tab.Station_RG_ID), eventNumber], ...
    [1 2]);

tab = tab(sortOrder, :);

fprintf('Events sorted by Station_RG_ID and Event_MI_ID.\n');


%% SELECT FIELDS USED FOR SAMPLING

fieldsToSample = { ...
    'Event_MI_ID', ...
    'Event_MI_SP_MatchConfidence', ...
    'Event_MI_WD_MatchConfidence', ...
    'Event_MI_MB_MatchConfidence', ...
    'Event_MI_GE_MatchConfidence', ...
    'Station_RG_ID', ...
    'Location_NE_Region', ...
    'Location_NE_Country'};

tabSample = tab(:, fieldsToSample);

% Convert grouping variables to categorical variables.
tabSample.Location_NE_Region = ...
    categorical(tabSample.Location_NE_Region);

tabSample.Location_NE_Country = ...
    categorical(tabSample.Location_NE_Country);

tabSample.Station_RG_ID = ...
    categorical(tabSample.Station_RG_ID);



%% CALCULATE MATCH-CONFIDENCE DECILES

% Each event is assigned to a match-confidence decile separately for each
% metadata source.
%
% Decile 1 = confidence values from 0.0 to <0.1
% Decile 2 = confidence values from 0.1 to <0.2
% ...
% Decile 10 = confidence values from 0.9 to 1.0

nSources = numel(sources);

decile = NaN(height(tabSample), nSources);

for s = 1:nSources

    source = sources(s);
    
    variableName = ['Event_MI_' char(source) '_MatchConfidence'];
    confidence = str2double(tabSample.(variableName));

    valid = ~ismissing(confidence);

    d = floor(confidence(valid) * 10) + 1;

    % Match Confidence = 1.0 belongs to decile 10 rather than 11.
    d(d > nDeciles) = nDeciles;

    decile(valid, s) = d;

end


%% SAMPLE EVENTS

% selected(i,s) indicates whether event i was selected for source s.
selected = false(height(tabSample), nSources);

for s = 1:nSources

    source = sources(s);

    fprintf('\nSampling source %s...\n', source);

    for d = 1:nDeciles

        % Events belonging to this source/decile.
        eligible = find(decile(:,s) == d);

        if numel(eligible) < nPerDecile

            fprintf(['  Decile %d: only %d eligible events; ' ...
                'skipping.\n'], ...
                d, numel(eligible));

            continue

        end

        % -----------------------------------------------------------------
        % Preserve the geographic-region distribution of the population
        % within this source/decile.
        % -----------------------------------------------------------------

        regions = tabSample.Location_NE_Region(eligible);

        [regionList, ~, regionIndex] = unique(regions);

        regionCounts = accumarray(regionIndex, 1);
        regionProportions = ...
            regionCounts / sum(regionCounts);

        % Allocate approximately proportional quotas.
        regionQuota = round( ...
            regionProportions * nPerDecile);

        % Ensure every represented region receives at least one slot.
        regionQuota(regionQuota == 0) = 1;

        chosen = zeros(0,1);

        % -----------------------------------------------------------------
        % Sample within each geographic region while restricting the
        % sample to at most one event per radio station.
        % -----------------------------------------------------------------

        for r = 1:numel(regionList)

            regionEvents = ...
                eligible(regionIndex == r);

            % Randomize the order of candidate events.
            regionEvents = ...
                regionEvents(randperm(numel(regionEvents)));

            % Keep at most one event per station.
            stations = tabSample.Station_RG_ID(regionEvents);

            [~, uniqueIndex] = unique(stations, 'stable');

            regionEvents = regionEvents(uniqueIndex);

            % Select the requested regional quota.
            nTake = min( ...
                regionQuota(r), ...
                numel(regionEvents));

            chosen = [chosen; regionEvents(1:nTake)];

        end

        % -----------------------------------------------------------------
        % Backfill any remaining sample slots from the remaining eligible
        % events, again restricting to one event per station.
        % -----------------------------------------------------------------

        if numel(chosen) < nPerDecile

            remaining = ...
                setdiff(eligible, chosen, 'stable');

            remaining = ...
                remaining(randperm(numel(remaining)));

            stations = ...
                tabSample.Station_RG_ID(remaining);

            [~, uniqueIndex] = ...
                unique(stations, 'stable');

            remaining = remaining(uniqueIndex);

            nNeeded = nPerDecile - numel(chosen);

            nTake = min(nNeeded, numel(remaining));

            chosen = ...
                [chosen; remaining(1:nTake)];

        end

        % Keep exactly the requested number of events when possible.
        chosen = chosen(1:min(nPerDecile, numel(chosen)));

        selected(chosen, s) = true;

        fprintf( ...
            '  Decile %d: selected %d events.\n', ...
            d, numel(chosen));

    end

end


%% CREATE REVIEW TABLE

% Find every event/source combination selected during sampling.
[rowIndices, sourceIndices] = find(selected);

nRows = numel(rowIndices);

fprintf('\nCreating review table with %d rows...\n', nRows);


%% PREALLOCATE REVIEW TABLE

reviewTable = table();

reviewTable.Event_SE_Description = ...
    tab.Event_SE_Description(rowIndices);

reviewTable.Event_SE_DescriptionClean = ...
    tab.Event_MI_DescriptionClean(rowIndices);

reviewTable.Source_Artist = strings(nRows, 1);
reviewTable.Source_Track = strings(nRows, 1);

reviewTable.Event_MI_ID = ...
    tab.Event_MI_ID(rowIndices);

reviewTable.Station_RG_ID = ...
    tab.Station_RG_ID(rowIndices);

reviewTable.Location_NE_Continent = ...
    tab.Location_NE_Continent(rowIndices);

reviewTable.Location_NE_Region = ...
    tab.Location_NE_Region(rowIndices);

reviewTable.Location_NE_Country = ...
    tab.Location_NE_Country(rowIndices);

reviewTable.Source = strings(nRows, 1);
reviewTable.Decile = zeros(nRows, 1);


%% POPULATE SOURCE-SPECIFIC FIELDS

for k = 1:nRows

    row = rowIndices(k);
    sourceIndex = sourceIndices(k);
    source = sources(sourceIndex);

    reviewTable.Source(k) = source;
    reviewTable.Decile(k) = decile(row, sourceIndex);

    % Artist metadata.
    artistVariable = ...
        ['Artist_' char(source) '_Name'];

    reviewTable.Source_Artist(k) = ...
        string(tab.(artistVariable)(row));

    % Track metadata.
    %
    % Genius uses Track_GE_Title rather than Track_GE_Name.
    if source == "GE"

        reviewTable.Source_Track(k) = ...
            string(tab.Track_GE_Title(row));

    else

        trackVariable = ...
            ['Track_' char(source) '_Title'];

        reviewTable.Source_Track(k) = ...
            string(tab.(trackVariable)(row));

    end

end


%% ORDER COLUMNS AND ROWS

reviewTable = reviewTable(:, { ...
    'Event_SE_Description', ...
    'Event_SE_DescriptionClean', ...
    'Source_Artist', ...
    'Source_Track', ...
    'Event_MI_ID', ...
    'Station_RG_ID', ...
    'Location_NE_Continent', ...
    'Location_NE_Region', ...
    'Location_NE_Country', ...
    'Source', ...
    'Decile'});

reviewTable = sortrows(reviewTable,[10 -11]);


%% EXPORT REVIEW TABLE

outputFile = fullfile( ...
    validationDir, 'MIRAGE_ValidationTable.csv');

writetable(reviewTable, outputFile);

fprintf('\nReview table written to:\n%s\n', outputFile);

fprintf('\nDone.\n');