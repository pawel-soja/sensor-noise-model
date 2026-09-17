function analysis = sensor_characterize(name = 'ASI2600MM_5deg', anchor = sensor_anchor(name))
    % anchor: [] for photon-transfer egain, or struct('iso', ..., 'egain', ...) - see sensor_fit
    analysis = load_stats(name, anchor);

    sensor_plot(analysis);
    sensor_print_model(analysis);
end

function out = load_stats(name, anchor)
    % CSV columns: ISO; shutter [s]; average [DN]; sigma [DN]
    data = dlmread(fullfile('stats', [name '.csv']), ';');

    out = sensor_fit(data, anchor);
    out.name = name;
end
