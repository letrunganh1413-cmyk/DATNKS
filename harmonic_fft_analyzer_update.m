function harmonic_fft_analyzer_update
% HARMONIC_FFT_ANALYZER_UPDATE2
% UI for harmonic-spectrum / THD analysis of an Excel (.xlsx/.xls) or
% CSV (.csv) file containing:
%   Column 1: time
%   Column 2: signal_value
%
% Processing chain (fundamental frequency f0 is FIXED by the user, e.g. 50 Hz):
%   1) Clean data (remove NaN/Inf, sort, remove duplicate times).
%   2) Find the largest INTEGER number of cycles of f0 contained in the
%      data, starting from the first sample. The remaining tail (less than
%      one full cycle) is discarded.
%   3) Resample that window onto a uniform grid with an integer number of
%      samples per cycle (the repeated end-point sample is never included).
%   4) FFT of the window: harmonic k falls exactly on bin k*nCycles, so
%      there is no spectral leakage and no "nearest bin" ambiguity.
%
% The time column may contain negative values; only time differences matter.
%
% Usage:
%   >> harmonic_fft_analyzer_update2

    % ----------------------- Main UI -----------------------
    fig = uifigure( ...
        'Name', 'Harmonic / FFT Analysis', ...
        'Position', [100 50 1100 900]);

    % File selection
    uilabel(fig, ...
        'Position', [30 850 90 22], ...
        'Text', 'Data file:');

    fileEdit = uieditfield(fig, 'text', ...
        'Position', [120 850 700 22], ...
        'Editable', 'off');

    uibutton(fig, 'push', ...
        'Position', [830 850 100 22], ...
        'Text', 'Browse...', ...
        'ButtonPushedFcn', @browseFile);

    % Parameters
    uilabel(fig, ...
        'Position', [30 810 120 22], ...
        'Text', 'Max harmonic:');

    maxHarmEdit = uieditfield(fig, 'numeric', ...
        'Position', [150 810 80 22], ...
        'Value', 50, ...
        'Limits', [1 Inf], ...
        'RoundFractionalValues', true);

    uilabel(fig, ...
        'Position', [250 810 175 22], ...
        'Text', 'Fundamental (Hz):');

    fundEdit = uieditfield(fig, 'numeric', ...
        'Position', [425 810 80 22], ...
        'Value', 50, ...
        'Limits', [1e-3 Inf]);

    % Analyze / export
    uibutton(fig, 'push', ...
        'Position', [530 810 130 30], ...
        'Text', 'Analyze', ...
        'ButtonPushedFcn', @analyzeFile);

    uibutton(fig, 'push', ...
        'Position', [680 810 150 30], ...
        'Text', 'Export Report...', ...
        'ButtonPushedFcn', @exportReport);

    statusLabel = uilabel(fig, ...
        'Position', [30 775 1040 22], ...
        'Text', 'Select an Excel or CSV file and click Analyze.');

    % Summary panel
    summaryPanel = uipanel(fig, ...
        'Title', 'FFT Summary', ...
        'Position', [30 550 400 210]);

    summaryText = uitextarea(summaryPanel, ...
        'Position', [10 10 380 170], ...
        'Editable', 'off', ...
        'Value', {'No analysis performed.'});

    % Harmonic table (named harmTable so it does not shadow table())
    harmTable = uitable(fig, ...
        'Position', [30 30 700 250], ...
        'ColumnName', {'Harmonic', 'Frequency (Hz)', ...
                       'RMS', 'Phase (deg)', 'Magnitude (%)'}, ...
        'ColumnEditable', false);

    % Spectrum axes
    ax = uiaxes(fig, ...
        'Position', [450 550 600 210]);
    title(ax, 'Harmonic Spectrum');
    xlabel(ax, 'Frequency (Hz)');
    ylabel(ax, 'RMS magnitude');
    grid(ax, 'on');

    % Time-domain signal axes (original data from the file)
    axSig = uiaxes(fig, ...
        'Position', [30 295 1020 240]);
    title(axSig, 'Input Signal (from file)');
    xlabel(axSig, 'Time (s)');
    ylabel(axSig, 'signal\_value');
    grid(axSig, 'on');

    % Storage
    result = [];

    % ----------------------- Callbacks -----------------------
    function browseFile(~, ~)
        [file, path] = uigetfile( ...
            {'*.xlsx;*.xls;*.csv', 'Excel / CSV files (*.xlsx, *.xls, *.csv)'; ...
             '*.xlsx;*.xls', 'Excel files (*.xlsx, *.xls)'; ...
             '*.csv', 'CSV files (*.csv)'}, ...
            'Select Excel or CSV file');

        if isequal(file, 0)
            return;
        end

        fileEdit.Value = fullfile(path, file);
        statusLabel.Text = 'File selected. Click Analyze.';
    end

    function analyzeFile(~, ~)
        filename = strtrim(fileEdit.Value);

        if isempty(filename) || ~isfile(filename)
            uialert(fig, 'Please select a valid Excel or CSV file.', ...
                'File error');
            return;
        end

        try
            maxH = round(maxHarmEdit.Value);
            f0 = fundEdit.Value;

            if maxH < 1
                error('Maximum harmonic must be >= 1.');
            end
            if ~isfinite(f0) || f0 <= 0
                error('Fundamental frequency must be greater than zero.');
            end

            % ---------------- Read Excel / CSV ----------------
            [~, ~, fileExt] = fileparts(filename);
            if strcmpi(fileExt, '.csv')
                % Delimiter (comma, semicolon, tab...) is auto-detected.
                T = readtable(filename, 'VariableNamingRule', 'preserve');
            else
                T = readtable(filename);
            end

            names = lower(string(T.Properties.VariableNames));
            timeIdx = find(names == "time", 1);
            sigIdx  = find(names == "signal_value", 1);

            if isempty(timeIdx) || isempty(sigIdx)
                if width(T) < 2
                    error(['The file must contain two columns: ' ...
                           'time and signal_value.']);
                end
                timeIdx = 1;
                sigIdx = 2;
            end

            t = toNumericColumn(T{:, timeIdx});
            x = toNumericColumn(T{:, sigIdx});

            % Remove NaN/Inf
            valid = isfinite(t) & isfinite(x);
            t = t(valid);
            x = x(valid);

            if numel(t) < 8
                error('Not enough valid samples.');
            end

            % Sort by time, remove duplicate time samples
            [t, order] = sort(t);
            x = x(order);
            [t, uniqueIdx] = unique(t, 'stable');
            x = x(uniqueIdx);

            if numel(t) < 8
                error('Not enough unique time samples.');
            end

            % Original data kept for the time-domain plot
            tPlot = t;
            xPlot = x;
            nOrig = numel(t);

            % Shift time origin (time may be negative)
            t0 = t(1);
            t = t - t0;

            dt = diff(t);
            dtMean = mean(dt);
            dataSpan = t(end);

            if dataSpan <= 0 || dtMean <= 0
                error('Invalid time span.');
            end

            % ---------------- Sampling uniformity ----------------
            nonuniformity = max(abs(dt - dtMean)) / dtMean;

            if nonuniformity > 1e-3
                warningText = sprintf( ...
                    'Non-uniform sampling detected (%.3g relative variation); data resampled.', ...
                    nonuniformity);
            else
                warningText = '';
            end

            % ---------------- Integer-cycle window ----------------
            T0 = 1 / f0;
            % Half-sample tolerance so that data covering exactly n cycles
            % (including the last end-point sample) gives n cycles.
            nCycles = floor((dataSpan + 0.5 * dtMean) * f0);

            if nCycles < 1
                error(['Data span (%.3g cycles) is shorter than one ' ...
                       'cycle of the fundamental (%.6g Hz).'], ...
                       dataSpan * f0, f0);
            end

            Tw = nCycles * T0;                          % window length
            nPerCycle = max(round(T0 / dtMean), 4);     % samples / cycle
            N = nCycles * nPerCycle;
            tw = (0:N-1).' * (Tw / N);                  % excludes end point

            xw = interp1(t, x, tw, 'spline');

            if any(~isfinite(xw))
                error('Resampling to the integer-cycle window failed.');
            end

            Fs = N / Tw;
            Ttotal = Tw;
            unusedCycles = dataSpan * f0 - nCycles;

            x = xw;                 % analysis signal
            tAnalysis = tw;

            % ---------------- Basic quantities ----------------
            totalRMS  = sqrt(mean(x.^2));   % including DC
            peakValue = max(abs(x));

            xMean = mean(x);
            xAC = x - xMean;
            dcRMS = abs(xMean);

            % ---------------- FFT (rectangular window) ----------------
            % The window holds an integer number of cycles, so the
            % rectangular window is exact (no leakage) for the components
            % at k*f0.
            X = fft(xAC);

            P2 = abs(X) / N;
            P1 = P2(1:floor(N/2)+1);
            if numel(P1) > 2
                P1(2:end-1) = 2 * P1(2:end-1);
            end

            f = (0:floor(N/2)).' * (Fs / N);    % resolution = f0/nCycles
            rmsSpectrum = P1 / sqrt(2);

            % ---------------- Harmonic report ----------------
            harmonic = (1:maxH).';
            freqH = harmonic * f0;

            rmsH = nan(maxH,1);
            phaseH = nan(maxH,1);
            magPct = nan(maxH,1);
            binH = nan(maxH,1);

            for k = 1:maxH
                idx = k * nCycles + 1;      % exact bin (MATLAB 1-based)

                if idx > numel(f)
                    continue;               % beyond Nyquist -> NaN
                end

                binH(k) = idx;
                rmsH(k) = rmsSpectrum(idx);
                phaseH(k) = angle(X(idx)) * 180/pi;
            end

            fundRMS = rmsH(1);

            if ~isfinite(fundRMS) || fundRMS <= eps
                THD = NaN;
                magPct(:) = NaN;
            else
                magPct = 100 * rmsH / fundRMS;

                if maxH >= 2
                    thdValues = rmsH(2:maxH);
                    thdValues = thdValues(isfinite(thdValues));

                    if isempty(thdValues)
                        THD = 0;
                    else
                        THD = 100 * sqrt(sum(thdValues.^2)) / fundRMS;
                    end
                else
                    THD = 0;
                end
            end

            reportTable = table( ...
                harmonic, ...
                freqH, ...
                rmsH, ...
                phaseH, ...
                magPct, ...
                'VariableNames', { ...
                    'Harmonic', ...
                    'Frequency_Hz', ...
                    'RMS', ...
                    'Phase_deg', ...
                    'Magnitude_percent_of_fundamental'});

            % ---------------- Store result ----------------
            result = struct();
            result.time = tAnalysis;
            result.signal = x;
            result.Fs = Fs;
            result.N = N;
            result.Ttotal = Ttotal;
            result.nCycles = nCycles;
            result.samplesPerCycle = nPerCycle;
            result.f0 = f0;
            result.dcRMS = dcRMS;
            result.fundamentalRMS = fundRMS;
            result.totalRMS = totalRMS;
            result.peakValue = peakValue;
            result.THD_percent = THD;
            result.frequency = f;
            result.rmsSpectrum = rmsSpectrum;
            result.reportTable = reportTable;
            result.filename = filename;
            result.warningText = warningText;

            % ---------------- Summary ----------------
            summaryText.Value = { ...
                sprintf('File: %s', getFileName(filename)), ...
                sprintf('Original samples: %d', nOrig), ...
                sprintf('Fundamental f0: %.9g Hz', f0), ...
                sprintf('Cycles analysed: %d (unused tail: %.3f cycle)', ...
                        nCycles, unusedCycles), ...
                sprintf('Analysis samples: %d (%d / cycle)', N, nPerCycle), ...
                sprintf('Sampling frequency: %.9g Hz', Fs), ...
                sprintf('Window length: %.9g s', Ttotal), ...
                sprintf('Freq. resolution: %.6g Hz', Fs / N), ...
                sprintf('DC component RMS: %.9g', dcRMS), ...
                sprintf('Fundamental RMS: %.9g', fundRMS), ...
                sprintf('Total RMS: %.9g', totalRMS), ...
                sprintf('Peak value: %.9g', peakValue), ...
                sprintf('THD: %.6f %%', THD)};

            msg = sprintf('Analysis completed: f0 = %.6g Hz, %d cycles used.', ...
                          f0, nCycles);
            if nCycles < 3
                msg = [msg ' Few cycles: noise averaging is limited.'];
            end
            if ~isempty(warningText)
                msg = [msg ' ' warningText];
            end
            statusLabel.Text = msg;

            % ---------------- Table ----------------
            harmTable.Data = [ ...
                reportTable.Harmonic, ...
                reportTable.Frequency_Hz, ...
                reportTable.RMS, ...
                reportTable.Phase_deg, ...
                reportTable.Magnitude_percent_of_fundamental ];

            % ---------------- Spectrum plot ----------------
            validPlot = isfinite(freqH) & isfinite(rmsH);
            cla(ax);

            stem(ax, freqH(validPlot), rmsH(validPlot), ...
                'filled', 'MarkerSize', 4);

            title(ax, sprintf('Harmonic Spectrum - THD = %.4f %%', THD));
            xlabel(ax, 'Frequency (Hz)');
            ylabel(ax, 'RMS magnitude');
            grid(ax, 'on');

            % ---------------- Signal plot ----------------
            % Original data (blue) and the integer-cycle window used for
            % the FFT (red).
            cla(axSig);
            plot(axSig, tPlot, xPlot, 'b-', 'LineWidth', 1);
            hold(axSig, 'on');
            plot(axSig, t0 + tAnalysis, x, 'r-', 'LineWidth', 1.2);
            hold(axSig, 'off');
            legend(axSig, {'Original data', ...
                sprintf('Analysed window (%d cycles)', nCycles)}, ...
                'Location', 'best');
            title(axSig, sprintf('Input Signal - %s', ...
                strrep(getFileName(filename), '_', '\_')));
            xlabel(axSig, 'Time (s)');
            ylabel(axSig, 'signal\_value');
            axis(axSig, 'tight');
            grid(axSig, 'on');

        catch ME
            uialert(fig, ME.message, 'Analysis error');
        end
    end

    function exportReport(~, ~)
        if isempty(result)
            uialert(fig, 'Please analyze a file first.', ...
                'No result');
            return;
        end

        [file, path] = uiputfile( ...
            {'*.xlsx', 'Excel report (*.xlsx)'}, ...
            'Save FFT report', ...
            'FFT_Harmonic_Report.xlsx');

        if isequal(file, 0)
            return;
        end

        outFile = fullfile(path, file);

        try
            summaryTable = table( ...
                string(getFileName(result.filename)), ...
                result.N, ...
                result.nCycles, ...
                result.samplesPerCycle, ...
                result.Fs, ...
                result.Ttotal, ...
                result.f0, ...
                result.dcRMS, ...
                result.fundamentalRMS, ...
                result.totalRMS, ...
                result.peakValue, ...
                result.THD_percent, ...
                'VariableNames', { ...
                    'File', ...
                    'Samples', ...
                    'Cycles', ...
                    'SamplesPerCycle', ...
                    'SamplingFrequency_Hz', ...
                    'WindowLength_s', ...
                    'FundamentalFrequency_Hz', ...
                    'DC_RMS', ...
                    'Fundamental_RMS', ...
                    'Total_RMS', ...
                    'Peak', ...
                    'THD_percent'});

            writetable(summaryTable, outFile, 'Sheet', 'Summary');

            writetable(result.reportTable, outFile, 'Sheet', 'Harmonics');

            spectrumTable = table( ...
                result.frequency, ...
                result.rmsSpectrum, ...
                'VariableNames', {'Frequency_Hz', 'RMS'});

            writetable(spectrumTable, outFile, 'Sheet', 'FFT_Spectrum');

            % Analysed (integer-cycle, resampled) signal
            signalTable = table( ...
                result.time, ...
                result.signal, ...
                'VariableNames', {'time', 'signal_value'});

            writetable(signalTable, outFile, 'Sheet', 'Analysed_Data');

            statusLabel.Text = ['Report exported: ' outFile];

        catch ME
            uialert(fig, ME.message, 'Export error');
        end
    end

    function name = getFileName(fullname)
        [~, nameOnly, ext] = fileparts(fullname);
        name = [nameOnly ext];
    end
end

% ======================= Local helper functions =======================

function v = toNumericColumn(c)
% Convert a table column to a numeric column vector. Text columns (e.g. a
% CSV that uses a decimal comma) are converted with str2double.
    if iscell(c) || isstring(c) || ischar(c)
        c = string(c);
        v = str2double(strrep(c, ',', '.'));
    else
        v = double(c);
    end
    v = v(:);
end
