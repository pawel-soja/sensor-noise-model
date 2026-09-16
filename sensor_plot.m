function sensor_plot(analysis)
    p = analysis;

    # Debug - Input data
    if true
        figure(1, 'name', 'Debug - Input data'); clf;

        subplot(221);
        plot_fit(p.shutter, p.average, p.shutter2average);
        xlabel('Shutter [s]');
        ylabel('Average - Bias [DN]');
        legend(num2str(round(p.iso')));

        subplot(222);
        plot(p.shutter, p.sigma, '-+');
        xlabel('Shutter [s]');
        ylabel('Sigma [DN]');
        legend(num2str(round(p.iso')));

        subplot(212);
        plot_fit(p.average, p.sigma2, p.average2sigma2);
        xlabel('Average - Bias [DN]');
        ylabel('Sigma^2 [DN^2]');
        legend(num2str(round(p.iso')));
    end

    figure(2, 'name', 'Sensor model'); clf;
    subplot(321);
    [ax h1 h2] = plotyy(p.iso, p.egain, p.iso, p.read_noise);
    set ([h1, h2], "linestyle", "-");
    set ([h1, h2], "marker", "+");
    ylabel(ax(1), 'Egain [DN/e-]');
    ylabel(ax(2), 'Read Noise [DN]');
    xlabel('ISO');
    title(sprintf("f(x) = %g * x + %g", p.iso2egain(1), p.iso2egain(2)));
    grid on;
    hold on;

    subplot(322);
    [ax h1 h2] = plotyy(p.iso, 1 ./ p.egain, p.iso, p.read_noise ./ p.egain);
    set ([h1, h2], "linestyle", "-");
    set ([h1, h2], "marker", "+");
    ylabel(ax(1), 'Egain [e-/DN]');
    ylabel(ax(2), 'Read Noise [e-]');
    xlabel('ISO');
    grid on;

    subplot(312);
    [ax, h1, h2] = plotyy(p.egain, p.read_noise, p.egain, p.read_noise ./ p.egain);
    xlabel('Egain [DN / e-]');
    ylabel(ax(1), 'Read Noise [DN]');
    ylabel(ax(2), 'Read Noise [e-]');
    set ([h1, h2], "linestyle", "-");
    set ([h1, h2], "marker", "+");
    title(sprintf('f(x) = %gx + %g', p.egain2read_noise(1), p.egain2read_noise(2)));
    grid on;

    subplot(325);
    plot(p.shutter, p.average ./ p.egain', '-+');
    legend(num2str(round(p.iso')));

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
end

function plot_fit(x, y, coeff)
    plot(x, y, '+');
    hold on;
    set(gca,'ColorOrderIndex',1);
    plot(x, x .* coeff(1, :) + coeff(2, :));
    hold off;
end
