function sensor_plot_sub_length(cameras, skies = [0.03 0.3], t = logspace(log10(1), log10(60), 61), penalty = 0.1)
    % Total integration time needed for a given SNR as a function of sub-exposure length.
    % All curves are relative to an ideal noiseless camera (no dark current, no read noise),
    % so the plot shows both the read-noise penalty of short subs and the dark-current cost:
    %
    %   T_i(t) / T_ideal = (sky + D_i + RN_i^2 / t) / sky
    %
    % One panel per sky flux, one line per camera (setting chosen as in sensor_compare:
    % lowest read noise in e-, or forced with {name, setting}). Dashed lines are each camera's
    % own limit for long subs (dark current only), markers show t_min – the sub length where
    % read noise^2 is `penalty` of the sky + dark variance, i.e. the total time is
    % (1 + penalty) x own limit. Same optics and QE assumed.
    % Saves plots/sub_length.png
    %
    %   cameras: cellstr of model names, or cells {name, setting}
    %   skies:   sky + target flux values [e-/s/pix], one subplot each
    %   t:       sub-exposure lengths [s] for the x axis
    %   penalty: accepted read-noise share of the variance for t_min (0.1 = 10 % more time)
    %
    % Example: sensor_plot_sub_length({'ASI2600MM_5deg', {'Nikon_D5100', 1600}}, [0.03 0.3])

    sensor_figure(4, 'Integration time vs sub length');
    n = numel(skies);

    for i = 1:n
        sky = skies(i);
        cams = sensor_compare(cameras, sky, t(end), penalty);

        subplot(n, 1, i);
        hold on;
        hs = [];
        labels = {};
        for r = cams
            base = (sky + r.dark_current) / sky;
            rel  = @(t) base + r.read_noise ^ 2 ./ (t * sky);
            h = plot(t, rel(t), '-', 'linewidth', 2);
            c = get(h, 'color');
            plot(t([1 end]), [base base], '--', 'color', c);
            plot(r.t_min, rel(r.t_min), 'o', 'color', c, 'markersize', 8, 'linewidth', 1.5);
            hs(end + 1) = h;
            labels{end + 1} = sprintf('%s @ %g: RN %.2f e-, D %.4f e-/s, long subs %.1fx, t_{min} %.0f s', ...
                                      strrep(r.name, '_', '\_'), r.setting, r.read_noise, r.dark_current, base, r.t_min);
        end
        hold off;
        xlim(t([1 end]));
        set(gca, 'yscale', 'log');
        yl = ylim();
        ylim([0.9 yl(2)]);
        yt = [1 2 3 5 10 20 50 100 200 500];
        yt = yt(yt <= yl(2));
        set(gca, 'ytick', yt, 'yticklabel', arrayfun(@(v) sprintf('%gx', v), yt, 'uniformoutput', false));
        grid on;
        xlabel('Sub exposure [s]');
        ylabel('Total integration time  T / T_{ideal}');
        title(sprintf('Sky + target %g e-/s/pix: total time for equal SNR vs sub length, T_{ideal} = noiseless camera (-- dark current only, o = t_{min}: +%g %% for read noise)', sky, penalty * 100));
        legend(hs, labels, 'location', 'northeast');
    end

    sensor_save_png(4, 'sub_length');
end
