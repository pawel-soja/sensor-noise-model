function analysis = sensor_characterize(name = 'ASI2600MM_5deg', min_setting = [])
    % min_setting: lowest ISO/gain to analyse ([] = automatic, see sensor_fit). With flats the
    %              automatic exclusion is off (0): cgain then comes from the flats and the dark
    %              photon-transfer slope no longer matters.
    dark_data = load_stats(name, 'dark');
    flat_file = stats_file(name, 'flat');

    if exist(flat_file, 'file')
        if isempty(min_setting)
            min_setting = 0;
        end
        dark = sensor_fit(dark_data, min_setting);
        flat = sensor_fit(load_stats(name, 'flat'), 0, [dark.setting' dark.bias']);
        analysis = sensor_merge(dark, flat);
    else
        analysis = sensor_fit(dark_data, min_setting);
    end
    analysis.name = name;

    sensor_plot(analysis);
    sensor_print_model(analysis);
end

function file = stats_file(name, type)
    file = fullfile('stats', [name '_' type '.csv']);
end

function data = load_stats(name, type)
    % CSV columns: ISO; shutter [s]; average [DN]; sigma [DN]
    data = dlmread(stats_file(name, type), ';');
end
