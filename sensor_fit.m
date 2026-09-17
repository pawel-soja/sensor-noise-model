function out = sensor_fit(data)
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
    ROWS = length(find(data(:, IDX_ISO) == ISO(1)));

    out = {};
    out.shutter = zeros(ROWS, COLS);

    for n = 1:COLS
        iso = ISO(n);
        idx = data(:, IDX_ISO) == iso;

        out.shutter(:, n) = data(idx, IDX_SHUTTER);
        out.average(:, n) = data(idx, IDX_AVERAGE);
        out.sigma(:, n)   = data(idx, IDX_SIGMA);
    end

    pf = polyfit_cols(out.shutter, out.average, 1);

    out.bias = (pf(2, :));       % DN
    out.average -= out.bias;     % DN
    out.sigma2 = out.sigma .^ 2; % DN^2

    out.shutter2average = polyfit_cols(out.shutter, out.average, 1);
    out.average2sigma2  = polyfit_cols(out.average, out.sigma2, 1);

    out.egain       = out.average2sigma2(1, :)'; % DN / e-
    out.read_noise2 = out.average2sigma2(2, :)'; % DN^2
    out.read_noise  = sqrt(out.read_noise2);     % DN

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

    out.dark_current = mean(out.shutter2average(1, :) ./ out.egain'); % e-/s/pix
end

function out = polyfit_cols(x, y, n)
    N = size(x)(2);
    out = zeros(2, N);
    for i=1:N
        c = polyfit(x(:, i), y(:, i), n);
        out(:, i) = c;
    end
end
