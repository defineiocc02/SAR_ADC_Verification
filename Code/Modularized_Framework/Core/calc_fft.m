function [f_axis, PSD_val, sndr_val] = calc_fft(Dout, Fs, N_fft, ADC, Fin)
% Compatibility entry for voltage-domain Monte Carlo records.
% PSD_val is bin power in dBFS/bin, NOT a density. For density use adc_spectrum.
% Set ADC.spectrum_full_scale_peak explicitly for non-voltage input.
    if numel(Dout) ~= N_fft
        error('ADC:RecordLength', 'N_fft must equal the record length.');
    end
    if isfield(ADC, 'spectrum_full_scale_peak')
        full_scale_peak = ADC.spectrum_full_scale_peak;
    elseif isfield(ADC, 'V_ref')
        full_scale_peak = ADC.V_ref;
    else
        error('ADC:MissingScale', 'Provide the full-scale peak in the input unit.');
    end
    [f_axis, PSD_val, sndr_val] = adc_spectrum(Dout, Fs, full_scale_peak, Fin, 'blackmanharris');
end
