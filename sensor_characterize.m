function analysis = sensor_characterize(name = 'ASI2600MM_5deg', min_setting = [])
    % min_setting: lowest ISO/gain to analyse ([] = automatic, see sensor_fit)
    analysis = load_stats(name, min_setting);

    sensor_plot(analysis);
    sensor_print_model(analysis);
end

function out = load_stats(name, min_setting)
    % CSV columns: ISO; shutter [s]; average [DN]; sigma [DN]
    data = dlmread(fullfile('stats', [name '_dark.csv']), ';');

    out = sensor_fit(data, min_setting);
    out.name = name;
end
