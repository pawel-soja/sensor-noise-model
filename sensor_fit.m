function out = sensor_fit(data, min_setting = [])
    % data:        [ISO shutter average sigma] rows from stats/<camera>.csv
    % min_setting: lowest ISO/gain to analyse. Default: chosen automatically - the lowest
    %              setting from which the photon-transfer slope is significant for every
    %              higher setting (slope / its standard error >= T_MIN). Low settings have too
    %              little dark signal for a usable slope and are not used in astrophotography
    %              anyway. Pass a value to override, 0 to keep everything.
    T_MIN = 10;   % slope significance threshold, ~ correlation > 0.95 on 5+ points

    IDX_ISO     = 1;
    IDX_SHUTTER = 2;
    IDX_AVERAGE = 3;
    IDX_SIGMA   = 4;

    ISO = unique(data(:, IDX_ISO))';

    % significance of the photon-transfer slope for every setting
    tstat = arrayfun(@(iso) slope_tstat(data(data(:, IDX_ISO) == iso, :)), ISO);

    if isempty(min_setting)
        bad = find(tstat < T_MIN, 1, 'last');
        if isempty(bad)
            min_setting = ISO(1);
        elseif bad == numel(ISO)
            error('sensor_fit: photon-transfer slope not significant at any setting (max t = %.1f)', max(tstat));
        else
            min_setting = ISO(bad + 1);
        end
    end
    out = {};
    out.min_setting = min_setting;
    out.excluded    = ISO(ISO < min_setting);
    out.tstat_all   = tstat;
    ISO = ISO(ISO >= min_setting);
    if ~isempty(out.excluded)
        printf('sensor_fit: excluded settings below %g (slope not significant): %s\n', min_setting, mat2str(out.excluded));
    end

    COLS = length(ISO);
    ROWS = max(arrayfun(@(iso) sum(data(:, IDX_ISO) == iso), ISO));

    % ISO settings may have a different number of exposures; missing entries are NaN
    out.shutter = nan(ROWS, COLS);
    out.average = nan(ROWS, COLS);
    out.sigma   = nan(ROWS, COLS);

    for n = 1:COLS
        iso = ISO(n);
        idx = data(:, IDX_ISO) == iso;
        k = sum(idx);

        out.shutter(1:k, n) = data(idx, IDX_SHUTTER);
        out.average(1:k, n) = data(idx, IDX_AVERAGE);
        out.sigma(1:k, n)   = data(idx, IDX_SIGMA);
    end

    pf = polyfit_cols(out.shutter, out.average, 1);

    out.bias = (pf(2, :));       % DN
    out.average -= out.bias;     % DN
    out.sigma2 = out.sigma .^ 2; % DN^2

    out.shutter2average = polyfit_cols(out.shutter, out.average, 1);
    out.average2sigma2  = polyfit_cols(out.average, out.sigma2, 1);

    out.dark_rate = out.shutter2average(1, :)';   % DN/s, = dark_current * cgain

    % Photon transfer: slope = cgain, intercept = read noise^2
    out.cgain       = out.average2sigma2(1, :)'; % DN / e-
    out.read_noise2 = out.average2sigma2(2, :)'; % DN^2
    out.read_noise  = sqrt(out.read_noise2);     % DN

    out.cgain2read_noise = polyfit_cols(out.cgain, out.read_noise, 1);

    # Like DSLR - ISO
    as_linear = {};
    as_linear.x = ISO;

    # Like Astrocam - Gain (0.1 dB)
    as_log = {};
    as_log.x = 10 .^ (ISO / 200) * 100;

    # select model on x normalised to [0,1]: DSLR ISO as gain gives 10^32, singular fit
    [~, as_linear.s] = polyfit(as_linear.x / max(as_linear.x), out.cgain, 1);
    [~, as_log.s]    = polyfit(as_log.x / max(as_log.x), out.cgain, 1);

    if as_linear.s.normr < as_log.s.normr
        out.iso = as_linear.x;
        out.has_iso = true;
    else
        out.iso = as_log.x;
        out.has_iso = false;
    end
    out.setting = ISO;   % value as set on the camera (ISO or gain), for labels
    out.iso2cgain = polyfit(out.iso, out.cgain, 1);

    out.cgain2iso   = polyfit_cols(out.cgain, out.iso', 1);

    out.dark_current = mean(out.dark_rate ./ out.cgain); % e-/s/pix
end

function out = polyfit_cols(x, y, n)
    N = size(x)(2);
    out = zeros(2, N);
    for i=1:N
        ok = ~isnan(x(:, i)) & ~isnan(y(:, i));
        c = polyfit(x(ok, i), y(ok, i), n);
        out(:, i) = c;
    end
end

% slope / standard error of the sigma^2(average) fit for one setting's rows
function t = slope_tstat(rows)
    x = rows(:, 3) - polyfit(rows(:, 2), rows(:, 3), 1)(2);   % average - bias
    y = rows(:, 4) .^ 2;
    n = numel(x);
    if n < 3
        t = 0;
        return;
    end
    p = polyfit(x, y, 1);
    res = y - polyval(p, x);
    se = sqrt(sum(res .^ 2) / (n - 2) / sum((x - mean(x)) .^ 2));
    t = p(1) / se;
end
