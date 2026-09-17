function camera = sensor_models(name)
    % Returns a fitted sensor model by name (output of sensor_print_model).
    switch name
        case "ASI2600MM_5deg"
            % settings below gain 150 excluded by sensor_fit: cooled darks carry too little
            % signal for a significant photon-transfer slope
            camera = {};
            camera.name = "ASI2600MM_5deg";
            camera.egain2read_noise = @(egain) 0.692273 * egain + 1.70705; # DN
            camera.dark_current = 0.00174143; # e-/s/pix
            camera.bias = 99; # DN
            camera.egain = [ 14.2484 25.3508 43.54 66.4655 108.061 161.314 263.544 ]; # DN/e-, settings >= 150
            camera.read_noise = [ 9.45753 16.0455 26.9249 43.7335 72.052 115.553 186.437 ]; # DN, per setting
            camera.has_iso = 0; # if false, log10(iso / 100) * 200 = gain [0.1dB]
            camera.iso = [ 562.341 1000 1778.28 3162.28 5623.41 10000 17782.8 ];
            camera.iso2egain = @(iso) 0.01496 * iso + 7.63132; # DN/e-

        case "Nikon_D5100"
            camera = {};
            camera.name = "Nikon_D5100";
            camera.egain2read_noise = @(egain) 1.94863 * egain + 0.69789; # DN
            camera.dark_current = 0.401177; # e-/s/pix
            camera.bias = 129; # DN
            camera.egain = [ 0.391267 0.434638 0.553248 0.69269 0.874804 1.11363 1.43024 1.77036 2.2299 3.27807 3.65635 4.63258 5.90305 5.88421 5.85468 5.91954 5.84929 5.92751 5.91549 ];
            camera.read_noise = [ 1.27644 1.38101 1.65053 1.94531 2.4179 2.91895 3.51555 4.33075 5.31091 7.255 7.91497 9.92268 12.0434 12.2229 12.2631 12.0972 12.0196 12.0571 12.1388 ]; # DN, per setting
            camera.has_iso = 1; # if false, log10(iso / 100) * 200 = gain [0.1dB]
            camera.iso = [ 100 125 160 200 250 320 400 500 640 800 1000 1250 1600 2000 2500 3200 4000 5000 6400 ];
            camera.iso2egain = @(iso) 0.0010196 * iso + 1.64578; # DN/e-

        otherwise
            error("sensor_models: unknown sensor '%s'", name);
    end
end
