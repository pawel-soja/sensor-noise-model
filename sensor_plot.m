function sensor_plot(analysis)
    p = analysis;

    # Debug - Input data
    if true
        figure(1, 'name', [p.name ' - Debug - Input data']); clf;
        colormap(iso_colormap());

        subplot(221);
        plot_iso(p.shutter, p.average, p, p.shutter2average);
        xlabel('Shutter [s]');
        ylabel('Average - Bias [DN]');
        title('Dark signal vs exposure (linear fit)');

        subplot(222);
        plot_iso(p.shutter, p.sigma, p);
        xlabel('Shutter [s]');
        ylabel('Sigma [DN]');
        title('Noise vs exposure');

        subplot(212);
        plot_iso(p.average, p.sigma2, p, p.average2sigma2);
        xlabel('Average - Bias [DN]');
        ylabel('Sigma^2 [DN^2]');
        title('Photon transfer: slope = egain [DN/e-], intercept = read noise^2');
    end

    figure(2, 'name', [p.name ' - Sensor model']); clf;
    colormap(iso_colormap());
    subplot(321);
    [ax h1 h2] = plotyy(p.iso, p.egain, p.iso, p.read_noise);
    set ([h1, h2], "linestyle", "-");
    set ([h1, h2], "marker", "+");
    ylabel(ax(1), 'Egain [DN/e-]');
    ylabel(ax(2), 'Read Noise [DN]');
    xlabel('ISO');
    title(sprintf("Egain vs ISO: f(x) = %g * x + %g", p.iso2egain(1), p.iso2egain(2)));
    grid on;
    hold on;

    subplot(322);
    [ax h1 h2] = plotyy(p.iso, 1 ./ p.egain, p.iso, p.read_noise ./ p.egain);
    set ([h1, h2], "linestyle", "-");
    set ([h1, h2], "marker", "+");
    ylabel(ax(1), 'Egain [e-/DN]');
    ylabel(ax(2), 'Read Noise [e-]');
    xlabel('ISO');
    title('Gain and read noise in electrons');
    grid on;

    subplot(312);
    [ax, h1, h2] = plotyy(p.egain, p.read_noise, p.egain, p.read_noise ./ p.egain);
    xlabel('Egain [DN / e-]');
    ylabel(ax(1), 'Read Noise [DN]');
    ylabel(ax(2), 'Read Noise [e-]');
    set ([h1, h2], "linestyle", "-");
    set ([h1, h2], "marker", "+");
    title(sprintf('Read noise vs egain: f(x) = %gx + %g', p.egain2read_noise(1), p.egain2read_noise(2)));
    grid on;

    subplot(325);
    plot_iso(p.shutter, p.average ./ p.egain', p);
    xlabel('Shutter [s]');
    ylabel('Dark signal [e-]');
    title(sprintf('Dark current: %.3g e-/s/pix', p.dark_current));

    subplot(326);

    U = @(camera, egain, exposure, photons) ...
          egain .* exposure .* photons;

    V = @(camera, egain, exposure, photons) ...
          egain .^ 2 .* exposure .* (photons + camera.dark_current) + ...
          (camera.egain2read_noise(1) .* egain + camera.egain2read_noise(2)) .^ 2;

    exposure = 30; # s
    egain    = 0.1; # DN/e-
    photons  = 2; # e-/s

    egain = p.egain(2);
    iso = p.iso;
    x = p.iso2egain(1) .* iso + p.iso2egain(2);

    L = U(p, egain .* x, exposure ./ x, photons) .^ 2;
    M = V(p, egain .* x, exposure ./ x, photons) ./ (x);
    SNR = L ./ M;

    plot(iso, 10*log(SNR));
    xlabel('ISO');
    ylabel('SNR [dB]');
    title(sprintf('SNR vs ISO (%g s, %g e-/s)', exposure, photons));
    grid on;

    save_png(1, [p.name '_input']);
    save_png(2, [p.name '_model']);
end

function save_png(fig, name)
    [~, ~] = mkdir('plots');
    file = fullfile('plots', [name '.png']);
    print(fig, file, '-dpng', '-S1400,900');
    printf('saved %s\n', file);
end

function cmap = iso_colormap()
    cmap = jet(64);
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

    # ~6 ticks evenly spread along the bar, snapped to real settings
    [~, k] = min(abs(v' - linspace(clim(1), clim(2), 6)), [], 1);
    k = unique(k);
    caxis(clim);
    cb = colorbar();
    set(cb, 'ytick', v(k), 'yticklabel', num2str(setting(k)'));
    title(cb, name, 'fontsize', 11);
end
