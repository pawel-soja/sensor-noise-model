function sensor_plot_iso_limit(analysis, iso_limit)
    % Egain and read noise vs ISO with the range above iso_limit highlighted,
    % where the sensor's analog gain stops changing (higher ISO = digital scaling only).
    % Saves plots/<name>_iso_limit.png
    p = analysis;
    iso   = p.iso(:);
    egain = p.egain(:);
    rn_dn = p.read_noise(:);
    rn_e  = rn_dn ./ egain;

    figure(3, 'name', [p.name ' - analog gain limit']); clf;
    xl = [min(iso) max(iso)] .* [0.9 1.1];

    subplot(211);
    shade_above(iso_limit, iso, egain);
    semilogx(iso, egain, '-+');
    set(gca, 'xlim', xl);
    xlabel('ISO');
    ylabel('Egain [DN/e-]');
    title(sprintf('%s: egain vs ISO', p.name), 'interpreter', 'none');
    grid on;
    hold off;

    % Annotation in the empty upper-left part of the egain plot
    idx = iso >= iso_limit;
    msg = sprintf(['Above ISO %d egain (%.1f DN/e-) and read noise (%.1f DN = %.1f e-) stay flat:\n' ...
                   'analog gain stops here, higher ISO is digital scaling only.\n' ...
                   'No SNR benefit - only highlight headroom and bit depth are lost.'], ...
                  iso_limit, mean(egain(idx)), mean(rn_dn(idx)), mean(rn_e(idx)));
    text(xl(1) * 1.05, max(egain) * 1.10, msg, 'fontsize', 10, 'verticalalignment', 'top', ...
         'backgroundcolor', [1 1 0.85], 'edgecolor', [0.6 0.6 0.6]);

    subplot(212);
    shade_above(iso_limit, iso, rn_dn);
    [ax, h1, h2] = plotyy(iso, rn_dn, iso, rn_e, @semilogx, @semilogx);
    set([h1, h2], 'linestyle', '-', 'marker', '+');
    set(ax, 'xlim', xl);
    xlabel('ISO');
    ylabel(ax(1), 'Read Noise [DN]');
    ylabel(ax(2), 'Read Noise [e-]');
    title('Read noise vs ISO');
    grid on;
    hold off;

    [~, ~] = mkdir('plots');
    file = fullfile('plots', [p.name '_iso_limit.png']);
    print(3, file, '-dpng', '-S1400,900');
    printf('saved %s\n', file);
end

function shade_above(iso_limit, iso, y)
    ymax = max(y) * 1.15;
    ymin = min(0, min(y));
    xmax = max(iso) * 1.1;
    patch([iso_limit xmax xmax iso_limit], [ymin ymin ymax ymax], [1 0.88 0.88], 'edgecolor', 'none');
    hold on;
    line([iso_limit iso_limit], [ymin ymax], 'color', [0.8 0 0], 'linestyle', '--');
    text(iso_limit, ymin + 0.03 * (ymax - ymin), sprintf(' ISO %d', iso_limit), 'color', [0.8 0 0], 'verticalalignment', 'bottom', 'fontsize', 11);
    set(gca, 'xscale', 'log', 'ylim', [ymin ymax]);
end
