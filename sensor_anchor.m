function anchor = sensor_anchor(name)
    % External egain reference for cameras whose darks are too clean for photon transfer.
    % Returns [] when the camera should use the photon-transfer egain (e.g. Nikon_D5100).
    % Pick an ISO where the dark rate is well above the noise of the mean (>= a few DN over
    % the exposure series); the relative curve dark_rate(ISO) then gives egain elsewhere.
    switch name
        case "Nikon_Z6_2"
            % Provisional: Z6 (same sensor) ISO 100 ~ 0.33 DN/e- (PhotonsToPhotos), x8 to ISO 800.
            % Replace with a flat-based measurement when available.
            anchor = struct('iso', 800, 'egain', 2.64);
        otherwise
            anchor = [];
    end
end
