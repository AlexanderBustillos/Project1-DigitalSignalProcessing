% Real Time Reading From Waveforms
close all; clear all; clc;

% Settings
% place where WaveForms saves data
directory_samples = '/Users/alex/Desktop/samples/';
%directory_samples = 'C:/home/Gault/samples/';
name_file = 'acq';
extention_file_name = 'csv';

% Find an existing file to get import settings
files = dir(fullfile(directory_samples, [name_file '*.' extention_file_name]));

if ~isempty(files)

    % Sort by date
    [~, order] = sort([files.datenum]);
    files = files(order);

    % Use the newest file for import settings
    str_aux = fullfile(directory_samples, files(end).name);

    opts = detectImportOptions(str_aux);
else
    opts = [];
end

% Variables for data collection
lastFileProcessed = "";

figure;

while true
    % Find only acquisition CSV files
    files = dir(fullfile(directory_samples, ...
        [name_file '*.' extention_file_name]));

    if ~isempty(files)

        % Sort files from oldest -> newest
        [~, order] = sort([files.datenum]);
        files = files(order);

        % Get newest file
        newestFile = files(end).name;
        newestPath = fullfile(directory_samples, newestFile);

        % Only process if this is a new file
        if ~strcmp(newestFile, lastFileProcessed)
            % Make sure WaveForms has finished writing the file
            fileInfo1 = dir(newestPath);

            pause(0.05);

            fileInfo2 = dir(newestPath);

            % File size should stop changing before we read it
            if fileInfo1.bytes == fileInfo2.bytes

                try

                    % Read header information
                    header = readlines(newestPath);
                    sampleRate = sscanf(header(5),"#Sample rate: %fHz");

                    numSamples = sscanf(header(6),"#Samples: %d");

                    frequency = sscanf(header(12), "#Frequency: %f kHz");

                    period = sscanf(header(13),"#Period: %f us");

                    amplitude = sscanf(header(14), "#Amplitude: %f V");

                    offset = sscanf(header(15), "#Offset: %f V");

                    phase = sscanf(header(17),"#Phase: %f");

                    % Read waveform data

                    % Create import options if needed
                    if isempty(opts)
                        opts = detectImportOptions(newestPath);
                    end

                    M = readmatrix(newestPath, opts);

                    % Mark this file as processed
                    lastFileProcessed = newestFile;

                    %% Isolate Data

                    datalength = length(M(:,2));

                    time = M(1:datalength-1, 1);
                    voltage1 = M(1:datalength-1, 2);

                    %% Parameter Estimation
                    voltage1 = voltage1(:);
                    n_samples = length(voltage1);

                    frequency = 125000;
                    w0 = 2*pi*frequency;

                    tn = (0:n_samples-1).' / sampleRate;

                    % Compute matrix E
                    E = [ (sin(w0*tn))  (cos(w0*tn)) ...
                        ones(n_samples,1) ];

                    pseudo_E = pinv(E);

                    % p estimation

                    %p = ( inv(E'*E)*E' ) * signal
                    p = pseudo_E * voltage1;

                    A_estimation = sqrt( p(1)^2 + p(2)^2 );

                    phi_estimation = atan2( p(2) , p(1) );

                    c_estimation = p(3);

                    %Create estimated signal
                    signal_estimation = A_estimation* ...
                        sin(w0*tn + phi_estimation) + c_estimation;

                    %% FFT
                    
                    x = voltage1(:);
                    Nfft = length(x);
                    
                    % Remove DC component
                    fft_offset = mean(x);
                    x_ac = x - fft_offset;
                    
                    % Compute FFT
                    X = fft(x_ac);

                    % Frequency axis
                    f_axis = (0:Nfft-1)/Nfft * sampleRate;
                    
                    % Only look at positive frequencies
                    f_positive = f_axis(1:floor(Nfft/2)+1);
                    X_positive = X(1:floor(Nfft/2)+1);
                    
                    % Find FFT bin closest to known frequency
                    
                    [~, index] = min(abs(f_positive - frequency));
                    
                    fft_frequency = f_positive(index);
                    
                    % Get complex FFT value at that frequency
                    X_peak = X_positive(index);
                    
                    % Calculate amplitude
                    
                    fft_amplitude = 2*abs(X_peak)/Nfft;
                    
                    % Calculate phase
                    
                    % FFT gives cosine phase
                    fft_phase_cos = angle(X_peak);
                    
                    % Convert cosine phase to sine phase
                    fft_phase = fft_phase_cos + pi/2;
                    
                    % Keep phase between -pi and pi
                    %fft_phase = atan2(sin(fft_phase), cos(fft_phase));
                    
                    % Reconstruct signal
                    
                    t = time(:);
                    
                    fft_signal_estimation = ...
                        fft_amplitude * sin(2*pi*fft_frequency*t + fft_phase) ...
                        + fft_offset;


                    %% Display Mean, STD, and Amplitude for comparison

                    QAM_Amp = A_estimation;
                    FFT_Amp = fft_amplitude;
                    
                    QAM_Mean = mean(signal_estimation);
                    FFT_Mean = mean(fft_signal_estimation);
                    
                    QAM_STD = std(signal_estimation);
                    FFT_STD = std(fft_signal_estimation);
                    
                    fprintf('Modulation Amplitude: %.4f V\n', QAM_Amp);
                    fprintf('FFT Amplitude:        %.4f V\n\n', FFT_Amp);
                    
                    fprintf('Modulation Mean:      %.4f V\n', QAM_Mean);
                    fprintf('FFT Mean:             %.4f V\n\n', FFT_Mean);
                    
                    fprintf('Modulation STD:       %.4f V\n', QAM_STD);
                    fprintf('FFT STD:              %.4f V\n', FFT_STD);
                    fprintf('\n');

                    fprintf('Actual frequency: %.4f Hz\n', frequency);
                    fprintf('FFT bin frequency: %.4f Hz\n', fft_frequency);
                    fprintf('Bin spacing: %.4f Hz\n\n', sampleRate/Nfft);

                    fprintf('Sample rate: %.2f Hz\n', sampleRate);
                    fprintf('Number of samples: %d\n', Nfft);
        
                                      


                    %Plotting
                

                    subplot(4,1,1)

                    plot(voltage1, 'b.-')

                    ylabel("Volts [V]");
                    xlabel("Time [s]");

                    title('Scope 01');


                    subplot(4,1,2)

                    plot(signal_estimation, 'b.-')

                    ylabel("Volts [V]");
                    xlabel("Time [s]");

                    title('Parameter Estimation');
                    

                    subplot(4,1,3)
                    plot( fft_signal_estimation, 'b.-')
                    ylabel('Volts [V]')
                    xlabel('Time [s]')
                    title('FFT')

                    subplot(4,1,4)
                    cla;   
                    hold on;
                    plot( voltage1, 'b.-')
                    plot( signal_estimation, 'r.-')
                    plot( fft_signal_estimation, 'g.-')
                    ylabel("Volts [V]");
                    xlabel("Time [s]");
                    title('comparison');
                    legend('Input', 'QAM','FFT');
                    hold off;
                    %draw now;



                    %Update plot

                    drawnow;

                    pause(0.3);

                    %Cleaning old files


                    % Refresh file list
                    files = dir(fullfile(directory_samples, ...
                        [name_file '*.' extention_file_name]));

                    [~, order] = sort([files.datenum]);
                    files = files(order);

                    % Keep the newest file and delete older files
                    if length(files) > 1

                        for i = 1:length(files)-1

                            oldFile = fullfile( ...
                                directory_samples, ...
                                files(i).name);

                            try
                                delete(oldFile);
                            catch
                                % File may currently be used by WaveForms
                            end

                        end

                    end

                catch ME
                    disp('ERROR: ');
                    disp(ME.message);
                end

            else 

            end

        end

    else

    end
    pause(0.05);

end
