function snr_vs_iso(name = "Nikon-D5100")
    pkg load statistics

    camera = sensor_models(name);

    exposure = 200; # s
    egain    = 0.1; # DN/e-
    photons  = 20; # e-/s

    #camera.dark_current = 0;
    #camera.egain2read_noise = @(x) 0;

    U = @(camera, egain, exposure, photons) ...
          egain .* exposure .* photons;

    V = @(camera, egain, exposure, photons) ...
          egain .^ 2 .* exposure .* (photons + camera.dark_current) + ...
          camera.egain2read_noise(egain) .^ 2;


    egain = camera.iso2egain(1000);
    #x = 1:100;
    iso = camera.iso;
    x = camera.iso2egain(iso);

    figure(1);
    subplot(111);
    L = U(camera, egain .* x, exposure ./ x, photons) .^ 2;
    M = V(camera, egain .* x, exposure ./ x, photons) .* 1 ./ (x);
    SNR = L ./ M;

    plot(iso, 10*log(SNR));
    return

    total = 60;
    EXPOSURE = [];
    SIGNAL = [];
    NOISE = [];
    for n=1:10
        exposure = total / n;
        egain = 1 + (n - 1) * 1.0;

        sum_signal = 0;
        sum_sigma2 = 0;
        for i=1:n
            [~, signal, noise] = sensor_snr(camera, exposure, egain, photons);
            sum_signal += signal;
            sum_sigma2 += noise .^ 2;
        end

        EXPOSURE = [EXPOSURE; exposure];
        SIGNAL = [SIGNAL; sum_signal / n];
        NOISE  = [NOISE; sqrt(sum_sigma2) / n];
    end
    x = EXPOSURE;
    subplot(211);
    plotyy(x, SIGNAL, x, NOISE);
    xlabel('Exposure [s]');
    legend('SIGNAL', 'NOISE');

    subplot(212);
    plot(SIGNAL, NOISE);
    xlabel('Signal');
    ylabel('Noise');
end

function [snr, signal, noise] = sensor_snr(camera, exposure, egain, photons)
    signal = egain .* exposure .* photons;
    # signal += egain .* exposure .* camera.dark_current
    sigma2 = egain .^ 2 .* exposure .* (photons + camera.dark_current) + ...
             camera.egain2read_noise(egain) .^ 2;
    noise = sqrt(sigma2);
    snr = 10 * log10((signal .^ 2) ./ (sqrt(noise) .^ 2));
end


function [signal, average, sigma] = simulate_exposure(camera, exposure, egain, photons)
    N = 1024 * 64;

    light         = egain * poissrnd(exposure * photons, N, 1);
    dark_current  = egain * poissrnd(exposure * camera.dark_current, N, 1);
    read_noise    = normrnd(0, camera.egain2read_noise(egain), N, 1);

    signal = light + dark_current - mean(dark_current) + read_noise;
    average = mean(signal);
    sigma = std(signal);
end

