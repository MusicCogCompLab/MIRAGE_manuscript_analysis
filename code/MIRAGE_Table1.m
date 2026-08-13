%% MIRAGE v1.1.0
% Table 1 -- Geographic coverage statistics
%
% This script calculates descriptive statistics describing the geographic
% coverage of locations and stations in the MIRAGE MetaCorpus. (~2 min)
%
% Outputs:
%   loc_stats       - MIRAGE locations by continent
%   stations_stats  - MIRAGE stations by continent
%   country_stats   - MIRAGE countries by continent and coverage relative
%                     to Natural Earth
%   region_stats    - MIRAGE first-level geographic regions by continent
%                     and coverage relative to Natural Earth
%   state_stats     - MIRAGE first-level administrative units by continent
%                     and coverage relative to Natural Earth
%
% Data:
%   The MIRAGE MetaCorpus is downloaded automatically from the
%   version-specific Zenodo record if it is not already available locally.
%
% Requirements:
%   MATLAB with parquetread, readgeotable, and webread/websave.
%
% External geographic data:
%   Natural Earth Admin 0 country boundaries
%   Natural Earth Admin 1 state/province boundaries



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


% Download MIRAGE only if the file is not already available locally.
if ~isfile(mirageFile)

    fprintf('MIRAGE data not found locally.\n');
    fprintf('Downloading MIRAGE from Zenodo record %s...\n', ...
        zenodoRecord);

    % Query the Zenodo record.
    zenodoAPI = sprintf( ...
        'https://zenodo.org/api/records/%s', zenodoRecord);

    record = webread(zenodoAPI);

    % Identify the MIRAGE Parquet file.
    fileNames = string({record.files.key});
    fileIndex = find(fileNames == "MIRAGE.parquet", 1);

    if isempty(fileIndex)
        error(['MIRAGE.parquet was not found in Zenodo record %s. ' ...
            'Verify that the correct v1.1.0 record ID is being used ' ...
            'and that the file is named MIRAGE.parquet.'], ...
            zenodoRecord);
    end

    % Retrieve the file download URL.
    downloadURL = record.files(fileIndex).links.self;

    % Download the file.
    websave(mirageFile, downloadURL);

    fprintf('MIRAGE download complete.\n');

else

    fprintf('Using local MIRAGE data:\n%s\n', mirageFile);

end


%% IMPORT MIRAGE

fprintf('Reading MIRAGE Parquet file...\n');

tab = parquetread(mirageFile);

fprintf('MIRAGE data imported: %d rows.\n', height(tab));


%% IMPORT NATURAL EARTH

% Country-level Natural Earth data.
neCountries = readgeotable(countryFile);

% Remove Antarctica because it is not included in the MIRAGE geographic
% coverage analyses.
neCountries(ismember(neCountries.ADMIN, 'Antarctica'), :) = [];

% State/province-level Natural Earth data.
neAdmin1 = readgeotable(admin1File);


%% CREATE LOCATION TABLE

% Identify unique MIRAGE locations.
[cityID, ~, locationIndex] = unique( ...
    tab.Location_RG_ID, 'stable');

% Use the first occurrence of each location to obtain its metadata.
firstLocation = accumarray( ...
    locationIndex, (1:height(tab))', [], @min);

loc = table( ...
    cityID, ...
    str2double(tab.Location_MI_Latitude(firstLocation)), ...
    str2double(tab.Location_MI_Longitude(firstLocation)), ...
    string(tab.Location_MI_City(firstLocation)), ...
    string(tab.Location_NE_StateProvince(firstLocation)), ...
    string(tab.Location_NE_Country(firstLocation)), ...
    string(tab.Location_NE_Region(firstLocation)), ...
    string(tab.Location_NE_Continent(firstLocation)), ...
    'VariableNames', { ...
        'city_id', ...
        'latitude', ...
        'longitude', ...
        'city', ...
        'province', ...
        'country', ...
        'region', ...
        'continent'});


%% LOCATION STATISTICS

% Number of MIRAGE locations by continent.
[continents, ~, continentIndex] = unique(loc.continent);

counts = accumarray(continentIndex, 1);

percent = round(100 * counts / sum(counts));

loc_stats = table( ...
    continents, counts, percent, ...
    'VariableNames', {'continent', 'count', 'percent'});


%% STATION STATISTICS

% Identify unique MIRAGE stations.
[~, firstStation] = unique( ...
    tab.Station_RG_ID, 'stable');

% Assign each station to the continent of its associated location.
stationContinents = string( ...
    tab.Location_NE_Continent(firstStation));

[continents, ~, continentIndex] = unique(stationContinents);

counts = accumarray(continentIndex, 1);

percent = round(100 * counts / sum(counts));

stations_stats = table( ...
    continents, counts, percent, ...
    'VariableNames', {'continent', 'count', 'percent'});


%% COUNTRY COVERAGE

% Identify unique countries represented in MIRAGE.
[~, firstCountry] = unique(loc.country, 'stable');

countryContinents = loc.continent(firstCountry);

[continents, ~, continentIndex] = unique(countryContinents);

counts = accumarray(continentIndex, 1);

percent = round(100 * counts / sum(counts));

country_stats = table( ...
    continents, counts, percent, ...
    'VariableNames', {'continent', 'count', 'percent'});


%% NATURAL EARTH COUNTRY DENOMINATORS

% Natural Earth continent assignments.
neContinents = string(neCountries.CONTINENT);

% Correct Natural Earth's classification of Mauritius and Seychelles.
isAfrica = ismember( ...
    string(neCountries.NAME), ...
    ["Mauritius", "Seychelles"]);

neContinents(isAfrica) = "Africa";

% Exclude Antarctica and open-ocean regions.
exclude = ismember( ...
    neContinents, ...
    ["Antarctica", "Seven seas (open ocean)"]);

neContinents(exclude) = [];

[continents, ~, continentIndex] = unique(neContinents);

neCountryCounts = accumarray(continentIndex, 1);

% Calculate MIRAGE country coverage relative to Natural Earth.
[tf, idx] = ismember( ...
    country_stats.continent, continents);

country_stats.ne_total = zeros( ...
    height(country_stats), 1);

country_stats.coverage_percent = NaN( ...
    height(country_stats), 1);

country_stats.ne_total(tf) = ...
    neCountryCounts(idx(tf));

country_stats.coverage_percent(tf) = round( ...
    100 * country_stats.count(tf) ./ ...
    country_stats.ne_total(tf));


%% REGION COVERAGE

% Identify unique MIRAGE regions.
[~, firstRegion] = unique(loc.region, 'stable');

regionContinents = loc.continent(firstRegion);

[continents, ~, continentIndex] = unique(regionContinents);

counts = accumarray(continentIndex, 1);

percent = round(100 * counts / sum(counts));

region_stats = table( ...
    continents, counts, percent, ...
    'VariableNames', {'continent', 'count', 'percent'});


%% NATURAL EARTH REGION DENOMINATORS

% Identify one Natural Earth subregion per unique subregion.
[~, firstSubregion] = unique( ...
    string(neCountries.SUBREGION), 'stable');

neSubregions = neCountries(firstSubregion, :);

neRegionContinents = string(neSubregions.CONTINENT);

% Correct Natural Earth's classification of Mauritius and Seychelles.
neRegionContinents(ismember( ...
    string(neSubregions.NAME), ...
    ["Mauritius", "Seychelles"])) = "Africa";

% Exclude Antarctica.
neRegionContinents( ...
    neRegionContinents == "Antarctica") = [];

[continents, ~, continentIndex] = ...
    unique(neRegionContinents);

neRegionCounts = accumarray(continentIndex, 1);

[tf, idx] = ismember( ...
    region_stats.continent, continents);

region_stats.ne_total = zeros( ...
    height(region_stats), 1);

region_stats.coverage_percent = NaN( ...
    height(region_stats), 1);

region_stats.ne_total(tf) = ...
    neRegionCounts(idx(tf));

region_stats.coverage_percent(tf) = round( ...
    100 * region_stats.count(tf) ./ ...
    region_stats.ne_total(tf));


%% FIRST-LEVEL ADMINISTRATIVE-UNIT COVERAGE

% Identify unique MIRAGE first-level administrative units.
[~, firstProvince] = unique( ...
    loc.province, 'stable');

provinceContinents = loc.continent(firstProvince);

[continents, ~, continentIndex] = ...
    unique(provinceContinents);

counts = accumarray(continentIndex, 1);

percent = round(100 * counts / sum(counts));

state_stats = table( ...
    continents, counts, percent, ...
    'VariableNames', {'continent', 'count', 'percent'});


%% NATURAL EARTH ADMINISTRATIVE-UNIT DENOMINATORS

% Match Natural Earth Admin 1 units to Natural Earth countries.
[tf, countryIndex] = ismember( ...
    neAdmin1.adm0_a3, neCountries.ADM0_A3);

neAdmin1 = neAdmin1(tf, :);
countryIndex = countryIndex(tf);

adminContinents = string( ...
    neCountries.CONTINENT(countryIndex));

% Correct Natural Earth's classification of Mauritius and Seychelles.
adminContinents(ismember( ...
    string(neAdmin1.admin), ...
    ["Mauritius", "Seychelles"])) = "Africa";

% Exclude Antarctica and open-ocean regions.
exclude = ismember( ...
    adminContinents, ...
    ["Antarctica", "Seven seas (open ocean)"]);

adminContinents(exclude) = [];

[continents, ~, continentIndex] = ...
    unique(adminContinents);

neAdminCounts = accumarray(continentIndex, 1);

[tf, idx] = ismember( ...
    state_stats.continent, continents);

state_stats.ne_total = zeros( ...
    height(state_stats), 1);

state_stats.coverage_percent = NaN( ...
    height(state_stats), 1);

state_stats.ne_total(tf) = ...
    neAdminCounts(idx(tf));

state_stats.coverage_percent(tf) = round( ...
    100 * state_stats.count(tf) ./ ...
    state_stats.ne_total(tf));


%% EXPORT RESULTS

writetable( ...
    loc_stats, ...
    fullfile(resultsDir, ...
    'MIRAGE_location_statistics.csv'));

writetable( ...
    stations_stats, ...
    fullfile(resultsDir, ...
    'MIRAGE_station_statistics.csv'));

writetable( ...
    country_stats, ...
    fullfile(resultsDir, ...
    'MIRAGE_country_coverage.csv'));

writetable( ...
    region_stats, ...
    fullfile(resultsDir, ...
    'MIRAGE_region_coverage.csv'));

writetable( ...
    state_stats, ...
    fullfile(resultsDir, ...
    'MIRAGE_admin1_coverage.csv'));

fprintf('\nGeographic coverage analysis complete.\n');