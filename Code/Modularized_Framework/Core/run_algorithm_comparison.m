% =========================================================================
% run_algorithm_comparison.m - 全链路动态行为级仿真平台
% =========================================================================
% 功能：基于正弦波相干采样的SAR ADC全链路动态仿真
% 
% 核心架构：
%   - 相干采样正弦波输入 + kT/C热噪声底
%   - 16-bit动态SAR量化（含比较器噪声注入）
%   - 残差自然产生（非预设）
%   - 8192点FFT计算真实SNDR
% 
% 扫描参数：
%   - 比较器噪声：σ_n = [0.4:0.1:1.2] LSB
%   - 冗余周期：N_red = [4, 8, 12, 16, 20, 24]
% 
% 输出图表：
%   - Fig_1_SNDR_vs_Sigma_PVT.png
%   - Fig_2_FFT_Spectrum_Comparison.png
%   - Fig_3_SNDR_vs_Nred.png
%   - Fig_4_Residual_PDF_Dynamic.png
% =========================================================================

function run_algorithm_comparison()
    tic;
    fprintf('================================================================================\n');
    fprintf('  SAR ADC 全链路动态行为级仿真平台 (JSSC风格)\n');
    fprintf('================================================================================\n');
    
    %% ========================================================================
    % 步骤1: 仿真参数配置
    %% ========================================================================
    fprintf('\n>>> [1/6] 配置动态仿真参数...\n');
    
    cfg.ADC.Resolution = 16;
    cfg.ADC.N_bits = 16;
    cfg.ADC.Fs = 5e6;
    cfg.ADC.V_ref = 1.0;
    cfg.ADC.V_dd = 1.8;
    cfg.ADC.C_sample = 10e-12;
    
    cfg.scan.N_red_range = [4, 8, 12, 16, 20, 24];
    cfg.scan.sigma_range = linspace(0.4, 1.2, 9);
    
    cfg.N_FFT = 8192;
    cfg.N_pts = cfg.N_FFT;
    cfg.N_MC = 20;
    
    target_SNR_dB = 91.8;
    P_FS = (2^(cfg.ADC.N_bits-1))^2 / 2;
    k_B = 1.380649e-23;
    T = 300;
    C_s = cfg.ADC.C_sample;
    kTC_noise = sqrt(k_B * T / C_s);
    V_LSB = 2 * cfg.ADC.V_ref / (2^cfg.ADC.N_bits);
    kTC_LSB = kTC_noise / V_LSB;
    fprintf('    kT/C噪声: %.3f LSB (对应%.1f dB)\n', kTC_LSB, target_SNR_dB);
    
    P_th = P_FS / (10^(target_SNR_dB/10));
    SNDR_Thermal_Limit = target_SNR_dB;
    
    cfg.output_dir = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'ComparisonResults');
    if ~exist(cfg.output_dir, 'dir')
        mkdir(cfg.output_dir);
    end
    
    fprintf('    FFT点数: %d\n', cfg.N_FFT);
    fprintf('    冗余周期范围: [%s]\n', num2str(cfg.scan.N_red_range));
    fprintf('    噪声范围: %.2f - %.2f LSB\n', cfg.scan.sigma_range(1), cfg.scan.sigma_range(end));
    
    algorithms_dir = fullfile(fileparts(mfilename('fullpath')), 'algorithms');
    addpath(algorithms_dir);
    
    num_N_red = length(cfg.scan.N_red_range);
    num_sigma = length(cfg.scan.sigma_range);
    alg_names = {'MLE', 'BE', 'DLR', 'ATA', 'ALA'};
    num_algs = length(alg_names);
    
    results = struct();
    results.N_red_range = cfg.scan.N_red_range;
    results.sigma_range = cfg.scan.sigma_range;
    results.sndr_raw = zeros(1, num_sigma);
    results.sndr = zeros(num_algs, num_sigma);
    results.sndr_gain = zeros(num_algs, num_sigma);
    results.sndr_fft = zeros(num_algs, num_N_red, num_sigma);
    
    base_sigma = 0.6;
    LUT_MLE = generate_LUT_MLE(cfg.scan.N_red_range(end), base_sigma);
    LUT_BE = generate_LUT_BE(cfg.scan.N_red_range(end), base_sigma);
    
    fprintf('\n>>> [2/6] 生成相干采样正弦波输入...\n');
    N_prime = 127;
    f_in = N_prime / cfg.N_FFT * cfg.ADC.Fs;
    t = (0:cfg.N_FFT-1) / cfg.ADC.Fs;
    A_in = cfg.ADC.V_ref * 0.95;
    V_in = A_in * sin(2 * pi * f_in * t);
    
    kTC_array = kTC_noise * randn(1, cfg.N_FFT);
    V_in_noisy = V_in + kTC_array;
    
    fprintf('    f_in = %.2f Hz (N_prime=%d)\n', f_in, N_prime);
    fprintf('    满量程: %.2f V\n', A_in);
    
    fprintf('\n>>> [3/6] 执行动态SAR量化 + 残差估计...\n');
    
    total_iters = num_N_red * num_sigma;
    current_iter = 0;
    
    for i_sigma = 1:num_sigma
        sigma_th = cfg.scan.sigma_range(i_sigma);
        current_iter = current_iter + 1;
        
        fprintf('\n    [%d/%d] σ_n = %.2f LSB\n', current_iter, total_iters, sigma_th);
        
        [D_raw, V_res_dynamic] = run_dynamic_sar_quantization(V_in_noisy, cfg.ADC, sigma_th);
        
        V_res_LSB = V_res_dynamic / V_LSB;
        
        [psd_raw, freq_raw] = compute_fft_psd(double(D_raw), cfg.ADC.Fs);
        sndr_raw = compute_sndr_from_psd(psd_raw, freq_raw, f_in);
        results.sndr_raw(i_sigma) = sndr_raw;
        
        fprintf('      Raw SNDR: %.2f dB\n', sndr_raw);
        
        for i_N = 1:num_N_red
            N_red = cfg.scan.N_red_range(i_N);
            
            RW_drift = randn(cfg.N_pts, N_red) * (sigma_th * 0.3);
            
            [est_mle, ~, ~, ~] = run_mle(V_res_LSB, N_red, sigma_th, LUT_MLE(1:N_red+1), RW_drift);
            D_mle = D_raw + int32(round(est_mle));
            
            [est_be, ~, ~, ~] = run_be(V_res_LSB, N_red, sigma_th, LUT_BE(1:N_red+1), RW_drift);
            D_be = D_raw + int32(round(est_be));
            
            [est_dlr, ~, ~, ~] = run_dlr(V_res_LSB, N_red, sigma_th, RW_drift);
            D_dlr = D_raw + int32(round(est_dlr));
            
            [est_ata, ~, ~, ~] = run_ata(V_res_LSB, N_red, sigma_th, RW_drift);
            D_ata = D_raw + int32(round(est_ata));
            
            [est_ala, ~, ~, ~] = run_ala(V_res_LSB, N_red, sigma_th, RW_drift);
            D_ala = D_raw + int32(round(est_ala));
            
            [psd_mle, ~] = compute_fft_psd(double(D_mle), cfg.Fs);
            results.sndr_fft(1, i_N, i_sigma) = compute_sndr_from_psd(psd_mle, freq_raw, f_in);
            
            [psd_be, ~] = compute_fft_psd(double(D_be), cfg.Fs);
            results.sndr_fft(2, i_N, i_sigma) = compute_sndr_from_psd(psd_be, freq_raw, f_in);
            
            [psd_dlr, ~] = compute_fft_psd(double(D_dlr), cfg.Fs);
            results.sndr_fft(3, i_N, i_sigma) = compute_sndr_from_psd(psd_dlr, freq_raw, f_in);
            
            [psd_ata, ~] = compute_fft_psd(double(D_ata), cfg.Fs);
            results.sndr_fft(4, i_N, i_sigma) = compute_sndr_from_psd(psd_ata, freq_raw, f_in);
            
            [psd_ala, ~] = compute_fft_psd(double(D_ala), cfg.Fs);
            results.sndr_fft(5, i_N, i_sigma) = compute_sndr_from_psd(psd_ala, freq_raw, f_in);
        end
        
        for a = 1:num_algs
            results.sndr(a, i_sigma) = results.sndr_fft(a, end, i_sigma);
            results.sndr_gain(a, i_sigma) = results.sndr(a, i_sigma) - sndr_raw;
        end
    end
    
    fprintf('\n>>> [4/6] 提取典型工况 FFT 数据 (σ=0.8, N=22)...\n');
    i_sigma_typ = find(cfg.scan.sigma_range >= 0.8, 1);
    i_N_typ = find(cfg.scan.N_red_range >= 22, 1);
    
    sigma_typ = cfg.scan.sigma_range(i_sigma_typ);
    N_red_typ = cfg.scan.N_red_range(i_N_typ);
    
    [D_raw_typ, V_res_typ] = run_dynamic_sar_quantization(V_in_noisy, cfg.ADC, sigma_typ);
    V_res_typ_LSB = V_res_typ / V_LSB;
    RW_drift_typ = randn(cfg.N_pts, N_red_typ) * (sigma_typ * 0.3);
    [est_ala_typ, ~, ~, ~] = run_ala(V_res_typ_LSB, N_red_typ, sigma_typ, LUT_MLE(1:N_red_typ+1), RW_drift_typ);
    D_ala_typ = D_raw_typ + int32(round(est_ala_typ));
    
    [psd_raw_typ, freq_typ] = compute_fft_psd(double(D_raw_typ), cfg.Fs);
    [psd_ala_typ, ~] = compute_fft_psd(double(D_ala_typ), cfg.Fs);
    
    sndr_raw_typ = results.sndr_raw(i_sigma_typ);
    sndr_ala_typ = results.sndr_fft(5, i_N_typ, i_sigma_typ);
    
    fprintf('    Raw SNDR: %.2f dB\n', sndr_raw_typ);
    fprintf('    ALA SNDR: %.2f dB\n', sndr_ala_typ);
    
    fprintf('\n>>> [5/6] 生成可视化图表...\n');
    
    color_raw = [0.2, 0.2, 0.2];
    color_ala = [0.8, 0, 0];
    color_ata = [0, 0, 0.8];
    color_dlr = [0, 0.6, 0];
    color_mle = [0.5, 0.5, 0.5];
    color_be = [0.6, 0.6, 0.6];
    color_thermal = [0.9, 0, 0];
    
    fs_axis = 14;
    fs_title = 16;
    fs_legend = 11;
    
    save_fig_eps = @(fig_h, filename) saveas(fig_h, fullfile(cfg.output_dir, filename), 'epsc');
    
    % ========================================================================
    % Fig_1: SNDR vs Sigma (PVT鲁棒性测试)
    % ========================================================================
    figure('Position', [100, 100, 1000, 700]);
    hold on;
    
    yline(SNDR_Thermal_Limit, 'r--', 'LineWidth', 2.5, 'DisplayName', sprintf('Thermal Limit (%.1f dB)', SNDR_Thermal_Limit));
    
    plot(cfg.scan.sigma_range, results.sndr_raw, 'k--', 'LineWidth', 2, 'DisplayName', 'Raw SAR');
    
    plot(cfg.scan.sigma_range, results.sndr(1,:), 's--', 'Color', color_mle, 'LineWidth', 1.5, 'MarkerSize', 8, 'DisplayName', 'MLE (LUT@0.6)');
    plot(cfg.scan.sigma_range, results.sndr(2,:), 'v--', 'Color', color_be, 'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName', 'BE (LUT@0.6)');
    plot(cfg.scan.sigma_range, results.sndr(3,:), '^-', 'Color', color_dlr, 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', 'DLR');
    plot(cfg.scan.sigma_range, results.sndr(4,:), 's-', 'Color', color_ata, 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', 'ATA v5.0');
    plot(cfg.scan.sigma_range, results.sndr(5,:), 'o-', 'Color', color_ala, 'LineWidth', 2.5, 'MarkerSize', 9, 'DisplayName', 'ALA v3.0');
    
    hold off;
    xlabel('$\sigma_n$ (LSB)', 'Interpreter', 'latex', 'FontSize', fs_axis);
    ylabel('SNDR (dB)', 'Interpreter', 'latex', 'FontSize', fs_axis);
    title('PVT Robustness Test: Dynamic SNDR vs Comparator Noise', 'FontSize', fs_title, 'Interpreter', 'latex');
    legend('Location', 'best', 'FontSize', fs_legend);
    grid on;
    set(gca, 'FontSize', fs_axis-2);
    box on;
    ylim([60, 100]);
    
    saveas(gcf, fullfile(cfg.output_dir, 'Fig_1_SNDR_vs_Sigma_PVT.png'));
    save_fig_eps(gcf, 'Fig_1_SNDR_vs_Sigma_PVT');
    close(gcf);
    
    % ========================================================================
    % Fig_2: FFT频谱对比
    % ========================================================================
    figure('Position', [100, 100, 1000, 700]);
    hold on;
    
    plot(freq_typ/1e3, 10*log10(psd_raw_typ), 'k-', 'LineWidth', 1.5, 'DisplayName', sprintf('Raw (SNDR=%.1f dB)', sndr_raw_typ));
    plot(freq_typ/1e3, 10*log10(psd_ala_typ), 'r-', 'LineWidth', 2.5, 'DisplayName', sprintf('ALA (SNDR=%.1f dB)', sndr_ala_typ));
    
    [~, idx_fund] = min(abs(freq_typ - f_in));
    fund_power_raw = psd_raw_typ(idx_fund);
    fund_power_ala = psd_ala_typ(idx_fund);
    
    noise_floor_raw = mean(psd_raw_typ(end-100:end));
    noise_floor_ala = mean(psd_ala_typ(end-100:end));
    floor_improvement = 10*log10(noise_floor_raw/noise_floor_ala);
    
    xline(f_in/1e3, 'g:', 'LineWidth', 1.5, 'DisplayName', sprintf('f_{in}=%.2f kHz', f_in/1e3));
    
    hold off;
    xlabel('Frequency (kHz)', 'Interpreter', 'latex', 'FontSize', fs_axis);
    ylabel('PSD (dBFS)', 'Interpreter', 'latex', 'FontSize', fs_axis);
    title(sprintf('FFT Spectrum: $\\sigma_n=%.2f$ LSB, $N_{red}=%d$', sigma_typ, N_red_typ), 'FontSize', fs_title, 'Interpreter', 'latex');
    legend('Location', 'best', 'FontSize', fs_legend);
    grid on;
    set(gca, 'FontSize', fs_axis-2);
    box on;
    xlim([0, cfg.Fs/2e3]);
    ylim([-160, 0]);
    
    annotation('textbox', [0.6, 0.75, 0.25, 0.1], 'String', sprintf('Noise Floor\\Delta = +%.1f dB', floor_improvement), ...
        'FontSize', 12, 'Interpreter', 'latex', 'EdgeColor', 'k', 'FaceAlpha', 0.9);
    
    saveas(gcf, fullfile(cfg.output_dir, 'Fig_2_FFT_Spectrum_Comparison.png'));
    save_fig_eps(gcf, 'Fig_2_FFT_Spectrum_Comparison');
    close(gcf);
    
    % ========================================================================
    % Fig_3: SNDR vs N_red (收敛效率)
    % ========================================================================
    i_sigma_fixed = find(cfg.scan.sigma_range >= 0.8, 1);
    
    figure('Position', [100, 100, 1000, 700]);
    hold on;
    
    yline(SNDR_Thermal_Limit, 'r--', 'LineWidth', 2.5, 'DisplayName', sprintf('Thermal Limit (%.1f dB)', SNDR_Thermal_Limit));
    
    raw_vs_N = results.sndr_raw(i_sigma_fixed) * ones(1, num_N_red);
    plot(cfg.scan.N_red_range, raw_vs_N, 'k--', 'LineWidth', 2, 'DisplayName', 'Raw SAR');
    
    for a = [3, 4, 5]
        alg_name = alg_names{a};
        if a == 3, c = color_dlr; mk = '^-'; lw = 2; ms = 8;
        elseif a == 4, c = color_ata; mk = 's-'; lw = 2; ms = 8;
        else, c = color_ala; mk = 'o-'; lw = 2.5; ms = 9; end
        
        plot_data = squeeze(results.sndr_fft(a, :, i_sigma_fixed));
        plot(cfg.scan.N_red_range, plot_data, mk, 'Color', c, 'LineWidth', lw, 'MarkerSize', ms, 'DisplayName', alg_name);
    end
    
    [max_ala, max_idx] = max(plot_data);
    if max_idx < length(cfg.scan.N_red_range)
        knee_N = cfg.scan.N_red_range(max_idx);
        knee_sndr = plot_data(max_idx);
        plot(knee_N, knee_sndr, 'k*', 'MarkerSize', 15, 'LineWidth', 2);
        text(knee_N+0.5, knee_sndr+1, sprintf('N=%d', knee_N), 'FontSize', 10, 'Interpreter', 'latex');
    end
    
    hold off;
    xlabel('$N_{red}$', 'Interpreter', 'latex', 'FontSize', fs_axis);
    ylabel('SNDR (dB)', 'Interpreter', 'latex', 'FontSize', fs_axis);
    title(sprintf('Convergence Efficiency: $\\sigma_n=%.2f$ LSB', cfg.scan.sigma_range(i_sigma_fixed)), 'FontSize', fs_title, 'Interpreter', 'latex');
    legend('Location', 'best', 'FontSize', fs_legend);
    grid on;
    set(gca, 'FontSize', fs_axis-2);
    box on;
    xlim([cfg.scan.N_red_range(1)-1, cfg.scan.N_red_range(end)+1]);
    ylim([60, 100]);
    
    saveas(gcf, fullfile(cfg.output_dir, 'Fig_3_SNDR_vs_Nred.png'));
    save_fig_eps(gcf, 'Fig_3_SNDR_vs_Nred');
    close(gcf);
    
    % ========================================================================
    % Fig_4: 动态残差分布直方图
    % ========================================================================
    V_res_before = V_res_typ;
    V_res_after = V_res_typ - est_ala_typ;
    
    rms_before = sqrt(mean(V_res_before.^2));
    rms_after = sqrt(mean(V_res_after.^2));
    compression_ratio = rms_before / rms_after;
    
    figure('Position', [100, 100, 1000, 700]);
    hold on;
    
    bins = linspace(min(V_res_before)*1.2, max(V_res_before)*1.2, 60);
    
    histogram(V_res_before, bins, 'FaceColor', 'k', 'FaceAlpha', 0.3, 'DisplayName', sprintf('Before (RMS=%.3f)', rms_before));
    histogram(V_res_after, bins, 'FaceColor', color_ala, 'FaceAlpha', 0.6, 'DisplayName', sprintf('After ALA (RMS=%.3f)', rms_after));
    
    x_fit = linspace(min(V_res_after)*2, max(V_res_after)*2, 200);
    y_fit = normpdf(x_fit, mean(V_res_after), rms_after);
    scale_factor = cfg.N_pts * (bins(2) - bins(1));
    plot(x_fit, y_fit * scale_factor * 0.4, 'r--', 'LineWidth', 2.5, 'DisplayName', 'Gaussian Fit');
    
    xline(0, 'k:', 'LineWidth', 1.5, 'DisplayName', 'Zero');
    
    hold off;
    xlabel('Residual Voltage (LSB)', 'Interpreter', 'latex', 'FontSize', fs_axis);
    ylabel('Count', 'FontSize', fs_axis);
    title(sprintf('Dynamic Residual Distribution ($\\sigma_n=%.2f$, $N_{red}=%d$)', sigma_typ, N_red_typ), 'FontSize', fs_title, 'Interpreter', 'latex');
    legend_text = sprintf('RMS_{compression}=%.2f×', compression_ratio);
    legend('Location', 'best', 'FontSize', fs_legend);
    annotation('textbox', [0.65, 0.75, 0.25, 0.1], 'String', legend_text, 'FontSize', 13, 'Interpreter', 'latex', 'EdgeColor', 'k', 'FaceAlpha', 0.9);
    grid on;
    set(gca, 'FontSize', fs_axis-2);
    box on;
    
    saveas(gcf, fullfile(cfg.output_dir, 'Fig_4_Residual_PDF_Dynamic.png'));
    save_fig_eps(gcf, 'Fig_4_Residual_PDF_Dynamic');
    close(gcf);
    
    fprintf('    图表已保存至: %s\n', cfg.output_dir);
    
    %% ========================================================================
    % 步骤6: 生成分析报告
    %% ========================================================================
    fprintf('\n>>> [6/6] 生成分析报告...\n');
    
    date_str = datestr(now, 'yyyymmdd_HHMMSS');
    report_file = fullfile(cfg.output_dir, ['Report_SAR_Comparison_', date_str, '.txt']);
    fid = fopen(report_file, 'w');
    
    fprintf(fid, '================================================================================\n');
    fprintf(fid, '         SAR ADC 全链路动态行为级仿真报告 (JSSC风格)\n');
    fprintf(fid, '================================================================================\n\n');
    
    fprintf(fid, '【仿真配置】\n');
    fprintf(fid, '  ADC分辨率: %d-bit\n', cfg.ADC.N_bits);
    fprintf(fid, '  采样频率: %.2f MHz\n', cfg.Fs/1e6);
    fprintf(fid, '  FFT点数: %d\n', cfg.N_FFT);
    fprintf(fid, '  输入频率: %.2f Hz (相干采样 N_prime=%d)\n', f_in, N_prime);
    fprintf(fid, '  kT/C噪声: %.3f LSB\n', kTC_LSB);
    fprintf(fid, '  Thermal Limit: %.1f dB\n\n', SNDR_Thermal_Limit);
    
    fprintf(fid, '【PVT鲁棒性测试 - LUT错位分析】\n');
    fprintf(fid, '  LUT基准噪声: %.2f LSB\n', base_sigma);
    fprintf(fid, '  仿真噪声范围: %.2f - %.2f LSB\n\n', cfg.scan.sigma_range(1), cfg.scan.sigma_range(end));
    
    fprintf(fid, '【SNDR汇总 - N=24 (σ扫描)】\n');
    fprintf(fid, '%-10s %12s %12s %12s\n', 'Algorithm', 'Min SNDR', 'Max SNDR', 'Gain');
    fprintf(fid, '%-10s %12s %12s %12s\n', '------', '---------', '---------', '-----');
    
    for a = 1:num_algs
        min_sndr = min(results.sndr(a,:));
        max_sndr = max(results.sndr(a,:));
        gain = max_sndr - min_sndr;
        fprintf(fid, '%-10s %12.2f %12.2f %+12.2f\n', alg_names{a}, min_sndr, max_sndr, gain);
    end
    fprintf(fid, '%-10s %12.2f %12.2f %12s\n', 'Raw', min(results.sndr_raw), max(results.sndr_raw), '---');
    
    fprintf(fid, '\n【收敛效率 - σ=0.8】\n');
    for a = [3,4,5]
        sndr_N4 = results.sndr_fft(a, 1, i_sigma_fixed);
        sndr_N24 = results.sndr_fft(a, end, i_sigma_fixed);
        improvement = sndr_N24 - sndr_N4;
        fprintf(fid, '  %s: N=4→%.1f dB, N=24→%.1f dB, 改善: %.1f dB\n', alg_names{a}, sndr_N4, sndr_N24, improvement);
    end
    
    fprintf(fid, '\n【FFT 频谱分析 (σ=0.8, N=22)】\n');
    fprintf(fid, '  Raw SNDR: %.2f dB\n', sndr_raw_typ);
    fprintf(fid, '  ALA SNDR: %.2f dB\n', sndr_ala_typ);
    fprintf(fid, '  噪声底改善：+%.1f dB\n\n', floor_improvement);
    
    fprintf(fid, '【残差压缩分析】\n');
    fprintf(fid, '  原始残差RMS: %.3f LSB\n', rms_before);
    fprintf(fid, '  ALA处理后RMS: %.3f LSB\n', rms_after);
    fprintf(fid, '  RMS压缩比: %.2f×\n\n', compression_ratio);
    
    fprintf(fid, '================================================================================\n');
    fprintf(fid, '  运行信息\n');
    fprintf(fid, '================================================================================\n');
    fprintf(fid, '  MATLAB版本: %s\n', version);
    fprintf(fid, '  总耗时: %.2f 秒\n', toc);
    fprintf(fid, '  生成时间: %s\n', datestr(now));
    
    fclose(fid);
    
    data_file = fullfile(cfg.output_dir, 'Data_Dynamic_Results.mat');
    save(data_file, 'results', 'cfg');
    
    fprintf('    报告已保存: %s\n', report_file);
    fprintf('    数据已保存: %s\n', data_file);
    
    fprintf('\n>>> 完成！\n');
end

%% ========================================================================
% 辅助函数: 动态SAR量化
%% ========================================================================
function [D_out, V_res] = run_dynamic_sar_quantization(V_in, ADC, sigma_n)
    N_bits = ADC.N_bits;
    N_pts = length(V_in);
    V_ref = ADC.V_ref;
    V_LSB = 2 * V_ref / (2^N_bits);
    
    D_out = zeros(1, N_pts, 'int16');
    V_res = zeros(1, N_pts);
    
    for i = 1:N_pts
        V_dac = 0;
        D_code = 0;
        
        for bit = N_bits:-1:1
            LSB_weight = 2^(bit-1);
            comparator_noise_V = sigma_n * V_LSB * randn();
            
            if (V_in(i) - V_dac + comparator_noise_V) > 0
                D_code = D_code + LSB_weight;
                V_dac = V_dac + LSB_weight * V_LSB;
            else
                V_dac = V_dac - LSB_weight * V_LSB;
            end
        end
        
        D_out(i) = D_code - (2^(N_bits-1));
        V_res(i) = V_in(i) - V_dac;
    end
end

%% ========================================================================
% 辅助函数: FFT功率谱密度计算
%% ========================================================================
function [psd, freq] = compute_fft_psd(signal, Fs)
    N = length(signal);
    
    signal = signal - mean(signal);
    
    fft_result = fft(signal, N);
    psd = (abs(fft_result).^2) / N;
    psd = psd(1:N/2+1);
    psd(2:end-1) = 2 * psd(2:end-1);
    
    freq = (0:N/2) * Fs / N;
end

%% ========================================================================
% 辅助函数: 从PSD计算SNDR
%% ========================================================================
function sndr = compute_sndr_from_psd(psd, freq, f_signal)
    [~, idx_fund] = min(abs(freq - f_signal));
    
    fund_bin_width = 2;
    fund_bins = max(1, idx_fund-fund_bin_width):min(length(psd), idx_fund+fund_bin_width);
    fund_power = sum(psd(fund_bins));
    
    total_power = sum(psd);
    noise_power = total_power - fund_power;
    
    if noise_power > 0
        sndr = 10 * log10(fund_power / noise_power);
    else
        sndr = 100;
    end
    
    sndr = min(sndr, 120);
end

%% ========================================================================
% 辅助函数: 生成MLE查找表
%% ========================================================================
function LUT = generate_LUT_MLE(N_red, sigma)
    LUT = zeros(1, N_red + 1);
    for k = 0:N_red
        if k > 0 && k < N_red
            LUT(k+1) = sqrt(2) * sigma * erfinv(2*k/N_red - 1);
        else
            LUT(k+1) = 2.5 * sign(k - 0.5);
        end
    end
end

%% ========================================================================
% 辅助函数: 生成BE查找表
%% ========================================================================
function LUT = generate_LUT_BE(N_red, sigma)
    v_grid = linspace(-10*sigma, 10*sigma, 5000);
    dv = v_grid(2) - v_grid(1);
    prior = exp(-0.5 * (v_grid / sigma).^2);
    LUT = zeros(1, N_red + 1);
    
    for k = 0:N_red
        p_v = 0.5 * (1 + erf(v_grid / (sqrt(2) * sigma)));
        likelihood = (p_v.^k) .* ((1 - p_v).^(N_red - k));
        posterior = likelihood .* prior;
        if sum(posterior) > 1e-100
            LUT(k+1) = sum(v_grid .* posterior .* dv) / sum(posterior .* dv);
        else
            LUT(k+1) = generate_LUT_MLE(N_red, sigma);
        end
    end
end
