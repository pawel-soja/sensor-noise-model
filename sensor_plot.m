function sensor_plot(analysis)
    p = analysis;
    has_flat = isfield(p, 'flat');

    plot_input(1, p, 'Dark');
    if has_flat
        p.flat.name = p.name;
        plot_input(3, p.flat, 'Flat');
    end

    sensor_figure(2, [p.name ' - Sensor model']);
    colormap(iso_colormap());
    [xs, xname] = setting_axis(p);
    if has_flat
        src = ' (from flats)';
    else
        src = '';
    end

    subplot(321);
    % x = ISO equivalent so the cgain fit is a straight line; ticks relabelled with gain for astro cameras
    [ax h1 h2] = plotyy(p.iso, p.cgain, p.iso, p.read_noise);
    set ([h1, h2], "linestyle", "-");
    set ([h1, h2], "marker", "+");
    ylabel(ax(1), ['Conversion gain [DN/e-]' src]);
    ylabel(ax(2), 'Read Noise [DN]');
    if p.has_iso
        xlabel('ISO');
        title(sprintf("Conversion gain vs ISO: f(x) = %g * x + %g", p.iso2cgain(1), p.iso2cgain(2)));
    else
        label_gain_ticks(ax, p);
        xlabel('Gain [0.1 dB]  (linear in 100*10^{gain/200})');
        title(sprintf("Conversion gain vs gain: f(g) = %g * 100*10^{g/200} + %g", p.iso2cgain(1), p.iso2cgain(2)));
    end
    grid on;
    hold on;

    subplot(322);
    [ax h1 h2] = plotyy(p.iso, 1 ./ p.cgain, p.iso, p.read_noise ./ p.cgain);
    set ([h1, h2], "linestyle", "-");
    set ([h1, h2], "marker", "+");
    ylabel(ax(1), 'Gain 1/cgain [e-/DN]');
    ylabel(ax(2), 'Read Noise [e-]');
    if p.has_iso
        xlabel('ISO');
    else
        label_gain_ticks(ax, p);
        xlabel('Gain [0.1 dB]  (linear in 100*10^{gain/200})');
    end
    title('Gain and read noise in electrons');
    grid on;

    subplot(312);
    [ax, h1, h2] = plotyy(p.cgain, p.read_noise, p.cgain, p.read_noise ./ p.cgain);
    xlabel('Conversion gain [DN/e-]');
    ylabel(ax(1), 'Read Noise [DN]');
    ylabel(ax(2), 'Read Noise [e-]');
    set ([h1, h2], "linestyle", "-");
    set ([h1, h2], "marker", "+");
    title(sprintf('Read noise vs cgain: f(x) = %gx + %g', p.cgain2read_noise(1), p.cgain2read_noise(2)));
    grid on;

    subplot(325);
    if has_flat
        % dark_current comes from the variance growth, so show that estimate (clamp-proof)
        plot_iso(p.shutter, (p.sigma2 - p.read_noise2') ./ p.cgain' .^ 2, p);
        ylabel('(Sigma^2 - RN^2) / cgain^2 [e-]');
        title(sprintf('Dark current from variance growth: %.3g e-/s/pix', p.dark_current));
    else
        plot_iso(p.shutter, p.average ./ p.cgain', p);
        ylabel('Dark signal [e-]');
        title(sprintf('Dark current: %.3g e-/s/pix', p.dark_current));
    end
    xlabel('Shutter [s]');

    subplot(326);

    % Simulated single frame: signal and variance in DN for a given cgain [DN/e-]
    U = @(camera, cgain, exposure, photons) ...
          cgain .* exposure .* photons;

    V = @(camera, cgain, exposure, photons) ...
          cgain .^ 2 .* exposure .* (photons + camera.dark_current) + ...
          (camera.cgain2read_noise(1) .* cgain + camera.cgain2read_noise(2)) .^ 2;

    exposures = [10 15];  # s
    photons   = 0.3;          # e-/s/pix, faint target / narrowband

    x = p.cgain(:);   # measured DN/e- per ISO/gain (linear iso2cgain fit is poor when gain saturates)

    hold on;
    for e = exposures
        SNR = U(p, x, e, photons) ./ sqrt(V(p, x, e, photons));
        plot(xs, 20 * log10(SNR), '-+');
    end
    hold off;
    legend(arrayfun(@(e) sprintf('%g s', e), exposures, 'uniformoutput', false), 'location', 'east');
    xlabel(xname);
    ylabel('SNR [dB]');
    title(sprintf('SNR of a single frame, %g e-/s', photons));
    grid on;

    sensor_save_png(1, [p.name '_input']);
    sensor_save_png(2, [p.name '_model']);
    if has_flat
        sensor_save_png(3, [p.name '_flat_input']);
    end
end

# Input data with fits: signal and noise vs exposure, photon transfer. kind = 'Dark' | 'Flat'
# Flats span decades in signal (EV steps) and cgain, so they get log-log axes.
function plot_input(fig, p, kind)
    sensor_figure(fig, sprintf('%s - %s input data', p.name, kind));
    colormap(iso_colormap());
    if strcmp(kind, 'Flat')
        scale = 'log';
    else
        scale = 'linear';
    end

    subplot(221);
    plot_iso(p.shutter, p.average, p, p.shutter2average);
    set(gca, 'xscale', scale, 'yscale', scale);
    xlabel('Shutter [s]');
    ylabel('Average - Bias [DN]');
    title(sprintf('%s signal vs exposure (linear fit)', kind));

    subplot(222);
    plot_iso(p.shutter, p.sigma, p);
    set(gca, 'xscale', scale, 'yscale', scale);
    xlabel('Shutter [s]');
    ylabel('Sigma [DN]');
    title('Noise vs exposure');

    subplot(212);
    plot_iso(p.average, p.sigma2, p, p.average2sigma2);
    set(gca, 'xscale', scale, 'yscale', scale);
    xlabel('Average - Bias [DN]');
    ylabel('Sigma^2 [DN^2]');
    if isempty(p.excluded)
        title('Photon transfer: slope = cgain [DN/e-], intercept = read noise^2');
    else
        title(sprintf('Photon transfer: slope = cgain [DN/e-], intercept = read noise^2  (settings < %g excluded: slope not significant)', p.min_setting));
    end
end

function cmap = iso_colormap()
    cmap = jet(64);
end

# X axis in the camera's own units: ISO for DSLR, gain [0.1 dB] for astro cameras
function [x, name] = setting_axis(p)
    x = p.setting(:);
    if p.has_iso
        name = 'ISO';
    else
        name = 'Gain [0.1 dB]';
    end
end

# Axes plotted against p.iso: put ~6 ticks at real gain settings, labelled with the gain value
function label_gain_ticks(ax, p)
    iso = p.iso(:)';
    [~, k] = min(abs(iso' - linspace(min(iso), max(iso), 6)), [], 1);
    k = unique(k);
    set(ax, 'xtick', iso(k), 'xticklabel', num2str(p.setting(k)'));
end

# One line per ISO/gain setting coloured from blue (lowest) to red (highest), colorbar instead of legend.
# DSLR ISO is spread on a log scale, astro-camera gain (0.1 dB) is already logarithmic.
# With coeff: '+' data plus fitted line, otherwise '-+'.
function plot_iso(x, y, p, coeff)
    cmap = iso_colormap();
    setting = p.setting(:)';
    if p.has_iso
        v = log10(setting);
        name = 'ISO';
    else
        v = setting;
        name = 'Gain';
    end
    clim = [min(v) max(v)];
    if diff(clim) == 0
        clim += [-0.5 0.5];
    end
    idx = 1 + round((v - clim(1)) / diff(clim) * (rows(cmap) - 1));

    hold on;
    for i = 1:numel(setting)
        c = cmap(idx(i), :);
        if nargin < 4
            plot(x(:, i), y(:, i), '-+', 'color', c);
        else
            plot(x(:, i), y(:, i), '+', 'color', c);
            plot(x(:, i), x(:, i) .* coeff(1, i) + coeff(2, i), '-', 'color', c);
        end
    end
    hold off;
    grid on;

    # ~6 ticks evenly spread along the bar, snapped to real settings
    [~, k] = min(abs(v' - linspace(clim(1), clim(2), 6)), [], 1);
    k = unique(k);
    caxis(clim);
    cb = colorbar();
    set(cb, 'ytick', v(k), 'yticklabel', num2str(setting(k)'));
    title(cb, name, 'fontsize', 11);
end
