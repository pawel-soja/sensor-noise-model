function camera = sensor_models(name)
    % Returns a fitted sensor model by name (output of sensor_print_model).
    switch name
        case "ASI2600MM_5deg"
            % egain below gain ~150 is unreliable: cooled darks carry too little signal for
            % photon transfer (see README); read noise in DN is fine
            camera = {};
            camera.name = "ASI2600MM_5deg";
            camera.egain2read_noise = @(egain) 0.692273 * egain + 1.70705; # DN
            camera.dark_current = 0.00174143; # e-/s/pix
            camera.bias = 99; # DN
            camera.egain = [ 6.15376 4.64231 7.14755 6.46586 7.55838 9.30614 10.6594 8.69506 6.84118 14.2484 25.3508 43.54 66.4655 108.061 161.314 263.544 ];
            camera.has_iso = 0; # if false, log10(iso / 100) * 200 = gain [0.1dB]
            camera.iso = [ 100 133.352 177.828 237.137 251.189 266.073 281.838 298.538 316.228 562.341 1000 1778.28 3162.28 5623.41 10000 17782.8 ];
            camera.iso2egain = @(iso) 0.01496 * iso + 7.63132; # DN/e-

        case "Nikon_D5100"
            camera = {};
            camera.name = "Nikon_D5100";
            camera.egain2read_noise = @(egain) 1.94863 * egain + 0.69789; # DN
            camera.dark_current = 0.401177; # e-/s/pix
            camera.bias = 129; # DN
            camera.egain = [ 0.391267 0.434638 0.553248 0.69269 0.874804 1.11363 1.43024 1.77036 2.2299 3.27807 3.65635 4.63258 5.90305 5.88421 5.85468 5.91954 5.84929 5.92751 5.91549 ];
            camera.has_iso = 1; # if false, log10(iso / 100) * 200 = gain [0.1dB]
            camera.iso = [ 100 125 160 200 250 320 400 500 640 800 1000 1250 1600 2000 2500 3200 4000 5000 6400 ];
            camera.iso2egain = @(iso) 0.0010196 * iso + 1.64578; # DN/e-

        otherwise
            error("sensor_models: unknown sensor '%s'", name);
    end
end
