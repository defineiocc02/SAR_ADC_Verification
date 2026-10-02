function [frequency, power_dbfs, sndr, detail] = adc_spectrum(x, fs, full_scale_peak, fin, window_name)
% One-sided bin power [dBFS/bin], density [signal-unit^2/Hz], and sine-fit SNDR.
% full_scale_peak uses the same unit as x. A full-scale sine has RMS power A^2/2.
% SNDR excludes a fitted DC and fundamental; it retains harmonics and noise.
% No arbitrary 100/120 dB saturation is applied. Fin must be independently known.
    if ~isvector(x) || ~isreal(x) || numel(x)<16 || any(~isfinite(x(:)))
        error('ADC:InvalidRecord', 'Need at least 16 finite real samples.');
    end
    if ~isscalar(fs) || ~isfinite(fs) || fs<=0 || ...
       ~isscalar(full_scale_peak) || ~isfinite(full_scale_peak) || full_scale_peak<=0 || ...
       ~isscalar(fin) || ~isfinite(fin) || fin<=0 || fin>=fs/2
        error('ADC:InvalidScale', 'Invalid sample rate, full scale or tone.');
    end
    x = double(x(:)); N = numel(x); sample = (0:N-1)';
    if strcmpi(window_name, 'rectangular')
        if abs(fin*N/fs-round(fin*N/fs)) > 1e-7
            error('ADC:Noncoherent', 'Rectangular analysis requires coherent sampling.');
        end
        w = ones(N,1);
    elseif strcmpi(window_name, 'blackmanharris')
        phase = 2*pi*sample/(N-1);
        w = 0.35875-0.48829*cos(phase)+0.14128*cos(2*phase)-0.01168*cos(3*phase);
    else
        error('ADC:InvalidWindow', 'Unknown window.');
    end
    centered = x-mean(x);
    transformed = fft(centered.*w);
    count = floor(N/2)+1;
    density = abs(transformed(1:count)).^2/(fs*sum(w.^2));
    if rem(N,2)==0
        density(2:end-1) = 2*density(2:end-1);
    else
        density(2:end) = 2*density(2:end);
    end
    ref_power = full_scale_peak^2/2;
    bin_power = density*(fs/N);
    frequency = ((0:count-1)'*fs/N)';
    power_dbfs = (10*log10(bin_power/ref_power))';
    phase = 2*pi*fin*sample/fs;
    basis = [ones(N,1), sin(phase), cos(phase)];
    coefficients = basis\x;
    residual = x-basis*coefficients;
    tone = basis(:,2:3)*coefficients(2:3);
    signal_power = mean((tone-mean(tone)).^2);
    noise_power = mean(residual.^2);
    if all(centered==0)
        sndr = NaN;
    elseif noise_power==0
        sndr = Inf;
    else
        sndr = 10*log10(signal_power/noise_power);
    end
    detail.density = density';
    detail.bin_power = bin_power';
    detail.reference_power = ref_power;
    detail.df_hz = fs/N;
    detail.enbw_hz = fs*sum(w.^2)/sum(w)^2;
    detail.power_unit = 'dBFS/bin';
    detail.density_unit = 'input-unit^2/Hz';
    detail.window = window_name;
end
