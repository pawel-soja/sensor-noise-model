function analysis = sensor_characterize(name = 'ASI2600MM_5deg')
    set(0, "defaulttextfontsize", 16)  % title
    set(0, "defaultaxesfontsize", 11)  % axes labels
    set(0, "defaultlinelinewidth", 1.1)

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
