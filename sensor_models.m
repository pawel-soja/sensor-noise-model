function camera = sensor_models(name)
    % Returns a fitted sensor model by name (output of sensor_print_model).
    switch name
        case "ASI2600MM_5deg"
            % settings below gain 150 excluded by sensor_fit: cooled darks carry too little
            % signal for a significant photon-transfer slope
            camera = {};
            camera.name = "ASI2600MM_5deg";
            camera.cgain2read_noise = @(cgain) 0.692273 * cgain + 1.70705; # DN
            camera.dark_current = 0.00174143; # e-/s/pix
            camera.bias = 99; # DN
            camera.cgain = [ 14.2484 25.3508 43.54 66.4655 108.061 161.314 263.544 ]; # DN/e-, settings >= 150
            camera.read_noise = [ 9.45753 16.0455 26.9249 43.7335 72.052 115.553 186.437 ]; # DN, per setting
            camera.has_iso = 0; # if false, log10(iso / 100) * 200 = gain [0.1dB]
            camera.iso = [ 562.341 1000 1778.28 3162.28 5623.41 10000 17782.8 ];
            camera.iso2cgain = @(iso) 0.01496 * iso + 7.63132; # DN/e-

        case "Nikon_D5100"
            camera = {};
            camera.name = "Nikon_D5100";
            % dark current is a session average: 0.15 e-/s cold, 0.75 after an hour of shooting
            # cgain from flats; read noise and dark current (variance growth) from darks
            camera.cgain2read_noise = @(cgain) 2.16584 * cgain + 0.555005; # DN
            camera.dark_current = 0.444449; # e-/s/pix
            camera.bias = 129; # DN
            camera.cgain = [ 0.347874 0.436174 0.560194 0.702386 0.876827 1.1207 1.39903 1.7344 2.19983 2.72715 3.37764 4.18329 5.30025 5.34764 5.39546 5.44886 5.4179 5.38713 5.35329 ]; # DN/e-, settings >= 0
            camera.read_noise = [ 1.27644 1.38101 1.65053 1.94531 2.4179 2.91895 3.51555 4.33075 5.31091 7.255 7.91497 9.92268 12.0434 12.2229 12.2631 12.0972 12.0196 12.0571 12.1388 ]; # DN, per setting
            camera.has_iso = 1; # if false, log10(iso / 100) * 200 = gain [0.1dB]
            camera.iso = [ 100 125 160 200 250 320 400 500 640 800 1000 1250 1600 2000 2500 3200 4000 5000 6400 ];
            camera.iso2cgain = @(iso) 0.000157442 * iso + 2.69564; # DN/e-

        case "Nikon_Z6_2"
            % dark mean is black-level clamped, so cgain comes from flats; dual conversion
            % gain switches at ISO 800 (read noise 6.4 -> 2.2 DN)
            camera = {};
            camera.name = "Nikon_Z6_2";
            # cgain from flats; read noise and dark current (variance growth) from darks
            camera.cgain2read_noise = @(cgain) 1.29242 * cgain + 1.92683; # DN
            camera.dark_current = 1.428; # e-/s/pix
            camera.bias = 1008; # DN
            camera.cgain = [ 0.201337 0.361621 0.729464 1.16725 1.45913 3.03345 6.25022 12.3195 24.5046 45.472 ]; # DN/e-, settings >= 0
            camera.read_noise = [ 1.48393 2.40837 4.53309 6.35985 2.22704 5.59733 9.0313 17.1048 32.187 61.7597 ]; # DN, per setting
            camera.has_iso = 1; # if false, log10(iso / 100) * 200 = gain [0.1dB]
            camera.iso = [ 100 200 400 640 800 1600 3200 6400 12800 25600 ];
            camera.iso2cgain = @(iso) 0.00179449 * iso + 0.292538; # DN/e-

        otherwise
            error("sensor_models: unknown sensor '%s'", name);
    end
end
