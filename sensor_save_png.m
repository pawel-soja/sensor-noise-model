function sensor_save_png(fig, name)
    % Save figure to plots/<name>.png at its on-screen pixel size. print() defaults to
    % 150 dpi while the screen is ~96 dpi, which would render fonts ~1.6x larger than
    % shown; matching the screen dpi makes the file look like the window.
    [~, ~] = mkdir('plots');
    file = fullfile('plots', [name '.png']);
    pos = get(fig, 'position');
    dpi = get(0, 'screenpixelsperinch');
    % -S would override -r, so set the paper size in inches and print at screen dpi
    set(fig, 'paperunits', 'inches', 'paperposition', [0 0 pos(3:4) / dpi]);
    print(fig, file, '-dpng', sprintf('-r%d', round(dpi)));
    printf('saved %s\n', file);
end
