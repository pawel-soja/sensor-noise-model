function out = sensor_fit(data, anchor = [])
    % data:   [ISO shutter average sigma] rows from stats/<camera>.csv
    % anchor: optional struct('iso', <setting>, 'egain', <DN/e->). When given, egain is taken
    %         from the dark signal rate (DN/s scales with egain, dark current in e-/s does not)
    %         scaled to the anchor, instead of from the photon-transfer slope. Use it for
    %         cameras whose darks carry too little signal for photon transfer (cooled / low
    %         dark current sensors); the anchor ISO should be one where the dark rate is
    %         well measured.
    IDX_ISO     = 1;
    IDX_SHUTTER = 2;
    IDX_AVERAGE = 3;
    IDX_SIGMA   = 4;

    ISO = unique(data(:, IDX_ISO))';
    #ISO = ISO(find(ISO < 1600));
    #ISO = ISO(1:3:end);
    #ISO = ISO(find(ISO > 500));
    #ISO = ISO(1:4);
    COLS = length(ISO);
    ROWS = max(arrayfun(@(iso) sum(data(:, IDX_ISO) == iso), ISO));

    % ISO settings may have a different number of exposures; missing entries are NaN
    out = {};
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

    out.dark_rate = out.shutter2average(1, :)';   % DN/s, = dark_current * egain

    % Photon transfer: slope = egain, intercept = read noise^2
    out.egain_pt    = out.average2sigma2(1, :)'; % DN / e-
    out.read_noise2 = out.average2sigma2(2, :)'; % DN^2

    if isempty(anchor)
        out.egain = out.egain_pt;
        out.egain_source = 'photon transfer';
        out.egain_rel = out.dark_rate / out.dark_rate(end);
    else
        k = find(ISO == anchor.iso);
        if isempty(k)
            error('sensor_fit: anchor ISO %g not in data', anchor.iso);
        end
        out.egain_rel = out.dark_rate / out.dark_rate(k);
        out.egain = out.egain_rel * anchor.egain;
        out.egain_source = sprintf('dark rate, anchored at %g = %g DN/e-', anchor.iso, anchor.egain);
        % with egain fixed, read noise^2 is the mean offset of sigma^2 above the Poisson term
        for i = 1:COLS
            ok = ~isnan(out.average(:, i));
            out.read_noise2(i) = mean(out.sigma2(ok, i) - out.egain(i) * out.average(ok, i));
        end
    end
    out.anchor = anchor;
    out.read_noise = sqrt(out.read_noise2);      % DN

    out.egain2read_noise = polyfit_cols(out.egain, out.read_noise, 1);

    # Like DSLR - ISO
    as_linear = {};
    as_linear.x = ISO;

    # Like Astrocam - Gain (0.1 dB)
    as_log = {};
    as_log.x = 10 .^ (ISO / 200) * 100;

    # select model on x normalised to [0,1]: DSLR ISO as gain gives 10^32, singular fit
    [~, as_linear.s] = polyfit(as_linear.x / max(as_linear.x), out.egain, 1);
    [~, as_log.s]    = polyfit(as_log.x / max(as_log.x), out.egain, 1);

    if as_linear.s.normr < as_log.s.normr
        out.iso = as_linear.x;
        out.has_iso = true;
    else
        out.iso = as_log.x;
        out.has_iso = false;
    end
    out.setting = ISO;   % value as set on the camera (ISO or gain), for labels
    out.iso2egain = polyfit(out.iso, out.egain, 1);

    out.egain2iso   = polyfit_cols(out.egain, out.iso', 1);

    out.dark_current = mean(out.dark_rate ./ out.egain); % e-/s/pix
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
