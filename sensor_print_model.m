function sensor_print_model(p)
    % Prints the fit result as Octave code ready to paste into sensor_models.m
    printf("  camera = {};\n");
    printf("  camera.name = \"%s\";\n", p.name);
    printf("  camera.egain2read_noise = @(egain) %g * egain + %g; # DN\n", p.egain2read_noise(1), p.egain2read_noise(2));
    printf("  camera.dark_current = %g; # e-/s/pix\n", p.dark_current);
    printf("  camera.bias = %g; # DN\n", floor(median(p.bias)));
    printf("  camera.egain = [ %s]; # %s\n", sprintf("%g ", p.egain'), p.egain_source);
    printf("  camera.has_iso = %d; # if false, log10(iso / 100) * 200 = gain [0.1dB]\n", p.has_iso)
    printf("  camera.iso = [ %s];\n", sprintf("%g ", p.iso));
    printf("  camera.iso2egain = @(iso) %g * iso + %g; # DN/e-\n", p.iso2egain(1), p.iso2egain(2));
end
