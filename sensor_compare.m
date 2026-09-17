function out = sensor_compare(cameras, sky = 0.3, t = 60)
    % Integration-time comparison of camera models from sensor_models for one sky flux and
    % sub-exposure length, same optics and QE assumed.
    %
    %   cameras: cellstr of model names, or cells {name, setting} to force an ISO/gain
    %            (default: the setting with the lowest read noise in e-)
    %   sky:     sky + target flux [e-/s/pix]
    %   t:       sub-exposure length [s]
    %
    % Noise variance per second of integration: sky + dark + read_noise^2 / t.
    % The required total time for equal SNR scales with that variance; the table reports it
    % relative to the best camera. t_min is the sub length where read noise^2 is 10 % of the
    % sky + dark variance (longer subs gain nothing from lower read noise).
    %
    % Example: sensor_compare({'ASI2600MM_5deg', {'Nikon_D5100', 1600}}, 0.3, 60)

    out = struct('name', {}, 'setting', {}, 'egain', {}, 'read_noise', {}, 'dark_current', {}, ...
                 't_min', {}, 'var_per_s', {}, 'rel_time', {});

    for i = 1:numel(cameras)
        c = cameras{i};
        if iscell(c)
            camera = sensor_models(c{1});
            setting = c{2};
        else
            camera = sensor_models(c);
            setting = [];
        end

        settings = camera_settings(camera);
        rn_e = camera.egain2read_noise(camera.egain) ./ camera.egain;   % e-

        if isempty(setting)
            [~, k] = min(rn_e);
        else
            k = find(settings == setting, 1);
            if isempty(k)
                error('sensor_compare: %s has no setting %g (available: %s)', ...
                      camera.name, setting, mat2str(settings));
            end
        end

        r = struct();
        r.name         = camera.name;
        r.setting      = settings(k);
        r.egain        = camera.egain(k);
        r.read_noise   = rn_e(k);
        r.dark_current = camera.dark_current;
        r.t_min        = 10 * r.read_noise ^ 2 / (sky + r.dark_current);
        r.var_per_s    = sky + r.dark_current + r.read_noise ^ 2 / t;
        r.rel_time     = NaN;
        out(end + 1) = r;
    end

    best = min([out.var_per_s]);
    for i = 1:numel(out)
        out(i).rel_time = out(i).var_per_s / best;
    end

    printf('\nSky %g e-/s/pix, subs %g s  (same optics and QE assumed)\n\n', sky, t);
    printf('%-18s %8s %9s %8s %10s %8s %10s %9s\n', ...
           'camera', 'setting', 'egain', 'RN [e-]', 'D [e-/s]', 't_min', 'var/s', 'time');
    printf('%-18s %8s %9s %8s %10s %8s %10s %9s\n', ...
           '', '', '[DN/e-]', '', '', '[s]', '[e-^2/s]', 'vs best');
    for r = out
        printf('%-18s %8g %9.3f %8.2f %10.4f %8.1f %10.3f %8.2fx\n', ...
               r.name, r.setting, r.egain, r.read_noise, r.dark_current, r.t_min, r.var_per_s, r.rel_time);
    end
    printf('\n');
end

function s = camera_settings(camera)
    % ISO for DSLR, gain [0.1 dB] for astro cameras (camera.iso is the ISO equivalent)
    if camera.has_iso
        s = camera.iso;
    else
        s = round(log10(camera.iso / 100) * 200);
    end
end
