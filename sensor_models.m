function camera = sensor_models(name)
    % Returns a fitted sensor model by name (output of sensor_print_model).
    switch name
        case "ASI2600MM_5deg"
            camera = {};
            camera.name = "ASI2600MM_5deg";
            camera.egain2read_noise = @(egain) 0.683603 * egain + 2.97458; # DN
            camera.dark_current = 0.00184594; # e-/s/pix
            camera.bias = 99; # DN
            camera.egain = [ 8.15623 5.09856 7.47473 6.46064 9.06379 8.00017 6.46293 6.99126 7.20754 10.6459 19.7142 44.0167 63.6323 94.1885 165.682 266.537 ];
            camera.has_iso = 0; # if false, log10(iso / 100) * 200 = gain [0.1dB]
            camera.iso = [ 100 133.352 177.828 237.137 251.189 266.073 281.838 298.538 316.228 562.341 1000 1778.28 3162.28 5623.41 10000 17782.8 ];
            camera.iso2egain = @(iso) 0.015119 * iso + 5.92291; # DN/e-

        case "Nikon-D5100"
            camera = {};
            camera.name = "Nikon-D5100";
            camera.egain2read_noise = @(egain) 2.08105 * egain + 0.572391; # DN
            camera.dark_current = 0.443848; # e-/s/pix
            camera.bias = 128; # DN
            camera.egain = [ 0.364511 0.436173 0.551517 0.668151 0.891261 1.13563 1.38105 1.8045 2.22617 3.1798 3.58617 4.60874 ];
            camera.has_iso = 1; # if false, log10(iso / 100) * 200 = gain [0.1dB]
            camera.iso = [ 100 125 160 200 250 320 400 500 640 800 1000 1250 ];
            camera.iso2egain = @(iso) 0.00372776 * iso + -0.0485242; # DN/e-

        otherwise
            error("sensor_models: unknown sensor '%s'", name);
    end
end
