function sensor_validate(name = "Nikon_D5100")
    % Round-trip check: model -> synthetic stats -> fit -> plot
    camera = sensor_models(name);

    data = sensor_simulate(camera);
    analysis = sensor_fit(data);
    analysis.name = [camera.name "_simulated"];

    sensor_plot(analysis);
    sensor_print_model(analysis);
end
