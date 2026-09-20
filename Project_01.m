% Real Time Reading From Waveforms
close all; clear all; clc;

% Settings
% place where WaveForms saves data
%directory_samples = '/Users/alex/Desktop/samples/';
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

                    disp(['Reading: ' newestFile]);
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

                    %% Parameter Estimation
                    frequency = frequency * 1000;
                    w0 = 2*pi*frequency;

                    N = [0:(numSamples-1)];
                    tn = N / sampleRate;

                    signal = amplitude*sin(w0*tn + phase) + offset;
                    signal = signal.';

                    % add noise
                    %signal = signal + 0.5*(rand(numSamples,1)-0.5);

                    % Compute matrix E
                    E = [ (sin(w0*tn)).'  (cos(w0*tn)).' ...
                        ones(numSamples,1) ];

                    pseudo_E = pinv(E);

                    % p estimation

                    %p = ( inv(E'*E)*E' ) * signal
                    p = pseudo_E * signal;

                    A_estimation = sqrt( p(1)^2 + p(2)^2 );

                    phi_estimation = atan2( p(2) , p(1) );

                    c_estimation = p(3);

                    %Create estimated signal
                    signal_estimation = A_estimation* ...
                        sin(w0*tn + phi_estimation) + c_estimation;

                    signal_estimation = signal_estimation';


                    %Isolate Data

                    datalength = length(M(:,2));

                    time = M(1:datalength-1, 1);
                    voltage1 = M(1:datalength-1, 2);


                    %% FFT

                    x = voltage1(:);
                    Nfft = length(x);

                    % remove DC component
                    x_ac = x - mean(x);

                    % compute fft
                    X = fft(x_ac);

                    % two sided magnitude spectrum
                    P2 = abs(X/Nfft);

                    % single sided magnitude spectrum
                    P1 = P2(1:floor(Nfft/2)+1);

                    % account for negative frequency
                    P1(2:end-1) = 2*P1(2:end-1);

                    % frequency axis
                    f = sampleRate*(0:floor(Nfft/2))/Nfft;

                   % Estimate dominant frequency and amplitude
                    [fft_amplitude, index] = max(P1);
                    fft_frequency = f(index);

                    %Plotting

                    subplot(3,1,1)

                    plot(time, voltage1)

                    ylabel("Volts [V]");
                    xlabel("Time [s]");

                    title('Scope 01');


                    subplot(3,1,2)

                    plot(tn, signal_estimation, 'b.-')

                    ylabel("Volts [V]");
                    xlabel("Time [s]");

                    title('Parameter Estimation');


                    subplot(3,1,3)

                    plot(fft_frequency, fft_amplitude)

                    ylabel('Amplitude [V]')
                    xlabel('Frequency [Hz]')

                    title('FFT')

                    xlim([0 500e3])


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

                end

            else 

            end

        end

    else

    end
    pause(0.05);
end
