%% Real Time Reading From Waveforms
close all ; clear all ;clc ;

%% settings
directory_samples = 'C:/home/Gault/samples/'; % place where WaveForms saves data
name_file = 'acq' ;
extention_file_name = 'csv' ;

%% reading for the first time, and get the configurations
listing_directory_samples = dir(directory_samples) ;
n_files = size(listing_directory_samples,1);

if(n_files>=4) % ensure you have at least 4 files
    name_NextToLastFile = listing_directory_samples(n_files-1).name ;
    str_aux = fullfile(directory_samples,name_NextToLastFile);
    opts = detectImportOptions( str_aux );
    % preview(str_aux,opts)
end

%% reading the next to last file
listing_directory_samples = dir(directory_samples);
n_files = size(listing_directory_samples, 1);

figure;

while true
    listing_directory_samples = dir(directory_samples);
    n_files = size(listing_directory_samples,1);

    if(n_files>=4)
        disp('collecting data')

        % read samples
        listing_directory_samples = dir(directory_samples) ;
        n_files = size(listing_directory_samples,1) ;
        name_NextToLastFile = listing_directory_samples(n_files-1).name ;

        str_aux = fullfile(directory_samples,name_NextToLastFile);

        %Read information for modulation
        header = readlines(str_aux);

        sampleRate = sscanf(header(5), "#Sample rate: %fHz");
        numSamples = sscanf(header(6), "#Samples: %d");

        frequency = sscanf(header(12), "#Frequency: %f kHz");
        period    = sscanf(header(13), "#Period: %f us");
        amplitude = sscanf(header(14), "#Amplitude: %f V");
        offset    = sscanf(header(15), "#Offset: %f V");
        phase     = sscanf(header(17), "#Phase: %f");

        M = readmatrix(str_aux,opts);

        %% Parameter estimation
        n_samples = numSamples ;
        fsample = sampleRate ;
        
        frequency = frequency * 1000;
        w0 = 2*pi*frequency;
        
        N = [0:(n_samples-1)] ;
        tn = N / fsample;

        signal = amplitude*sin(w0*tn + phase) + offset ;
        signal = signal.';

        % add noise
        %signal = signal + 0.5*(rand(n_samples,1)-0.5);

        % Compute matrix E
        E = [ (sin(w0*tn)).'  (cos(w0*tn)).'  ones(n_samples,1) ] ;
        pseudo_E = pinv(E); 
        
        % p estimation
        
        %p = ( inv(E'*E)*E' ) * signal
        p = pseudo_E * signal;
                
        A_estimation = sqrt( p(1)^2 + p(2)^2  );
              
        phi_estimation = atan2( p(2) , p(1) ); 
        
        c_estimation = p(3);
        
        %Create estimated signal
        signal_estimation = A_estimation*sin(w0*tn + phi_estimation) + c_estimation ;
        signal_estimation = signal_estimation' ;


        % remove all files
        for (i=3:n_files-1) % leave 1-> '.' , 2-> '..', last file

            name_NextToLastFile = listing_directory_samples(i).name ;
            str_aux = fullfile(directory_samples,name_NextToLastFile);
            delete(str_aux);

        end

        %% Isolate Data
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
        f = fsample*(0:floor(Nfft/2))/Nfft;

        % find dominat frequency
        %[fft_amplitude, index] = max(P1);
        %fft_frequency = f(index);

        %% Plot
        subplot(3,1,1)
        plot(time, voltage1)
        ylabel("Volts [V]"); xlabel("Time [s]");
        title('Scope 01')
        %plot( tn , signal , 'r.')

        subplot(3,1,2)
        %plot( tn , signal , 'r.-')
        plot( tn , signal_estimation , 'b.-')
        ylabel("Volts [V]"); xlabel("Time [s]");
        title('Parameter Estimation')
        %xlim( [0 (n_samples/fsample)/16] )
        %legend('signal','signal est.')

        subplot(3,1,3)
        plot(f, P1)
        ylabel('Amplitude [V]')
        xlabel('Frequency [Hz]')
        title('FFT')
        xlim([0 500e3])

        pause(0.3)
        drawnow

        %% %%%%%%%%%% %%%%%%%%%% %%%%%%%%%% %%%%%%%%%% %%%%%%%%%%
    else
        disp('waiting for new data')
    end
    clc;
end