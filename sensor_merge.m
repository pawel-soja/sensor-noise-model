function out = sensor_merge(dark, flat)
    % Combine a dark and a flat fit (both from sensor_fit) into one model on the dark's
    % ISO/gain grid:
    %   cgain        from the flat photon transfer (signal 100x larger than in darks, and
    %                unaffected by a black-level clamp that compresses the dark mean);
    %                settings without a flat are interpolated in log-log (cgain ~ ISO),
    %                outside the flat range the flat's iso2cgain fit is used
    %   read_noise   from the dark photon-transfer intercept (flats have RN^2 << signal
    %                variance, their intercept is poorly determined)
    %   dark_current from the dark variance growth: sigma2_rate / cgain^2 - the dark mean
    %                is not used, so a black-level clamp does not matter
    %   bias         from darks
    % The dark input arrays (shutter, average, ...) are kept for the plots; the flat fit is
    % attached as out.flat.
    out = dark;
    out.source = 'flat';
    out.flat   = flat;

    for n = 1:numel(dark.setting)
        k = find(flat.setting == dark.setting(n), 1);
        if ~isempty(k)
            out.cgain(n) = flat.cgain(k);
        else
            c = exp(interp1(log(flat.iso), log(flat.cgain), log(dark.iso(n))));
            if isnan(c)
                c = polyval(flat.iso2cgain, dark.iso(n));
            end
            out.cgain(n) = c;
            printf('sensor_merge: no flat at setting %g, cgain interpolated: %g\n', dark.setting(n), c);
        end
    end

    out.iso2cgain = flat.iso2cgain;
    out.cgain2iso = flat.cgain2iso;
    out.cgain2read_noise = polyfit(out.cgain, out.read_noise, 1);

    out.dark_current_per_setting = out.sigma2_rate ./ out.cgain .^ 2;   % e-/s/pix
    out.dark_current = mean(out.dark_current_per_setting);
end
