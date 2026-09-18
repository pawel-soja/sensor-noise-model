function data = sensor_simulate(model, shutter = linspace(1/4000, 15, 5))
    pkg load statistics
    IDX_ISO     = 1;
    IDX_SHUTTER = 2;
    IDX_AVERAGE = 3;
    IDX_SIGMA   = 4;

    iso_len = length(model.iso);
    shu_len = length(shutter);

    data = [];

    for iso=model.iso
        row = [];
        for shu=shutter

            cgain = model.iso2cgain(iso);

            data_dark_current = poissrnd(shu * model.dark_current, 1024 * 1024, 1);
            dark_current = mean(data_dark_current);
            dark_current_sigma2 = std(data_dark_current) .^ 2;
            #dark_current        = shu * model.dark_current;
            #dark_current_sigma2 = dark_current;

            #data_noise = poissrnd();

            row(IDX_ISO)     = iso;
            row(IDX_SHUTTER) = shu;
            row(IDX_AVERAGE) = cgain * dark_current + model.bias;
            row(IDX_SIGMA)   = sqrt(cgain .^ 2 * dark_current_sigma2 + model.cgain2read_noise(cgain) .^ 2);

            data = [data; row];
        end
    end
end
