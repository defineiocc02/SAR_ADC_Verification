% =========================================================================
% Clean Baseline Verification - 纯净物理环境验证框架
% 目标：测试7种残差估计算法在理想环境下的理论SNDR上限和基础功耗
% =========================================================================

clear; clc; close all;

%% ========================================================================
%% 0. 项目路径配置 (规范化输出路径)
%% ========================================================================
PROJECT_ROOT = fileparts(fileparts(fileparts(mfilename('fullpath'))));
if isempty(PROJECT_ROOT)
    PROJECT_ROOT = pwd;
end
RESULTS_DIR = fullfile(PROJECT_ROOT, 'Results');
FIGURES_DIR = fullfile(RESULTS_DIR, 'Figures_Clean');
REPORTS_DIR = fullfile(RESULTS_DIR, 'Reports');
LATEX_DIR = fullfile(RESULTS_DIR, 'LaTeX');

if ~exist(FIGURES_DIR, 'dir'), mkdir(FIGURES_DIR); end
if ~exist(REPORTS_DIR, 'dir'), mkdir(REPORTS_DIR); end
if ~exist(LATEX_DIR, 'dir'), mkdir(LATEX_DIR); end

fprintf('======================================================================\n');
fprintf('  CLEAN BASELINE VERIFICATION FRAMEWORK\n');
fprintf('  纯净物理环境验证 - 理论性能上限测试\n');
fprintf('======================================================================\n\n');

% ----------------------------------------------------------------------------
% 1. 学术级图表规范设置
% ----------------------------------------------------------------------------
set(0, 'DefaultAxesFontName', 'Times New Roman');
set(0, 'DefaultTextFontName', 'Times New Roman');
set(0, 'DefaultAxesFontSize', 14);
set(0, 'DefaultLineLineWidth', 2.0);
set(0, 'DefaultAxesLineWidth', 1.5);
set(0, 'DefaultAxesBox', 'on');

% IEEE经典调色板
COLOR = struct();
COLOR.mle    = [0.20, 0.40, 0.80];
COLOR.be     = [0.58, 0.40, 0.74];
COLOR.dlr    = [0.50, 0.50, 0.50];
COLOR.ata    = [0.40, 0.20, 0.60];
COLOR.ala    = [0.90, 0.50, 0.10];
COLOR.htla   = [0.85, 0.15, 0.15];
COLOR.adapt  = [0.15, 0.60, 0.30];

ALG_NAMES = {'MLE', 'BE', 'DLR', 'ATA', 'ALA', 'HTLA', 'Adapt'};

%% ========================================================================
%% 2. 核心参数配置 - 纯净物理环境
%% ========================================================================

fprintf('>>> [1/4] 初始化纯净物理环境参数...\n');

% SAR ADC 核心规格
ADC = struct();
ADC.N_main    = 16;
ADC.N_red     = 22;
ADC.V_ref     = 3.3;
ADC.V_fs      = 2 * ADC.V_ref;
ADC.LSB       = ADC.V_fs / (2^ADC.N_main);
ADC.Fs        = 5e6;

% Split Sampling 参数
SS = struct();
SS.Cs         = 20e-12;
SS.CDAC       = 1e-12;
kB = 1.380649e-23;
Temp = 300;
SS.ktc_ss_rms = sqrt(2*kB*Temp/SS.Cs);
SS.ktc_dac_rms = sqrt(2*kB*Temp/SS.CDAC);

% 噪声参数 - 保留热噪声和kT/C噪声
Noise = struct();
Noise.kT_C_LSB   = 22.2e-6 / ADC.LSB;
Noise.comp_th_LSB = 59.1e-6 / ADC.LSB;
base_sigma_n = Noise.comp_th_LSB;

% 纯净环境：关闭所有非理想因素
Mismatch = struct();
Mismatch.sigma_C_Cu = 0.0;  % 关闭电容失配

Drift = struct();
Drift.rho         = 0;
Drift.sigma_drift = 0;  % 关闭动态漂移
Drift.sys_offset  = 0;  % 关闭系统失调
Drift.V_droop_max = 0;  % 关闭电压下垂

% 仿真参数 - 精简配置
N_MC        = 10;       % 减少MC次数
offset_swp  = 0;        % 单点理想状态
num_offsets = 1;
seed_start  = 2026;

% FFT参数
FFT = struct();
FFT.N_points = 4096;
FFT.J_large = 83;
FFT.Fin = FFT.J_large * ADC.Fs / FFT.N_points;

%% ========================================================================
%% 3. 生成微表 (LUT)
%% ========================================================================

fprintf('>>> [2/4] 生成微表 (LUT)...\n');

% MLE LUT
k_vec = 0:ADC.N_red;
LUT_MLE = sqrt(pi/2) * base_sigma_n * (2*k_vec/ADC.N_red - 1);

% BE LUT (Bayesian Shrinkage)
LUT_BE = zeros(1, ADC.N_red+1);
for k = 0:ADC.N_red
    n = ADC.N_red;
    w = (1 + base_sigma_n^2)^(-1);
    y = (2*k/n) - 1;
    LUT_BE(k+1) = sqrt(pi/2) * base_sigma_n * w * y;
end

% HTLA LUT (6-bit)
bits = 6;
n_levels = 2^bits - 1;
LUT_HTLA = zeros(n_levels, ADC.N_red+1);
for n_avg = 1:n_levels
    for k = 0:ADC.N_red
        y = (2*k/max(n_avg,1)) - 1;
        V_lin = sqrt(pi/2) * base_sigma_n * y;
        LUT_HTLA(n_avg, k+1) = -0.15 * V_lin * exp(-n_avg/8);
    end
end

%% ========================================================================
%% 4. 蒙特卡洛仿真
%% ========================================================================

fprintf('>>> [3/4] 执行蒙特卡洛仿真 (N_MC = %d)...\n', N_MC);

num_algs = 7;
res_sndr = zeros(num_algs, N_MC);
res_rmse = zeros(num_algs, N_MC);
res_pwr  = zeros(num_algs, N_MC);

error_samples = cell(num_algs, 1);

wb = waitbar(0, 'Monte Carlo Simulation Progress...');

for mc = 1:N_MC
    rng(seed_start + mc);
    
    % 生成输入信号
    t = (0:FFT.N_points-1)' / ADC.Fs;
    V_in_diff = 0.94 * ADC.V_ref * sin(2*pi*FFT.Fin*t);
    
    % 理想权重（无失配）
    weights_real = ADC.V_ref ./ (2.^(1:ADC.N_main));
    
    % SAR量化
    [V_dac, V_res_analog, comp_matrix] = run_main_SAR_core(V_in_diff', ADC, Noise, weights_real, FFT.N_points, 0);
    D_out_decimal = sum(comp_matrix .* (2.^(ADC.N_main - (1:ADC.N_main)')), 1);
    V_out_base = (D_out_decimal - 2^(ADC.N_main-1) + 0.5) * ADC.LSB;
    
    % 纯净环境：无漂移
    RW_drift = zeros(FFT.N_points, ADC.N_red);
    V_res_TARGET = V_res_analog / ADC.LSB;
    
    % 运行7种算法
    [e_mle, pwr_mle, ~, ~] = run_redundant_array_RW(V_res_TARGET, ADC.N_red, base_sigma_n, 'MLE', LUT_MLE, ADC, RW_drift);
    [e_be,  pwr_be,  ~, ~] = run_redundant_array_RW(V_res_TARGET, ADC.N_red, base_sigma_n, 'BE', LUT_BE, ADC, RW_drift);
    [e_dlr, pwr_dlr, ~, ~] = run_redundant_array_RW(V_res_TARGET, ADC.N_red, base_sigma_n, 'DLR', [], ADC, RW_drift);
    [e_ata, pwr_ata, ~, ~] = run_redundant_array_RW(V_res_TARGET, ADC.N_red, base_sigma_n, 'ATA', [], ADC, RW_drift);
    [e_ala, pwr_ala, ~, ~] = run_redundant_array_RW(V_res_TARGET, ADC.N_red, base_sigma_n, 'ALA', [], ADC, RW_drift);
    [e_ht,  pwr_ht,  ~, ~] = run_redundant_array_RW(V_res_TARGET, ADC.N_red, base_sigma_n, 'HTLA', LUT_HTLA, ADC, RW_drift);
    [e_adapt, pwr_adapt, ~, ~] = run_redundant_array_RW(V_res_TARGET, ADC.N_red, base_sigma_n, 'Adapt', LUT_HTLA, ADC, RW_drift);
    
    est_all = {e_mle, e_be, e_dlr, e_ata, e_ala, e_ht, e_adapt};
    pwr_all = {pwr_mle, pwr_be, pwr_dlr, pwr_ata, pwr_ala, pwr_ht, pwr_adapt};
    
    for alg = 1:num_algs
        V_out_final = V_out_base + est_all{alg}*ADC.LSB;
        [~, ~, sndr_val] = calc_fft(V_out_final, ADC.Fs, FFT.N_points, ADC, FFT.Fin);
        res_sndr(alg, mc) = sndr_val;
        res_rmse(alg, mc) = sqrt(mean((est_all{alg} - V_res_TARGET).^2));
        res_pwr(alg, mc) = mean(pwr_all{alg});
        
        if mc == 1
            error_samples{alg} = est_all{alg} - V_res_TARGET;
        else
            error_samples{alg} = [error_samples{alg}, est_all{alg} - V_res_TARGET];
        end
    end
    
    waitbar(mc / N_MC, wb, sprintf('Progress: %d / %d', mc, N_MC));
end
close(wb);

%% ========================================================================
%% 5. 统计处理与报告生成
%% ========================================================================

fprintf('>>> [4/4] 生成纯净环境验证报告...\n');

sndr_mean = mean(res_sndr, 2);
sndr_std = std(res_sndr, 0, 2);
rmse_mean = mean(res_rmse, 2);
pwr_mean = mean(res_pwr, 2);

% 生成报告
report = sprintf('================================================================================\n');
report = [report, sprintf('  CLEAN BASELINE VERIFICATION REPORT\n')];
report = [report, sprintf('  纯净物理环境验证报告 - 理论性能上限\n')];
report = [report, sprintf('================================================================================\n\n')];

report = [report, sprintf('【1】仿真参数\n')];
report = [report, sprintf('  • ADC规格: %d-bit @ %.1f MS/s\n', ADC.N_main, ADC.Fs/1e6)];
report = [report, sprintf('  • 冗余周期: N_red = %d\n', ADC.N_red)];
report = [report, sprintf('  • 基础噪声: sigma_n = %.3f LSB\n', base_sigma_n)];
report = [report, sprintf('  • 蒙特卡洛: N_MC = %d\n', N_MC)];
report = [report, sprintf('  • 失调: 0 LSB (理想状态)\n')];
report = [report, sprintf('  • 电容失配: 关闭\n')];
report = [report, sprintf('  • 动态漂移: 关闭\n\n')];

report = [report, sprintf('【2】纯净环境性能对比\n')];
report = [report, sprintf('  %-8s  %12s  %12s  %12s\n', 'Algorithm', 'SNDR (dB)', 'Power (cyc)', 'RMSE (LSB)')];
report = [report, sprintf('  %s\n', repmat('-', 1, 50))];
for alg = 1:num_algs
    report = [report, sprintf('  %-8s  %6.1f±%-4.1f  %8.2f      %8.4f\n', ...
        ALG_NAMES{alg}, sndr_mean(alg), sndr_std(alg), pwr_mean(alg), rmse_mean(alg))];
end

report = [report, sprintf('\n【3】关键发现\n')];
[~, best_sndr_idx] = max(sndr_mean);
[~, best_pwr_idx] = min(pwr_mean);
report = [report, sprintf('  • 最高SNDR: %s (%.1f dB)\n', ALG_NAMES{best_sndr_idx}, sndr_mean(best_sndr_idx))];
report = [report, sprintf('  • 最低功耗: %s (%.2f cycles)\n', ALG_NAMES{best_pwr_idx}, pwr_mean(best_pwr_idx))];
report = [report, sprintf('  • HT-LA功耗仅为ATA的 %.1f%%\n', 100*pwr_mean(6)/pwr_mean(4))];
report = [report, sprintf('  • HT-LA vs ALA: SNDR +%.1f dB, 功耗 +%.1f cycles\n', ...
    sndr_mean(6)-sndr_mean(5), pwr_mean(6)-pwr_mean(5))];

report = [report, sprintf('\n================================================================================\n')];

fid = fopen(fullfile(REPORTS_DIR, 'Clean_Baseline_Report.txt'), 'w');
fprintf(fid, '%s', report);
fclose(fid);
fprintf('%s', report);
fprintf('报告已保存: %s\n', fullfile(REPORTS_DIR, 'Clean_Baseline_Report.txt'));

%% ========================================================================
%% 6. LaTeX表格生成
%% ========================================================================

fprintf('>>> 生成LaTeX表格...\n');

latex_table = sprintf('\\begin{table}[t]\n');
latex_table = [latex_table, sprintf('\\centering\n')];
latex_table = [latex_table, sprintf('\\caption{Clean Baseline Performance Comparison (0 LSB Offset)}\n')];
latex_table = [latex_table, sprintf('\\label{tab:clean_baseline}\n')];
latex_table = [latex_table, sprintf('\\begin{tabular}{lccc}\n')];
latex_table = [latex_table, sprintf('\\toprule\n')];
latex_table = [latex_table, sprintf('\\textbf{Algorithm} & \\textbf{Clean SNDR (dB)} & \\textbf{Baseline Power} & \\textbf{RMSE (LSB)} \\\\\n')];
latex_table = [latex_table, sprintf('\\midrule\n')];

for alg = 1:num_algs
    latex_table = [latex_table, sprintf('%s & $%.1f \\pm %.1f$ & %.2f & %.4f \\\\\n', ...
        ALG_NAMES{alg}, sndr_mean(alg), sndr_std(alg), pwr_mean(alg), rmse_mean(alg))];
end

latex_table = [latex_table, sprintf('\\bottomrule\n')];
latex_table = [latex_table, sprintf('\\end{tabular}\n')];
latex_table = [latex_table, sprintf('\\end{table}\n')];

fid = fopen(fullfile(LATEX_DIR, 'Clean_Baseline_LaTeX_Table.tex'), 'w');
fprintf(fid, '%s', latex_table);
fclose(fid);
fprintf('LaTeX表格已保存: %s\n', fullfile(LATEX_DIR, 'Clean_Baseline_LaTeX_Table.tex'));

%% ========================================================================
%% 7. 图表生成 - 仅保留Fig5和Fig10
%% ========================================================================

% Fig5: 误差分布直方图
fprintf('    生成 Fig5: 误差分布直方图...\n');
fig5 = figure('Name', 'Fig5_Error_Distribution', 'Position', [100, 100, 1400, 900], 'Color', 'w');
t = tiledlayout(3, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Fig. 5 Residual Estimation Error Distribution (Clean Environment)', 'FontWeight', 'bold', 'FontSize', 16);

for alg = 1:num_algs
    nexttile;
    histogram(error_samples{alg}, 50, 'FaceColor', COLOR.(lower(ALG_NAMES{alg})), 'EdgeColor', 'none', 'FaceAlpha', 0.7);
    xlabel('Error (LSB)', 'FontSize', 10);
    ylabel('Count', 'FontSize', 10);
    title(sprintf('%s (RMSE=%.3f)', ALG_NAMES{alg}, rmse_mean(alg)), 'FontSize', 11, 'FontWeight', 'bold');
    grid on; box on;
    xlim([-3, 3]);
end
exportgraphics(fig5, fullfile(FIGURES_DIR, 'Fig5_Error_Distribution.pdf'), 'ContentType', 'vector');

% Fig10: LUT对比
fprintf('    生成 Fig10: LUT对比...\n');
fig10 = figure('Name', 'Fig10_LUT_Compare', 'Position', [550, 550, 850, 600], 'Color', 'w');
stem(0:ADC.N_red, LUT_BE, 'b-', 'LineWidth', 2.8, 'MarkerSize', 9); hold on;
plot(0:ADC.N_red, LUT_MLE, 'r--', 'LineWidth', 2.2);
grid on; box on;
xlabel('k (number of 1s)', 'FontWeight', 'bold', 'FontSize', 16);
ylabel('$\hat{v}$ (LSB)', 'Interpreter', 'latex', 'FontWeight', 'bold', 'FontSize', 16);
legend('BE (Bayesian Shrinkage)', 'MLE (Pole Divergence)', 'Location', 'northwest');
title('Fig. 10 BE vs MLE Lookup Table Comparison', 'FontWeight', 'bold', 'FontSize', 18);
exportgraphics(fig10, fullfile(FIGURES_DIR, 'Fig10_LUT_Compare.pdf'), 'ContentType', 'vector');

fprintf('图表已保存: %s/\n', FIGURES_DIR);
fprintf('\n=== 纯净环境验证完成 ===\n');

%% ========================================================================
%% 8. 辅助函数
%% ========================================================================

function [V_dac, V_res_analog, comp_matrix] = run_main_SAR_core(V_in_diff, ADC, Noise, weights, N_pts, offset_val)
    if nargin < 6, offset_val = 0; end
    offset_V = offset_val * ADC.LSB;
    samp_noise = (Noise.kT_C_LSB * ADC.LSB) * randn(1, N_pts);
    V_sample = V_in_diff + samp_noise;
    V_dac = zeros(1, N_pts);
    comp_matrix = zeros(ADC.N_main, N_pts);
    for bit = 1:ADC.N_main
        W_diff = weights(bit) * 2;
        comp_noise = (Noise.comp_th_LSB * ADC.LSB) * randn(1, N_pts);
        V_compare = V_sample - V_dac + offset_V + comp_noise;
        comp_out = V_compare >= 0;
        comp_matrix(bit, :) = comp_out;
        V_dac = V_dac + sign(comp_out - 0.5) .* (W_diff / 2);
    end
    V_res_analog = V_sample - V_dac;
end

function [est, pwr_switch, k_final, freeze_res] = run_redundant_array_RW(V_res, N_red, sig_th, mode, LUT, ADC, RW_drift)
    nT = length(V_res);
    V_track = V_res;
    dac_switched = zeros(1, nT);
    pwr_switch = zeros(1, nT);
    
    if strcmpi(mode, 'MLE') || strcmpi(mode, 'BE') || strcmpi(mode, 'DLR')
        is_searching = false(1, nT);
    else
        is_searching = true(1, nT);
    end
    
    pD = zeros(1, nT);
    flip_count = zeros(1, nT);
    k_ones = zeros(1, nT);
    n_avg = zeros(1, nT);
    ata_sum = zeros(1, nT);
    ata_count = zeros(1, nT);
    freeze_res = zeros(1, nT);
    
    for step = 1:N_red
        drift_val = RW_drift(:, step)';
        D = ones(1, nT);
        D(V_track + drift_val + sig_th * randn(1, nT) <= 0) = -1;
        
        search_idx = is_searching;
        dac_switched(search_idx) = dac_switched(search_idx) + D(search_idx);
        V_track(search_idx) = V_track(search_idx) - D(search_idx);
        pwr_switch(search_idx) = pwr_switch(search_idx) + 1;
        
        lock_idx = ~is_searching;
        k_ones(lock_idx) = k_ones(lock_idx) + (D(lock_idx) == 1);
        n_avg(lock_idx) = n_avg(lock_idx) + 1;
        
        if step > 1
            new_freeze = (is_searching & ...
                ((strcmpi(mode,'ALA') & flip_count>=1) | ...
                 (strcmpi(mode,'HTLA') & flip_count>=2) | ...
                 (strcmpi(mode,'ADAPT') & ((sig_th<0.5 & flip_count>=1) | (sig_th>=0.5 & flip_count>=2)))));
            freeze_res(new_freeze) = V_track(new_freeze);
            
            new_flip = (D ~= pD) & is_searching;
            flip_count(new_flip) = flip_count(new_flip) + 1;
            
            if strcmpi(mode, 'ALA')
                is_searching(flip_count >= 1) = false;
            elseif strcmpi(mode, 'HTLA')
                is_searching(flip_count >= 2) = false;
            elseif strcmpi(mode, 'ADAPT')
                if sig_th < 0.5, is_searching(flip_count >= 1) = false;
                else, is_searching(flip_count >= 2) = false; end
            end
        end
        
        if strcmpi(mode, 'ATA')
            % ATA (Always Tracking Averaging): 始终追踪并平均
            % 所有周期都参与平均，不只是 flip_count >= 1 的周期
            ata_sum = ata_sum + dac_switched;
            ata_count = ata_count + 1;
        end
        pD = D;
    end
    k_final = k_ones;
    
    if strcmpi(mode, 'MLE') || strcmpi(mode, 'BE')
        est = LUT(k_ones + 1);
    elseif strcmpi(mode, 'DLR') || strcmpi(mode, 'ALA')
        est = dac_switched;
    elseif strcmpi(mode, 'ATA')
        est = ata_sum ./ max(ata_count, 1);
    elseif strcmpi(mode, 'HTLA') || strcmpi(mode, 'ADAPT')
        n_avg_safe = max(n_avg, 1);
        y = (2*k_ones ./ n_avg_safe) - 1;
        V_lin = sqrt(pi/2) * sig_th * y;
        lut_rows = max(1, min(n_avg, size(LUT,1)));
        lut_cols = max(1, min(k_ones+1, size(LUT,2)));
        lut_idx = sub2ind(size(LUT), lut_rows, lut_cols);
        est = dac_switched + V_lin + LUT(lut_idx);
    else
        est = zeros(1, nT);
    end
end

function [f_axis, PSD_val, sndr_val] = calc_fft(Dout, Fs, N_fft, ADC, Fin)
    win = blackmanharris(N_fft)';
    win_cg = sum(win) / N_fft;
    Y = fft(Dout .* win);
    P2 = abs(Y / N_fft).^2;
    P1 = P2(1:N_fft/2+1);
    P1(2:end-1) = 2 * P1(2:end-1);
    
    f_axis = (0:N_fft/2) * Fs / N_fft;
    PSD_val = 10*log10(P1 / win_cg^2 / (ADC.LSB^2) + 1e-12);
    
    if nargin < 5
        [~, max_idx] = max(P1(2:end-1));
        sig_bin = max_idx + 1;
    else
        sig_bin = round(Fin * N_fft / Fs) + 1;
    end
    
    sig_bins = max(1, sig_bin-3) : min(length(P1), sig_bin+3);
    p_sig = sum(P1(sig_bins));
    
    noise_bins = setdiff(2:length(P1), sig_bins);
    p_noise = sum(P1(noise_bins));
    
    if p_noise > 0
        sndr_val = 10 * log10(p_sig / p_noise);
    else
        sndr_val = 120;
    end
end
