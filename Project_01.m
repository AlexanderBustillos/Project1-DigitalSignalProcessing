% Real Time Reading From Waveforms
close all; clear all; clc;

% Settings
% place where WaveForms saves data
directory_samples = '/Users/alex/Desktop/samples/';
%directory_samples = 'C:/home/Gault/samples/';
name_file = 'acq';
extention_file_name = 'csv';

%Parameters
N_samples_STD = 50;
Amplitude_Vector = zeros(N_samples_STD,2);
Counter = 1;

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
                    % Read waveform data
                    % Create import options if needed
                    if isempty(opts)
                        opts = detectImportOptions(newestPath);
                    end
                    M = readmatrix(newestPath, opts);
                    % Mark this file as processed
                    lastFileProcessed = newestFile;
                    %Isolate Data

                    datalength = length(M(:,2));

                    time = M(1:datalength, 1) - M(1);
                    voltage1 = M(1:datalength-1, 2);

                    %% Parameter Estimation
                    voltage1 = voltage1(:);
                    n_samples = length(voltage1);

                    frequency = 125000;
                    w0 = 2*pi*frequency;

                    tn = (0:n_samples-1).' / sampleRate;

                    %% Compute matrix E
                    E = [ (sin(w0*tn))  (cos(w0*tn)) ...
                        ones(n_samples,1) ];

                    pseudo_E = pinv(E);

                    %% p estimation
                    p = pseudo_E * voltage1;

                    A_estimation = sqrt( p(1)^2 + p(2)^2 );

                    phi_estimation = atan2( p(2) , p(1) );

                    c_estimation = p(3);

                    %% Create estimated signal
                    signal_estimation = A_estimation* ...
                        sin(w0*tn + phi_estimation) + c_estimation;


                    %% FFT
                    x = voltage1(:);
                    %Nfft = length(x);
                    
                    % Remove DC component
                    fft_offset = mean(x);
                    x_ac = x - fft_offset;
                    Nbins = 40;
             
                    % Compute FFT
                    X = fft(x_ac, Nbins);

                    % Frequency axis
                    f_axis = (0:Nbins-1)/Nbins * sampleRate;
                    
                    % Find FFT bin closest to known frequency
                    [~, index] = min(abs(f_axis - frequency));
                    
                    fft_frequency = f_axis(index);
                    
                    % FFT value at that frequency
                    X_peak = X(index);
                    
                    %% Calculate amplitude and phase
                    fft_amplitude = 2*abs(X_peak)/Nbins;

                    fft_phase = angle(X_peak);
                   
                    % Reconstruct signal
                    
                    t = time(:);
                    fft_signal_estimation = ...
                        fft_amplitude * cos(2*pi*fft_frequency*t + fft_phase) ...
                        + fft_offset;


                    %% Display Mean, STD, and Amplitude for comparison
                    
                    QAM_Amp = A_estimation;
                    FFT_Amp = fft_amplitude;

                    Amplitude_Vector (Counter,1) = QAM_Amp;
                    Amplitude_Vector (Counter,2) = FFT_Amp;

                    if(Counter > N_samples_STD)
                        Counter = 1;
                    end

                    Counter = Counter + 1;

                    QAM_Mean = mean(Amplitude_Vector(:,1));
                    FFT_Mean = mean(Amplitude_Vector(:,2));

                    QAM_STD = std(Amplitude_Vector(:,1));
                    FFT_STD = std(Amplitude_Vector(:,2));


                    %% Plotting
                    
                    %Plot of all 3 signals overlapping
                    subplot(3,1,1)
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
                    xlim([0 length(x)])

                    %Plot of a period
                    subplot(3,1,2)
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
                    ylim([-3 3])
                    xlim([0 50])

                    %Plotting the amplitude of the QAM with std and mean
                    subplot(3,2,5);
                    plot(Amplitude_Vector(:,1),'-.');
                    ylabel("QAM_Amp [V]");
                    xlabel("Time [s]");
                    ylim([0 3]);
                    str_aux = sprintf('Amp QAM STD = %f Amp QAM MEAN = %f',QAM_STD,QAM_Mean);
                    title(str_aux);

                    %Plotting the amplitude of the FFT with std and mean
                    subplot(3,2,6);
                    plot(Amplitude_Vector(:,2),'-.');
                    ylabel("FFT_Amp [V]");
                    xlabel("Time [s]");
                    ylim([0 3]);
                    str_aux = sprintf('Amp FFT STD = %f Amp FFT MEAN = %f',FFT_STD,FFT_Mean);
                    title(str_aux);
                   
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
