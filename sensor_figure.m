function fig = sensor_figure(n, name)
    % Figure of fixed size with fonts sized for that window. Fonts are in points, so the
    % window size decides how crowded the subplots look; sensor_save_png exports 1:1.
    fig = figure(n, 'name', name);
    clf(fig);
    set(fig, 'position', [50 50 1400 900]);
    set(fig, 'defaultaxesfontsize', 12, ...
             'defaulttextfontsize', 13, ...
             'defaultaxestitlefontsizemultiplier', 1.15, ...
             'defaultlinelinewidth', 1.1);
end
