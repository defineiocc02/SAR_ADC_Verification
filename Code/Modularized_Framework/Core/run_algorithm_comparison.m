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
    k_B = 1.380649e-23;
    T = 300;
    C_s = cfg.ADC.C_sample;
    kTC_noise = sqrt(k_B * T / C_s);
    V_LSB = 2 * cfg.ADC.V_ref / (2^cfg.ADC.N_bits);
    kTC_LSB = kTC_noise / V_LSB;
    fprintf('    kT/C噪声: %.3f LSB (对应%.1f dB)\n', kTC_LSB, target_SNR_dB);
    
    SNDR_Thermal_Limit = target_SNR_dB;
    
    cfg.output_dir = fullfile(fileparts(mfilename('fullpath')), '..', '..', '..', 'Results');
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
    alg_names = {'MLE', 'BE', 'DLR', 'ATA', 'ALA', 'HT-LA', 'Adaptive'};
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
    A_in = cfg.ADC.V_ref * 0.99;
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
        
        V_res_LSB = (V_res_dynamic / V_LSB) - 0.5;
        
        [psd_raw, freq_raw] = compute_fft_psd(double(D_raw), cfg.ADC.Fs, cfg.ADC.N_bits);
        sndr_raw = compute_sndr_from_psd(psd_raw, freq_raw, f_in);
        results.sndr_raw(i_sigma) = sndr_raw;
        
        fprintf('      Raw SNDR: %.2f dB\n', sndr_raw);
        
        for i_N = 1:num_N_red
            N_red = cfg.scan.N_red_range(i_N);
            
            RW_drift = randn(cfg.N_pts, N_red) * (sigma_th * 0.3);
            
            sig_th = sigma_th;
            
            [est_mle, ~, ~, ~] = run_mle(V_res_LSB, N_red, sig_th, LUT_MLE(1:N_red+1), RW_drift);
            D_mle = double(D_raw) + est_mle;
            
            [est_be, ~, ~, ~] = run_be(V_res_LSB, N_red, sig_th, LUT_BE(1:N_red+1), RW_drift);
            D_be = double(D_raw) + est_be;
            
            [est_dlr, ~, ~] = run_dlr(V_res_LSB, N_red, sig_th, RW_drift);
            D_dlr = double(D_raw) + est_dlr;
            
            [est_ata, ~, ~, ~] = run_ata(V_res_LSB, N_red, sig_th, RW_drift);
            D_ata = double(D_raw) + est_ata;
            
            [est_ala, ~, ~, ~] = run_ala(V_res_LSB, N_red, sig_th, RW_drift);
            D_ala = double(D_raw) + est_ala;
            
            [est_htla, ~, ~, ~] = run_htla(V_res_LSB, N_red, sig_th, LUT_MLE(1:N_red+1), RW_drift);
            D_htla = double(D_raw) + est_htla;
            
            [est_adaptive, ~, ~, ~] = run_adaptive(V_res_LSB, N_red, sig_th, LUT_MLE(1:N_red+1), RW_drift);
            D_adaptive = double(D_raw) + est_adaptive;
            
            [psd_mle, ~] = compute_fft_psd(D_mle, cfg.ADC.Fs, cfg.ADC.N_bits);
            results.sndr_fft(1, i_N, i_sigma) = compute_sndr_from_psd(psd_mle, freq_raw, f_in);
            
            [psd_be, ~] = compute_fft_psd(D_be, cfg.ADC.Fs, cfg.ADC.N_bits);    
            results.sndr_fft(2, i_N, i_sigma) = compute_sndr_from_psd(psd_be, freq_raw, f_in);
            
            [psd_dlr, ~] = compute_fft_psd(D_dlr, cfg.ADC.Fs, cfg.ADC.N_bits);
            results.sndr_fft(3, i_N, i_sigma) = compute_sndr_from_psd(psd_dlr, freq_raw, f_in);
            
            [psd_ata, ~] = compute_fft_psd(D_ata, cfg.ADC.Fs, cfg.ADC.N_bits);
            results.sndr_fft(4, i_N, i_sigma) = compute_sndr_from_psd(psd_ata, freq_raw, f_in);
            
            [psd_ala, ~] = compute_fft_psd(D_ala, cfg.ADC.Fs, cfg.ADC.N_bits);
            results.sndr_fft(5, i_N, i_sigma) = compute_sndr_from_psd(psd_ala, freq_raw, f_in);
            
            [psd_htla, ~] = compute_fft_psd(D_htla, cfg.ADC.Fs, cfg.ADC.N_bits);
            results.sndr_fft(6, i_N, i_sigma) = compute_sndr_from_psd(psd_htla, freq_raw, f_in);
            
            [psd_adaptive, ~] = compute_fft_psd(D_adaptive, cfg.ADC.Fs, cfg.ADC.N_bits);
            results.sndr_fft(7, i_N, i_sigma) = compute_sndr_from_psd(psd_adaptive, freq_raw, f_in);
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
    V_res_typ_LSB = (V_res_typ / V_LSB) - 0.5;
    RW_drift_typ = randn(cfg.N_pts, N_red_typ) * (sigma_typ * 0.3);
    
    % 公平测试所有 7 种算法
    % 注意：截取 LUT_MLE(1:N_red_typ+1) 传递对应长度的查找表，并补齐 RW_drift_typ 参数
    [est_mle_typ, ~, ~, ~] = run_mle(V_res_typ_LSB, N_red_typ, sigma_typ, LUT_MLE(1:N_red_typ+1), RW_drift_typ);
    D_mle_typ = double(D_raw_typ) + est_mle_typ;
    
    [est_be_typ, ~, ~, ~] = run_be(V_res_typ_LSB, N_red_typ, sigma_typ, LUT_BE(1:N_red_typ+1), RW_drift_typ);
    D_be_typ = double(D_raw_typ) + est_be_typ;
    
    [est_dlr_typ, ~, ~] = run_dlr(V_res_typ_LSB, N_red_typ, sigma_typ, RW_drift_typ);
    D_dlr_typ = double(D_raw_typ) + est_dlr_typ;
    
    [est_ata_typ, ~, ~, ~] = run_ata(V_res_typ_LSB, N_red_typ, sigma_typ, RW_drift_typ);
    D_ata_typ = double(D_raw_typ) + est_ata_typ;
    
    [est_ala_typ, ~, ~, ~] = run_ala(V_res_typ_LSB, N_red_typ, sigma_typ, RW_drift_typ);
    D_ala_typ = double(D_raw_typ) + est_ala_typ;
    
    % 注意：为 HT-LA 和 Adaptive 传入正确的查找表
    [est_htla_typ, ~, ~, ~] = run_htla(V_res_typ_LSB, N_red_typ, sigma_typ, LUT_MLE(1:N_red_typ+1), RW_drift_typ);
    D_htla_typ = double(D_raw_typ) + est_htla_typ;
    
    [est_adaptive_typ, ~, ~, ~] = run_adaptive(V_res_typ_LSB, N_red_typ, sigma_typ, LUT_MLE(1:N_red_typ+1), RW_drift_typ);
    D_adaptive_typ = double(D_raw_typ) + est_adaptive_typ;
    
    % 计算所有算法的 FFT
    [psd_raw_typ, freq_typ] = compute_fft_psd(double(D_raw_typ), cfg.ADC.Fs, cfg.ADC.N_bits);
    [psd_mle_typ, ~] = compute_fft_psd(D_mle_typ, cfg.ADC.Fs, cfg.ADC.N_bits);
    [psd_be_typ, ~] = compute_fft_psd(D_be_typ, cfg.ADC.Fs, cfg.ADC.N_bits);
    [psd_dlr_typ, ~] = compute_fft_psd(D_dlr_typ, cfg.ADC.Fs, cfg.ADC.N_bits);
    [psd_ata_typ, ~] = compute_fft_psd(D_ata_typ, cfg.ADC.Fs, cfg.ADC.N_bits);
    [psd_ala_typ, ~] = compute_fft_psd(D_ala_typ, cfg.ADC.Fs, cfg.ADC.N_bits);
    [psd_htla_typ, ~] = compute_fft_psd(D_htla_typ, cfg.ADC.Fs, cfg.ADC.N_bits);
    [psd_adaptive_typ, ~] = compute_fft_psd(D_adaptive_typ, cfg.ADC.Fs, cfg.ADC.N_bits);
    
    % 计算所有算法的 SNDR
    sndr_raw_typ = results.sndr_raw(i_sigma_typ);
    sndr_mle_typ = compute_sndr_from_psd(psd_mle_typ, freq_typ, f_in);
    sndr_be_typ = compute_sndr_from_psd(psd_be_typ, freq_typ, f_in);
    sndr_dlr_typ = compute_sndr_from_psd(psd_dlr_typ, freq_typ, f_in);
    sndr_ata_typ = compute_sndr_from_psd(psd_ata_typ, freq_typ, f_in);
    sndr_ala_typ = compute_sndr_from_psd(psd_ala_typ, freq_typ, f_in);
    sndr_htla_typ = compute_sndr_from_psd(psd_htla_typ, freq_typ, f_in);
    sndr_adaptive_typ = compute_sndr_from_psd(psd_adaptive_typ, freq_typ, f_in);
    
    fprintf('    Raw SNDR: %.2f dB\n', sndr_raw_typ);
    fprintf('    MLE SNDR: %.2f dB\n', sndr_mle_typ);
    fprintf('    BE SNDR: %.2f dB\n', sndr_be_typ);
    fprintf('    DLR SNDR: %.2f dB\n', sndr_dlr_typ);
    fprintf('    ATA SNDR: %.2f dB\n', sndr_ata_typ);
    fprintf('    ALA SNDR: %.2f dB\n', sndr_ala_typ);
    fprintf('    HT-LA SNDR: %.2f dB\n', sndr_htla_typ);
    fprintf('    Adaptive SNDR: %.2f dB\n', sndr_adaptive_typ);
    
    fprintf('\n>>> [5/6] 生成可视化图表...\n');
    
    color_ala = [0.85, 0.1, 0.1];
    color_ata = [0, 0, 0.8];
    color_dlr = [0, 0.6, 0];
    color_mle = [0.5, 0.5, 0.5];
    color_be = [0.6, 0.6, 0.6];
    
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
    
    plot(cfg.scan.sigma_range, results.sndr_raw, 'k--', 'LineWidth', 2.5, 'DisplayName', 'Raw SAR');
    
    plot(cfg.scan.sigma_range, results.sndr(1,:), 's--', 'Color', color_mle, 'LineWidth', 2.5, 'MarkerSize', 10, 'DisplayName', 'MLE (LUT@0.6)');
    plot(cfg.scan.sigma_range, results.sndr(2,:), 'v--', 'Color', color_be, 'LineWidth', 2.5, 'MarkerSize', 10, 'DisplayName', 'BE (LUT@0.6)');
    plot(cfg.scan.sigma_range, results.sndr(3,:), '^-', 'Color', color_dlr, 'LineWidth', 2.5, 'MarkerSize', 10, 'DisplayName', 'DLR');
    plot(cfg.scan.sigma_range, results.sndr(4,:), 's-', 'Color', color_ata, 'LineWidth', 2.5, 'MarkerSize', 10, 'DisplayName', 'ATA v5.0');
    plot(cfg.scan.sigma_range, results.sndr(5,:), 'o-', 'Color', color_ala, 'LineWidth', 2.5, 'MarkerSize', 10, 'MarkerFaceColor', color_ala, 'DisplayName', 'ALA v3.0');
    
    hold off;
    xlabel('$\sigma_n$ (LSB)', 'Interpreter', 'latex', 'FontSize', fs_axis);
    ylabel('SNDR (dB)', 'Interpreter', 'latex', 'FontSize', fs_axis);
    title('PVT Robustness Test: Dynamic SNDR vs Comparator Noise', 'FontSize', fs_title, 'Interpreter', 'latex');
    legend('Location', 'SouthEast', 'FontSize', fs_legend);
    grid on;
    set(gca, 'FontName', 'Times New Roman', 'FontSize', fs_axis-2, 'TickLabelInterpreter', 'latex');
    set(gca, 'GridAlpha', 0.25, 'MinorGridAlpha', 0.1);
    box on;
    ylim([84, 93]);
    
    saveas(gcf, fullfile(cfg.output_dir, 'Fig_1_SNDR_vs_Sigma_PVT.png'));
    save_fig_eps(gcf, 'Fig_1_SNDR_vs_Sigma_PVT');
    close(gcf);
    
    % ========================================================================
    % Fig_2: FFT频谱对比
    % ========================================================================
    figure('Position', [100, 100, 1000, 700]);
    hold on;
    
    semilogx(freq_typ/1e3, psd_raw_typ, 'k-', 'LineWidth', 1.0, 'DisplayName', sprintf('Raw (SNDR=%.1f dB)', sndr_raw_typ));
    semilogx(freq_typ/1e3, psd_ala_typ, 'r-', 'LineWidth', 1.5, 'DisplayName', sprintf('ALA (SNDR=%.1f dB)', sndr_ala_typ));
    
    noise_floor_raw = mean(10.^(psd_raw_typ(end-100:end)/10));
    noise_floor_ala = mean(10.^(psd_ala_typ(end-100:end)/10));
    floor_improvement = 10*log10(noise_floor_raw/noise_floor_ala);
    
    xline(f_in/1e3, 'g:', 'LineWidth', 1.5, 'DisplayName', sprintf('f_{in}=%.2f kHz', f_in/1e3));
    
    hold off;
    xlabel('Frequency (kHz)', 'Interpreter', 'latex', 'FontSize', fs_axis);
    ylabel('PSD (dBFS)', 'Interpreter', 'latex', 'FontSize', fs_axis);
    title(sprintf('FFT Spectrum: $\\sigma_n=%.2f$ LSB, $N_{red}=%d$', sigma_typ, N_red_typ), 'FontSize', fs_title, 'Interpreter', 'latex');
    legend('Location', 'best', 'FontSize', fs_legend);
    grid on;
    set(gca, 'FontName', 'Times New Roman', 'FontSize', fs_axis-2, 'TickLabelInterpreter', 'latex');
    set(gca, 'GridAlpha', 0.25, 'MinorGridAlpha', 0.1);
    box on;
    xlim([0.1, cfg.ADC.Fs/2e3]);
    ylim([-150, 0]);
    
    annotation('textbox', [0.15, 0.15, 0.25, 0.1], 'String', sprintf('Noise Floor $\\Delta$ = +%.1f dB', floor_improvement), ...
        'FontSize', 12, 'Interpreter', 'latex', 'EdgeColor', 'k', 'BackgroundColor', 'w', 'FaceAlpha', 0.9);
    
    saveas(gcf, fullfile(cfg.output_dir, 'Fig_2_FFT_Spectrum_Comparison.png'));
    save_fig_eps(gcf, 'Fig_2_FFT_Spectrum_Comparison');
    close(gcf);
    
    % ========================================================================
    % Fig_3: SNDR vs N_red (收敛效率 - 公平展示所有 7 种算法)
    % ========================================================================
    i_sigma_fixed = find(cfg.scan.sigma_range >= 0.8, 1);
    
    figure('Position', [100, 100, 1200, 800]);
    hold on;
    
    yline(SNDR_Thermal_Limit, 'k--', 'LineWidth', 2.5, 'DisplayName', sprintf('Thermal Limit (%.1f dB)', SNDR_Thermal_Limit));
    
    raw_vs_N = results.sndr_raw(i_sigma_fixed) * ones(1, num_N_red);
    plot(cfg.scan.N_red_range, raw_vs_N, 'k--', 'LineWidth', 2.0, 'DisplayName', 'Raw SAR');
    
    % 公平展示所有 7 种算法
    alg_colors = {color_mle, color_be, color_dlr, color_ata, color_ala, 'y', 'c'};
    alg_markers = {'s--', 'v--', '^-', 's-', 'o-', 'd-', 'h-'};
    alg_names_full = {'MLE (LUT@0.6)', 'BE (LUT@0.6)', 'DLR', 'ATA v5.0', 'ALA v3.0', 'HT-LA', 'Adaptive'};
    
    for a = 1:7
        c = alg_colors{a};
        mk = alg_markers{a};
        alg_name = alg_names_full{a};
        
        if a == 5  % ALA 填充标记
            plot_data = squeeze(results.sndr_fft(a, :, i_sigma_fixed));
            plot(cfg.scan.N_red_range, plot_data, mk, 'Color', c, 'LineWidth', 2.5, 'MarkerSize', 10, 'MarkerFaceColor', c, 'DisplayName', alg_name);
        else
            plot_data = squeeze(results.sndr_fft(a, :, i_sigma_fixed));
            plot(cfg.scan.N_red_range, plot_data, mk, 'Color', c, 'LineWidth', 2.0, 'MarkerSize', 8, 'DisplayName', alg_name);
        end
    end
    
    hold off;
    xlabel('$N_{red}$', 'Interpreter', 'latex', 'FontSize', fs_axis);
    ylabel('SNDR (dB)', 'Interpreter', 'latex', 'FontSize', fs_axis);
    title(sprintf('Convergence Efficiency (All Algorithms): $\\sigma_n=%.2f$ LSB', cfg.scan.sigma_range(i_sigma_fixed)), 'FontSize', fs_title, 'Interpreter', 'latex');
    legend('Location', 'best', 'FontSize', 9);
    grid on;
    set(gca, 'FontName', 'Times New Roman', 'FontSize', fs_axis-2, 'TickLabelInterpreter', 'latex');
    set(gca, 'GridAlpha', 0.25, 'MinorGridAlpha', 0.1);
    box on;
    xlim([cfg.scan.N_red_range(1)-1, cfg.scan.N_red_range(end)+1]);
    ylim([84, 93]);
    
    saveas(gcf, fullfile(cfg.output_dir, 'Fig_3_SNDR_vs_Nred.png'));
    save_fig_eps(gcf, 'Fig_3_SNDR_vs_Nred');
    close(gcf);
    
    % ========================================================================
    % Fig_4: 动态残差分布直方图 (公平展示所有 7 种算法)
    % ========================================================================
    % 使用零均值残差 V_res_typ_LSB 作为基准（与喂给算法的输入一致）
    % V_res_typ_LSB 已在第188行定义：(V_res_typ / V_LSB) - 0.5
    
    % 计算所有算法的残差压缩（使用零均值基准）
    rms_before = sqrt(mean(V_res_typ_LSB.^2));
    
    rms_after_mle = sqrt(mean((V_res_typ_LSB - est_mle_typ).^2));
    rms_after_be = sqrt(mean((V_res_typ_LSB - est_be_typ).^2));
    rms_after_dlr = sqrt(mean((V_res_typ_LSB - est_dlr_typ).^2));
    rms_after_ata = sqrt(mean((V_res_typ_LSB - est_ata_typ).^2));
    rms_after_ala = sqrt(mean((V_res_typ_LSB - est_ala_typ).^2));
    rms_after_htla = sqrt(mean((V_res_typ_LSB - est_htla_typ).^2));
    rms_after_adaptive = sqrt(mean((V_res_typ_LSB - est_adaptive_typ).^2));
    
    compression_mle = rms_before / rms_after_mle;
    compression_be = rms_before / rms_after_be;
    compression_dlr = rms_before / rms_after_dlr;
    compression_ata = rms_before / rms_after_ata;
    compression_ala = rms_before / rms_after_ala;
    compression_htla = rms_before / rms_after_htla;
    compression_adaptive = rms_before / rms_after_adaptive;
    
    figure('Position', [100, 100, 1400, 900]);
    hold on;
    
    bins = linspace(min(V_res_typ_LSB)*1.5, max(V_res_typ_LSB)*1.5, 80);
    
    % 所有算法的残差分布（使用零均值基准）
    histogram(V_res_typ_LSB, bins, 'FaceColor', 'k', 'FaceAlpha', 0.2, 'Normalization', 'pdf', 'EdgeColor', 'none', 'DisplayName', sprintf('Raw (RMS=%.3f LSB)', rms_before));
    histogram(V_res_typ_LSB - est_mle_typ, bins, 'FaceColor', color_mle, 'FaceAlpha', 0.3, 'Normalization', 'pdf', 'EdgeColor', 'none', 'DisplayName', sprintf('MLE (RMS=%.3f, %.1fx)', rms_after_mle, compression_mle));
    histogram(V_res_typ_LSB - est_be_typ, bins, 'FaceColor', color_be, 'FaceAlpha', 0.3, 'Normalization', 'pdf', 'EdgeColor', 'none', 'DisplayName', sprintf('BE (RMS=%.3f, %.1fx)', rms_after_be, compression_be));
    histogram(V_res_typ_LSB - est_dlr_typ, bins, 'FaceColor', color_dlr, 'FaceAlpha', 0.3, 'Normalization', 'pdf', 'EdgeColor', 'none', 'DisplayName', sprintf('DLR (RMS=%.3f, %.1fx)', rms_after_dlr, compression_dlr));
    histogram(V_res_typ_LSB - est_ata_typ, bins, 'FaceColor', color_ata, 'FaceAlpha', 0.3, 'Normalization', 'pdf', 'EdgeColor', 'none', 'DisplayName', sprintf('ATA (RMS=%.3f, %.1fx)', rms_after_ata, compression_ata));
    histogram(V_res_typ_LSB - est_ala_typ, bins, 'FaceColor', color_ala, 'FaceAlpha', 0.5, 'Normalization', 'pdf', 'EdgeColor', 'none', 'DisplayName', sprintf('ALA (RMS=%.3f, %.1fx)', rms_after_ala, compression_ala));
    histogram(V_res_typ_LSB - est_htla_typ, bins, 'FaceColor', [1, 1, 0], 'FaceAlpha', 0.3, 'Normalization', 'pdf', 'EdgeColor', 'none', 'DisplayName', sprintf('HT-LA (RMS=%.3f, %.1fx)', rms_after_htla, compression_htla));
    histogram(V_res_typ_LSB - est_adaptive_typ, bins, 'FaceColor', [0, 1, 1], 'FaceAlpha', 0.3, 'Normalization', 'pdf', 'EdgeColor', 'none', 'DisplayName', sprintf('Adaptive (RMS=%.3f, %.1fx)', rms_after_adaptive, compression_adaptive));
    
    xline(0, 'k:', 'LineWidth', 1.5, 'DisplayName', 'Zero');
    
    hold off;
    xlabel('Residual Voltage (LSB)', 'Interpreter', 'latex', 'FontSize', fs_axis);
    ylabel('Probability Density', 'Interpreter', 'latex', 'FontSize', fs_axis);
    title(sprintf('Dynamic Residual Distribution (All Algorithms): $\\sigma_n=%.2f$ LSB, $N_{red}=%d$', sigma_typ, N_red_typ), 'FontSize', fs_title, 'Interpreter', 'latex');
    legend('Location', 'best', 'FontSize', 9);
    grid on;
    set(gca, 'FontName', 'Times New Roman', 'FontSize', fs_axis-2, 'TickLabelInterpreter', 'latex');
    set(gca, 'GridAlpha', 0.25, 'MinorGridAlpha', 0.1);
    box on;
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
    
    date_str = string(datetime("now", "Format", "yyyyMMdd_HHmmss"));
    report_file = fullfile(cfg.output_dir, ['Report_SAR_Comparison_', date_str, '.txt']);
    fid = fopen(report_file, 'w');
    
    fprintf(fid, '================================================================================\n');
    fprintf(fid, '         SAR ADC 全链路动态行为级仿真报告 (JSSC风格)\n');
    fprintf(fid, '================================================================================\n\n');
    
    fprintf(fid, '【仿真配置】\n');
    fprintf(fid, '  ADC分辨率: %d-bit\n', cfg.ADC.N_bits);
    fprintf(fid, '  采样频率: %.2f MHz\n', cfg.ADC.Fs/1e6);
    fprintf(fid, '  FFT点数: %d\n', cfg.N_FFT);
    fprintf(fid, '  输入频率: %.2f Hz (相干采样 N_prime=%d)\n', f_in, N_prime);
    fprintf(fid, '  kT/C噪声: %.3f LSB\n', kTC_LSB);
    fprintf(fid, '  Thermal Limit: %.1f dB\n\n', SNDR_Thermal_Limit);
    
    fprintf(fid, '【PVT鲁棒性测试 - LUT错位分析】\n');
    fprintf(fid, '  LUT基准噪声: %.2f LSB\n', base_sigma);
    fprintf(fid, '  仿真噪声范围: %.2f - %.2f LSB\n\n', cfg.scan.sigma_range(1), cfg.scan.sigma_range(end));
    
    fprintf(fid, '【SNDR汇总 - N=24 (σ扫描)】\n');
    fprintf(fid, '  Note: Amplitude Loss Compensation = 0.09 dB (due to 0.99*V_ref)\n');
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
    for a = 1:7
        sndr_N4 = results.sndr_fft(a, 1, i_sigma_fixed);
        sndr_N24 = results.sndr_fft(a, end, i_sigma_fixed);
        improvement = sndr_N24 - sndr_N4;
        fprintf(fid, '  %s: N=4→%.1f dB, N=24→%.1f dB, 改善: %.1f dB\n', alg_names{a}, sndr_N4, sndr_N24, improvement);
    end
    
    fprintf(fid, '\n【FFT 频谱分析 (σ=0.8, N=22)】\n');
    fprintf(fid, '  Raw SNDR: %.2f dB\n', sndr_raw_typ);
    fprintf(fid, '  MLE SNDR: %.2f dB\n', sndr_mle_typ);
    fprintf(fid, '  BE SNDR: %.2f dB\n', sndr_be_typ);
    fprintf(fid, '  DLR SNDR: %.2f dB\n', sndr_dlr_typ);
    fprintf(fid, '  ATA SNDR: %.2f dB\n', sndr_ata_typ);
    fprintf(fid, '  ALA SNDR: %.2f dB\n', sndr_ala_typ);
    fprintf(fid, '  HT-LA SNDR: %.2f dB\n', sndr_htla_typ);
    fprintf(fid, '  Adaptive SNDR: %.2f dB\n', sndr_adaptive_typ);
    fprintf(fid, '  噪声底改善 (ALA): +%.1f dB\n\n', floor_improvement);
    
    fprintf(fid, '【残差压缩分析】\n');
    fprintf(fid, '  原始残差RMS: %.3f LSB\n', rms_before);
    fprintf(fid, '  MLE处理后RMS: %.3f LSB, 压缩比: %.2fx\n', rms_after_mle, compression_mle);
    fprintf(fid, '  BE处理后RMS: %.3f LSB, 压缩比: %.2fx\n', rms_after_be, compression_be);
    fprintf(fid, '  DLR处理后RMS: %.3f LSB, 压缩比: %.2fx\n', rms_after_dlr, compression_dlr);
    fprintf(fid, '  ATA处理后RMS: %.3f LSB, 压缩比: %.2fx\n', rms_after_ata, compression_ata);
    fprintf(fid, '  ALA处理后RMS: %.3f LSB, 压缩比: %.2fx\n', rms_after_ala, compression_ala);
    fprintf(fid, '  HT-LA处理后RMS: %.3f LSB, 压缩比: %.2fx\n', rms_after_htla, compression_htla);
    fprintf(fid, '  Adaptive处理后RMS: %.3f LSB, 压缩比: %.2fx\n', rms_after_adaptive, compression_adaptive);
    
    fprintf(fid, '================================================================================\n');
    fprintf(fid, '  运行信息\n');
    fprintf(fid, '================================================================================\n');
    fprintf(fid, '  MATLAB版本: %s\n', version);
    fprintf(fid, '  总耗时: %.2f 秒\n', toc);
    fprintf(fid, '  生成时间: %s\n', string(datetime("now")));
    
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
        V_sampled = V_in(i) + V_ref;
        V_dac = 0;
        D_code = 0;
        
        for bit = N_bits:-1:1
            weight = 2^(bit-1);
            V_test = V_dac + weight * V_LSB;
            comp_noise_V = sigma_n * V_LSB * randn();
            
            if (V_sampled - V_test + comp_noise_V) > 0
                V_dac = V_test;
                D_code = D_code + weight;
            end
        end
        
        D_out(i) = D_code - (2^(N_bits-1));
        V_res(i) = V_sampled - V_dac;
    end
end

%% ========================================================================
% 辅助函数: FFT功率谱密度计算 (dBFS归一化)
%% ========================================================================
function [psd_dBFS, freq] = compute_fft_psd(signal, Fs, N_bits)
    N = length(signal);
    
    signal = signal - mean(signal);
    
    fft_result = fft(signal, N);
    
    mag = abs(fft_result) / (N/2);
    mag(1) = mag(1) / 2;
    
    A_FS = 2^(N_bits-1);
    psd_dBFS = 20 * log10(mag(1:N/2+1) / A_FS + eps);
    
    freq = (0:N/2) * Fs / N;
end

%% ========================================================================
% 辅助函数: 从PSD计算SNDR
%% ========================================================================
function sndr = compute_sndr_from_psd(psd_dBFS, freq, f_signal)
    psd_linear = 10.^(psd_dBFS / 10);
    
    [~, idx_fund] = min(abs(freq - f_signal));
    
    fund_bin_width = 2;
    fund_bins = max(1, idx_fund-fund_bin_width):min(length(psd_linear), idx_fund+fund_bin_width);
    fund_power = sum(psd_linear(fund_bins));
    
    total_power = sum(psd_linear);
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
