function sensor_print_model(p)
    % Prints the fit result as Octave code ready to paste into sensor_models.m
    printf("  camera = {};\n");
    printf("  camera.name = \"%s\";\n", p.name);
    if strcmp(p.source, 'flat')
        printf("  # cgain from flats; read noise and dark current (variance growth) from darks\n");
    end
    printf("  camera.cgain2read_noise = @(cgain) %g * cgain + %g; # DN\n", p.cgain2read_noise(1), p.cgain2read_noise(2));
    printf("  camera.dark_current = %g; # e-/s/pix\n", p.dark_current);
    printf("  camera.bias = %g; # DN\n", floor(median(p.bias)));
    printf("  camera.cgain = [ %s]; # DN/e-, settings >= %g\n", sprintf("%g ", p.cgain'), p.min_setting);
    printf("  camera.read_noise = [ %s]; # DN, per setting\n", sprintf("%g ", p.read_noise'));
    printf("  camera.has_iso = %d; # if false, log10(iso / 100) * 200 = gain [0.1dB]\n", p.has_iso)
    printf("  camera.iso = [ %s];\n", sprintf("%g ", p.iso));
    printf("  camera.iso2cgain = @(iso) %g * iso + %g; # DN/e-\n", p.iso2cgain(1), p.iso2cgain(2));
end
