function counts2mag()

    #value =
    target = 'Deneb';
    exposure = 0.01;
    egain = 10.7;
    bias = 100;
    resolution = 1.7;
    value = 2000;

    #photons = (value - bias) / resolution / egain / exposure; # photons / arcsec^2 / s
    # 858 mean values at 10x10 pixels, 0.01 s exposure
    photons = (858.5 - bias) / egain * 10^2 / (pi * (0.081/2) ^ 2) / 0.01; # photons/m2/s
    photons
    lambda = 650e-9;

    h = 6.626e-34; # Planck const.
    c = 2.998e8;   # light speed
    Ep = h * c / lambda; # J


    #flux = photons * ((60 * 60 * 180) .^ 2 ./ pi .^ 2) ...
    flux = photons * Ep;
    #* Ep / pi; # W/m^2

    flux_U = 4.35e-11; # Ultraviolet
    flux_B = 7.20e-11; # Blue
    flux_V = 3.64e-11; # Visual
    flux_R = 1.74e-11; # Red
    flux_I = 8.32e-12; # Infrared

    -2.5 * log10(flux / flux_R)
    return;
    distance_parsecs = 10;
    flux = cd / (4 * pi * (distance_parsecs * 3.086e16) .^ 2)
    return;

    flux_vega = 2.518e-8; # W/m2
    magnitude = -2.5 * log10(flux ./ flux_vega)
    #arcsec2_to_sr(1)

    #Energy = photons *

    #I = 0; # cd

end
