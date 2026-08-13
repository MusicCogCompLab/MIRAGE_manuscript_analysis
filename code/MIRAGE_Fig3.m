%% MIRAGE v1.1.0
% Figure 3 -- Match confidence, validation precision, geographic coverage,
%             and source overlap
%
% Plots:
%   (a) Cumulative proportion of MIRAGE events by match-confidence decile.
%   (b) Geographic distribution of average maximum match confidence.
%   (c) Validation precision by match-confidence decile.
%   (d) Overlap of events across metadata sources (UpSet plot).
%
% Inputs:
%   data/MIRAGE.parquet
%   validation/MIRAGE_ValidationTableAnnotated.csv
%
% Outputs:
%   figures/Figure_3a.svg
%   figures/Figure_3a.png
%   figures/Figure_3b.svg
%   figures/Figure_3b.png
%   figures/Figure_3c.svg
%   figures/Figure_3c.png
%   figures/Figure_3d.svg
%   figures/Figure_3d.png
%
% Natural Earth country boundaries are distributed with the repository.
%
% The validation sample is NOT recreated here. Plot (c) uses the
% previously generated and manually annotated validation table directly.



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

% Annotated validation table.
validationFile = fullfile( ...
    validationDir, ...
    'MIRAGE_ValidationTableAnnotated.csv');

% Natural Earth country boundaries.
countryFile = fullfile( ...
    naturalEarthDir, ...
    'ne_10m_admin_0_countries.json');

% Natural Earth first-level administrative boundaries.
admin1File = fullfile( ...
    naturalEarthDir, ...
    'ne_10m_admin_1_states_provinces.json');

% Zenodo record for MIRAGE v1.1.0.
zenodoRecord = '21891580';

% Metadata sources.
sources = ["GE", "MB", "WD", "SP"];

% Number of match-confidence deciles.
nDeciles = 10;



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
        'https://zenodo.org/api/records/%s', ...
        zenodoRecord);

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

%% IMPORT MIRAGE

fprintf('Reading MIRAGE data...\n');

tab = parquetread(mirageFile);

fprintf('MIRAGE data imported: %d rows.\n', height(tab));

%% IMPORT ANNOTATED VALIDATION TABLE

if ~isfile(validationFile)

    error(['Annotated validation table was not found:\n%s\n\n' ...
        'Expected file:\nvalidation/MIRAGE_ValidationTableAnnotated.csv'], ...
        validationFile);

end

fprintf('Reading annotated validation table...\n');

tabValidation = readtable(validationFile);

fprintf('Validation table imported: %d rows.\n', ...
    height(tabValidation));


%% ========================================================================
% PLOT A -- CUMULATIVE PROPORTION OF EVENTS BY MATCH-CONFIDENCE DECILE
% ========================================================================

fprintf('\nCreating Plot A...\n');

nSources = numel(sources);

cdfMIRAGE = nan(nSources, nDeciles);

for s = 1:nSources

    source = sources(s);

    variableName = ...
        ['Event_MI_' char(source) '_MatchConfidence'];

    confidence = str2double(tab.(variableName));

    % Keep only events with a match-confidence value for this source.
    valid = ~isnan(confidence);
    confidence = confidence(valid);

    % Convert match confidence to deciles.
    decile = floor(confidence * 10) + 1;

    % Confidence = 1.0 belongs to decile 10.
    decile(decile > nDeciles) = nDeciles;

    % Count events in each decile.
    counts = zeros(1, nDeciles);

    for d = 1:nDeciles
        counts(d) = sum(decile == d);
    end

    % Cumulative proportion among events with a confidence score.
    cdfMIRAGE(s,:) = cumsum(counts) / sum(counts);

end

% Source colors.
sourceColors = struct( ...
    'SP', [75 175 98]  / 255, ...
    'WD', [164 218 183] / 255, ...
    'MB', [68 181 197] / 255, ...
    'GE', [44 126 185] / 255);

figureHandle = figure( ...
    'Color', 'white', ...
    'Units', 'inches', ...
    'Position', [1 1 6.5 4.5]);

hold on;

offsets = linspace(-0.18, 0.18, nSources);

for s = 1:nSources

    source = char(sources(s));
    c = sourceColors.(source);

    x = (1:nDeciles) + offsets(s);

    plot( ...
        x, ...
        cdfMIRAGE(s,:), ...
        '-o', ...
        'Color', c, ...
        'MarkerFaceColor', c, ...
        'MarkerEdgeColor', c, ...
        'LineWidth', 1.2, ...
        'MarkerSize', 4, ...
        'DisplayName', source);

end

xlabel( ...
    'Match Confidence Decile', ...
    'FontName', 'Times New Roman', ...
    'FontSize', 10);

ylabel( ...
    'Cumulative Proportion', ...
    'FontName', 'Times New Roman', ...
    'FontSize', 10);

set(gca, ...
    'FontName', 'Times New Roman', ...
    'FontSize', 9, ...
    'Box', 'off', ...
    'TickDir', 'out');

xlim([0.5 10.5]);
ylim([-0.02 1.02]);

xticks(1:nDeciles);
yticks(0:0.2:1);

grid off;

legend( ...
    'Location', 'northwest', ...
    'FontName', 'Times New Roman', ...
    'FontSize', 9, ...
    'Box', 'off');

% Export Plot A.
svgFile = fullfile(figureDir, 'Figure_3a.svg');
pngFile = fullfile(figureDir, 'Figure_3a.png');

exportgraphics( ...
    figureHandle, ...
    svgFile, ...
    'ContentType', 'vector');

exportgraphics( ...
    figureHandle, ...
    pngFile, ...
    'Resolution', 600);

close(figureHandle);

fprintf('Plot A exported.\n');


%% ========================================================================
% PLOT B -- CHLOROPLETH OF MATCH CONFIDENCE BY COUNTRY
% ========================================================================

fprintf('\nCreating Plot B...\n');

% Natural Earth country boundaries.
basemap = readgeotable(countryFile);

% Remove Antarctica.
basemap( ...
    ismember(string(basemap.ADMIN), "Antarctica"), :) = [];


% -------------------------------------------------------------------------
% Calculate average maximum match confidence by country.
% -------------------------------------------------------------------------

confidence = nan(height(tab), nSources);

for s = 1:nSources

    source = sources(s);

    variableName = ...
        ['Event_MI_' char(source) '_MatchConfidence'];

    confidence(:,s) = ...
        str2double(tab.(variableName));

end

% Maximum available source confidence for each event.
maxConfidence = max(confidence, [], 2, 'omitnan');

% Country associated with each event.
country = string(tab.Location_NE_Country);

[countryList, ~, countryIndex] = unique(country);

% Average maximum match-confidence by country.
avgConfidence = accumarray( ...
    countryIndex, ...
    maxConfidence, ...
    [], ...
    @(x) mean(x, 'omitnan'), ...
    NaN);

countryConfidence = table( ...
    countryList, ...
    avgConfidence, ...
    'VariableNames', {'Country', 'AvgConfidence'});


% -------------------------------------------------------------------------
% Harmonize MIRAGE country names with Natural Earth.
% -------------------------------------------------------------------------

% Harmonize MIRAGE country names with Natural Earth names.

countryConfidence.Country( ...
    countryConfidence.Country == "Cape Verde") = "Cabo Verde";

countryConfidence.Country( ...
    countryConfidence.Country == "Czech Republic") = "Czechia";

countryConfidence.Country( ...
    countryConfidence.Country == "People's Republic of China") = "China";

countryConfidence.Country( ...
    countryConfidence.Country == "Tanzania") = ...
    "United Republic of Tanzania";

countryConfidence.Country( ...
    countryConfidence.Country == "Serbia") = ...
    "Republic of Serbia";

countryConfidence.Country( ...
    countryConfidence.Country == "United States") = ...
    "United States of America";

countryConfidence.Country( ...
    countryConfidence.Country == ...
    "United States of America Virgin Islands") = ...
    "United States Virgin Islands";

% -------------------------------------------------------------------------
% Match Natural Earth countries to MIRAGE country estimates.
% -------------------------------------------------------------------------

[tf, countryIndex] = ismember( ...
    string(basemap.ADMIN), ...
    countryConfidence.Country);

% -------------------------------------------------------------------------
% Create geographic figure.
% -------------------------------------------------------------------------

figureHandle = figure( ...
    'Color', 'white', ...
    'Units', 'inches', ...
    'Position', [1 1 10 6]);

layout = tiledlayout(figureHandle, 1, 1);

gx = geoaxes(layout);

hold(gx, 'on');

% Plot country outlines.
countryLayer = geoplot( ...
    gx, ...
    basemap, ...
    'FaceColor', 'none', ...
    'EdgeColor', [0.6 0.6 0.6]);

% White-to-blue colormap.
nColors = 256;


% Use viridis when available; otherwise fall back to MATLAB's parula.
if exist('viridis', 'file') == 2
    cmap = viridis(256);
else
    cmap = parula(256);
end

colormap(gx, cmap);

% Plot countries individually.
for i = 1:height(basemap)

    if ~tf(i)

        faceColor = [1 1 1];

    else

        value = ...
            countryConfidence.AvgConfidence(countryIndex(i));

        if isnan(value)

            faceColor = [1 1 1];

        else

            colorIndex = ...
                max(1, min(nColors, ...
                round(value * (nColors - 1)) + 1));

            faceColor = cmap(colorIndex,:);

        end

    end

    geoplot( ...
        gx, ...
        basemap.Shape(i), ...
        'FaceColor', faceColor, ...
        'EdgeColor', 'none');

end

% Map limits and formatting.
gx.Grid = 'off';
gx.LongitudeAxis.Visible = 'off';
gx.LatitudeAxis.Visible = 'off';
gx.Scalebar.Visible = 'off';
gx.Basemap = 'none';
gx.Color = 'white';

geolimits( ...
    gx, ...
    [-75 75], ...
    [-180 180]);

% Colorbar.
colorbarHandle = colorbar;

colorbarHandle.Label.String = ...
    'Average maximum match confidence';

colorbarHandle.FontName = 'Times New Roman';
colorbarHandle.FontSize = 10;

caxis(gx, [0 1]);

% Export Plot B.
svgFile = fullfile(figureDir, 'Figure_3b.svg');
pngFile = fullfile(figureDir, 'Figure_3b.png');

exportgraphics( ...
    figureHandle, ...
    svgFile, ...
    'ContentType', 'vector');

exportgraphics( ...
    figureHandle, ...
    pngFile, ...
    'Resolution', 600);

close(figureHandle);

fprintf('Plot B exported.\n');


%% ========================================================================
% PLOT C -- VALIDATION PRECISION BY MATCH-CONFIDENCE DECILE
% ========================================================================

fprintf('\nCreating Plot C...\n');

% The validation table already contains the manually reviewed events and
% their Match annotations. No sampling or recreation of the validation
% sample is performed here.

% Check required fields.
requiredFields = ...
    {'Source', 'Decile', 'Match'};

for i = 1:numel(requiredFields)

    if ~ismember(requiredFields{i}, ...
            tabValidation.Properties.VariableNames)

        error( ...
            'Validation table is missing required field: %s', ...
            requiredFields{i});

    end

end

precision = nan(nSources, nDeciles);
nReviewed = zeros(nSources, nDeciles);

for s = 1:nSources

    source = char(sources(s));

    for d = 1:nDeciles

        idx = strcmp( ...
            string(tabValidation.Source), ...
            source) & ...
            tabValidation.Decile == d;

        if any(idx)

            matchValues = ...
                tabValidation.Match(idx);

            % Remove missing Match annotations if any exist.
            matchValues = matchValues(~ismissing(matchValues));

            nReviewed(s,d) = numel(matchValues);

            if nReviewed(s,d) > 0

                precision(s,d) = ...
                    mean(matchValues);

            end

        end

    end

end

% Calculate exact binomial confidence intervals.
alpha = 0.05;

ciLow = nan(size(precision));
ciHigh = nan(size(precision));

for s = 1:nSources

    for d = 1:nDeciles

        n = nReviewed(s,d);

        if n > 0

            k = round(precision(s,d) * n);

            [~, pci] = binofit(k, n, alpha);

            ciLow(s,d) = pci(1);
            ciHigh(s,d) = pci(2);

        end

    end

end

% Create figure.
figureHandle = figure( ...
    'Color', 'white', ...
    'Units', 'inches', ...
    'Position', [1 1 6.5 4.5]);

hold on;

offsets = linspace(-0.3, 0.3, nSources);

for s = 1:nSources

    source = char(sources(s));
    c = sourceColors.(source);

    x = (1:nDeciles) + offsets(s);

    errorbar( ...
        x, ...
        precision(s,:), ...
        precision(s,:) - ciLow(s,:), ...
        ciHigh(s,:) - precision(s,:), ...
        '-o', ...
        'Color', c, ...
        'MarkerFaceColor', c, ...
        'MarkerEdgeColor', c, ...
        'MarkerSize', 3, ...
        'LineWidth', 0.8, ...
        'DisplayName', source);

end

xlabel( ...
    'Match Confidence Decile', ...
    'FontName', 'Times New Roman', ...
    'FontSize', 10);

ylabel( ...
    'Precision', ...
    'FontName', 'Times New Roman', ...
    'FontSize', 10);

set(gca, ...
    'FontName', 'Times New Roman', ...
    'FontSize', 9, ...
    'Box', 'off', ...
    'TickDir', 'out');

ylim([-0.05 1.05]);
xlim([0.5 10.5]);

xticks(1:nDeciles);
yticks(0:0.2:1);

grid off;

legend( ...
    'Location', 'northwest', ...
    'FontName', 'Times New Roman', ...
    'FontSize', 9, ...
    'Box', 'off');

% Export Plot C.
svgFile = fullfile(figureDir, 'Figure_3c.svg');
pngFile = fullfile(figureDir, 'Figure_3c.png');

exportgraphics( ...
    figureHandle, ...
    svgFile, ...
    'ContentType', 'vector');

exportgraphics( ...
    figureHandle, ...
    pngFile, ...
    'Resolution', 600);

close(figureHandle);

fprintf('Plot C exported.\n');


%% ========================================================================
% PLOT D -- UPSET PLOT OF SOURCE OVERLAP
% ========================================================================

fprintf('\nCreating Plot D...\n');

% The UpSet plot represents which metadata sources provide metadata for 
% each MIRAGE event.

% Data is therefore based on the complete MIRAGE dataset, not the
% validation sample.

hasSource = false(height(tab), nSources);

for s = 1:nSources

    source = sources(s);

    variableName = ...
        ['Event_MI_' char(source) '_MatchConfidence'];

    confidence = str2double(tab.(variableName));

    hasSource(:,s) = ~isnan(confidence);

end

Data = hasSource;

% Source names corresponding to the columns of Data.
setName = cellstr(sources);

% -------------------------------------------------------------------------
% Calculate source intersections.
% -------------------------------------------------------------------------

pBool = ...
    abs(dec2bin((1:(2^size(Data,2)-1))')) - 48;

[pPos, ~] = find( ...
    ((pBool * (1-Data')) | ...
    ((1-pBool) * Data')) == 0);

sPPos = sort(pPos);

dPPos = find([diff(sPPos); 1]);

pType = sPPos(dPPos);

pCount = diff([0; dPPos]);

[pCount, pInd] = sort( ...
    pCount, ...
    'descend');

pType = pType(pInd);

% Number of intersection combinations to display. (N=8)
nPlotIntersections = min(8, numel(pType));

% Restrict the displayed intersection combinations.
pCount = pCount(1:nPlotIntersections);
pType = pType(1:nPlotIntersections);

% Source set sizes.
sCount = sum(Data, 1);

[sCount, sInd] = sort( ...
    sCount, ...
    'descend');

sType = 1:size(Data,2);
sType = sType(sInd);

% -------------------------------------------------------------------------
% Create UpSet figure.
% -------------------------------------------------------------------------

bar2Color = [ ...
    253 255 228;
    164 218 183;
    68 181 197;
    44 126 185;
    35 51 154] / 255;

lineColor = [61 58 61] / 255;

fig = figure( ...
    'Units', 'normalized', ...
    'Position', [.3 .2 .5 .63], ...
    'Color', [1 1 1]);

% Intersection-size axes.
axI = axes('Parent', fig);
hold(axI, 'on');

set(axI, ...
    'Position', [.33 .35 .655 .61], ...
    'LineWidth', 1.2, ...
    'Box', 'off', ...
    'TickDir', 'out', ...
    'FontName', 'Times New Roman', ...
    'FontSize', 12, ...
    'XTick', [], ...
    'XLim', [0 length(pType)+1]);

axI.YLabel.String = 'Intersection Size';
axI.YLabel.FontSize = 16;

% Set-size axes.
axS = axes('Parent', fig);
hold(axS, 'on');

set(axS, ...
    'Position', [.01 .08 .245 .26], ...
    'LineWidth', 1.2, ...
    'Box', 'off', ...
    'TickDir', 'out', ...
    'FontName', 'Times New Roman', ...
    'FontSize', 12, ...
    'YColor', 'none', ...
    'YLim', [.5 size(Data,2)+.5], ...
    'YAxisLocation', 'right', ...
    'XDir', 'reverse', ...
    'YTick', []);

axS.XLabel.String = 'Set Size';
axS.XLabel.FontSize = 16;

% Relationship axes.
axL = axes('Parent', fig);
hold(axL, 'on');

set(axL, ...
    'Position', [.33 .08 .655 .26], ...
    'YColor', 'none', ...
    'YLim', [.5 size(Data,2)+.5], ...
    'XColor', 'none', ...
    'XLim', axI.XLim);


% -------------------------------------------------------------------------
% Intersection bars.
% -------------------------------------------------------------------------

barHdlI = bar(axI, pCount);

% Light-gray intersection bars.
barHdlI.FaceColor = [165/255 181/255 183/255];
barHdlI.EdgeColor = 'none';


% -------------------------------------------------------------------------
% Set-size bars.
% -------------------------------------------------------------------------

barHdlS = barh( ...
    axS, ...
    sCount, ...
    'BarWidth', .6);

barHdlS.EdgeColor = 'none';
barHdlS.BaseLine.Color = 'none';

for i = 1:size(Data,2)

    annotation( ...
        'textbox', ...
        [(axS.Position(1)+axS.Position(3)+axI.Position(1))/2-.02, ...
        axS.Position(2)+axS.Position(4)/size(Data,2)*(i-.5)-.02, ...
        .04, .04], ...
        'String', setName{sInd(i)}, ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'FitBoxToText', 'on', ...
        'LineStyle', 'none', ...
        'FontName', 'Times New Roman', ...
        'FontSize', 13);

end

% Assign set-size bar colors by source.
sourceColors = struct( ...
    'SP', [75 175 98]  / 255, ...   % green
    'WD', [164 218 183] / 255, ...  % light green
    'MB', [68 181 197] / 255, ...   % cyan
    'GE', [44 126 185] / 255);      % blue

barHdlS.FaceColor = 'flat';

sstr = cell(size(Data,2),1);

for i = 1:size(Data,2)

    % sInd gives the source identity after sorting by set size.
    src = setName{sInd(i)};

    % Assign the correct source-specific color.
    barHdlS.CData(i,:) = sourceColors.(src);

    % Add the set-size label.
    sstr{i} = [num2str(sCount(i)), ' '];

end

text( ...
    axS, ...
    sCount, ...
    1:size(Data,2), ...
    sstr, ...
    'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'middle', ...
    'FontName', 'Times New Roman', ...
    'FontSize', 12, ...
    'Color', [61 58 61]/255);

% -------------------------------------------------------------------------
% Relationship matrix.
% -------------------------------------------------------------------------

patchColor = [248 246 249; 255 254 255] / 255;

for i = 1:size(Data,2)

    fill( ...
        axL, ...
        axI.XLim([1 2 2 1]), ...
        [-.5 -.5 .5 .5] + i, ...
        patchColor(mod(i+1,2)+1,:), ...
        'EdgeColor', 'none');

end

[tX, tY] = meshgrid( ...
    1:length(pType), ...
    1:size(Data,2));

plot( ...
    axL, ...
    tX(:), ...
    tY(:), ...
    'o', ...
    'Color', [233 233 233]/255, ...
    'MarkerFaceColor', [233 233 233]/255, ...
    'MarkerSize', 10);

for i = 1:length(pType)

    tY = find(pBool(pType(i),:));

    oY = zeros(size(tY));

    for j = 1:length(tY)
        oY(j) = find(sType == tY(j));
    end

    tX = i * ones(size(tY));

    plot( ...
        axL, ...
        tX(:), ...
        oY(:), ...
        '-o', ...
        'Color', lineColor, ...
        'MarkerEdgeColor', 'none', ...
        'MarkerFaceColor', lineColor, ...
        'MarkerSize', 10, ...
        'LineWidth', 2);

end

% Export Plot D.
svgFile = fullfile(figureDir, 'Figure_3d.svg');
pngFile = fullfile(figureDir, 'Figure_3d.png');

exportgraphics( ...
    fig, ...
    svgFile, ...
    'ContentType', 'vector');

exportgraphics( ...
    fig, ...
    pngFile, ...
    'Resolution', 600);

close(fig);

fprintf('Plot D exported.\n');


%% COMPLETE

fprintf('\nFigure 3 panel generation complete.\n');
fprintf('Files written to:\n%s\n', figureDir);