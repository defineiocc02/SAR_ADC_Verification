function run_numeric_tests()
    root = fileparts(fileparts(mfilename('fullpath')));
    core = fullfile(root, 'Code', 'Modularized_Framework', 'Core');
    addpath(core); addpath(fullfile(core, 'algorithms'));
    for N = [4 8 12 16 20 22 24]
        for method = {'mle', 'be'}
            lut = generate_residual_lut(N, 0.6, method{1});
            assert(numel(lut)==N+1);
            assert(all(isfinite(lut)) && all(diff(lut)>=-1e-12));
            assert(max(abs(lut+fliplr(lut)))<1e-10);
            assert(lut(1)<0 && lut(end)>0 && abs(lut(N/2+1))<1e-10);
        end
        lut = generate_residual_lut(N, 0.6, 'mle');
        [estimate, ~, count] = run_mle([-100 100], N, 0, lut, zeros(2,N));
        assert(isequal(count, [0 N]));
        assert(estimate(1)<0 && estimate(2)>0);
    end
    wrong_table = generate_residual_lut(24, 0.6, 'mle');
    assert(wrong_table(5)<0); % Negative control: the former N=4 slice is invalid.
    N = 4096; fs = 1e6; k = 71; fin = k*fs/N; t = 0:N-1;
    x = 0.8*sin(2*pi*k*t/N)+0.008*sin(2*pi*3*k*t/N);
    [~, bins, sndr, detail] = adc_spectrum(x, fs, 1, fin, 'rectangular');
    assert(abs(sndr-40)<1e-8);
    assert(abs(sum(10.^(bins/10))-(0.8^2+0.008^2))<1e-10);
    assert(abs(sum(detail.density)*fs/N-mean(x.^2))<1e-10);
    [~, ~, shifted] = adc_spectrum(x+17, fs, 1, fin, 'rectangular');
    assert(abs(shifted-sndr)<1e-8);
    [~, ~, compat] = calc_fft((x+17)',fs,N,struct('V_ref',1),fin);
    assert(abs(compat-sndr)<1e-8);
    y = sin(2*pi*k*t/N)+0.01*cos(pi*t);
    [~, ~, ~, nyquist] = adc_spectrum(y,fs,1,fin,'rectangular');
    assert(abs(nyquist.bin_power(end)-0.0001)<1e-10);
    Nodd = 2049; u = 0:Nodd-1;
    [~, ~, ~, odd] = adc_spectrum(sin(2*pi*71*u/Nodd),fs,1,71*fs/Nodd,'rectangular');
    assert(abs(sum(odd.bin_power)-0.5)<1e-10);
    [~, ~, constant] = adc_spectrum(ones(1,N),fs,1,fin,'rectangular');
    assert(isnan(constant));
    rejected=false;
    try adc_spectrum(x,fs,1,fin+fs/N/3,'rectangular'); catch rejected=true; end
    assert(rejected);
    rejected=false;
    try generate_residual_lut(0,0.6,'mle'); catch rejected=true; end
    assert(rejected);
    fprintf('PASS: count-specific likelihood, signed endpoints, spectral power, DC invariance, Nyquist and odd records.\n');
end
