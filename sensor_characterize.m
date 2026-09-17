function analysis = sensor_characterize(name = 'ASI2600MM_5deg')
    analysis = load_stats(name);

    sensor_plot(analysis);
    sensor_print_model(analysis);
end

function out = load_stats(name)
    % CSV columns: ISO; shutter [s]; average [DN]; sigma [DN]
    data = dlmread(fullfile('stats', [name '.csv']), ';');

    out = sensor_fit(data);
    out.name = name;
end
