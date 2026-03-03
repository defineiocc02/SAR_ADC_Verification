% =========================================================================
% SAR ADC 物理感知验证框架 (V34.2 - 修复函数调用分隔符错误，完善中文注释)
%
% [修复说明]:
% 1. 将 run_redundant_array_RW 的多个调用语句分开，避免变量未定义错误。
% 2. 增加中文注释，解释每个物理参数和算法步骤，便于理解。
% =========================================================================

clc; clear; close all;

%% ========================================================================
% 全局绘图规范设置 (Publication-Ready Graphical Settings)
% ========================================================================
set(0, 'DefaultAxesFontName', 'Times New Roman');
set(0, 'DefaultTextFontName', 'Times New Roman');
set(0, 'DefaultAxesFontSize', 12);
set(0, 'DefaultLineLineWidth', 1.5);
set(0, 'DefaultAxesLineWidth', 1.0);
set(0, 'DefaultAxesBox', 'on');
set(0, 'DefaultAxesXGrid', 'on', 'DefaultAxesYGrid', 'on');
set(0, 'DefaultAxesGridLineStyle', ':', 'DefaultAxesGridAlpha', 0.5);

% 定义 IEEE 学术经典调色板 (用于区分不同算法的曲线)
COLOR.raw   =[0.70, 0.70, 0.70]; % 高级灰 (Raw)
COLOR.mle   =[0.20, 0.40, 0.80]; % 深靛蓝 (MLE)
COLOR.ata   =[0.40, 0.20, 0.60]; % 绛紫色 (ATA)
COLOR.ala   =[0.90, 0.50, 0.10]; % 橙赤色 (ALA)
COLOR.htla  = [0.85, 0.15, 0.15]; % 砖红色 (HT-LA - Proposed)
COLOR.adapt =[0.15, 0.60, 0.30]; % 森林绿 (Adaptive)

%% ========================================================================
% 1. 全局配置与底层物理参数定义 (Global Configuration & Physics)
% ========================================================================
fprintf('>>> [1/4] 初始化物理环境与蒙特卡洛验证引擎...\n');

N_MC          = 30;                      % 蒙特卡洛良率分析次数 (论文出图建议设为30-50)
seed_start    = 2026;                    % 固定随机种子保证可复现
rep_mc_idx    = floor(N_MC/2) + 1;       % 选取一次代表性运行用于频谱绘制

% --- 1.1 SAR ADC 核心规格 (Core Specifications) ---
ADC.N_main    = 16;                      % 主阵列量化位宽 (bit)
ADC.N_red     = 22;                      % 冗余阵列追踪周期数 (时钟周期数)
ADC.V_ref     = 3.3;                     % 系统满摆幅参考电压 (V)
ADC.V_fs      = 2 * ADC.V_ref;           % 差分全量程输入范围 (Vpp)
ADC.LSB       = ADC.V_fs / (2^ADC.N_main); % 最低有效位物理电压步长 (V) 约100.6µV
ADC.Fs        = 5e6;                     % 采样率 (5 MSPS)

% --- 1.2 物理底噪与工艺失配 (Noise & Process Variations) ---
Noise.kT_C_LSB      = 22.2e-6 / ADC.LSB; % kT/C 采样噪声标准差 (等效 LSB)
base_sigma_n        = 59.1e-6 / ADC.LSB; % 比较器热噪声 (~0.587 LSB)
ADC.Cu_fF           = 0.015;             % 单位电容设计值 (15 aF)，用于计算切换能耗
Mismatch.sigma_C_Cu = 0.001;             % 单位电容失配率 (0.1% Pelgrom 定律)

% --- 1.3 动态失调与宏微观漂移 (Dynamic Offset & Drift) ---
Drift.rho         = 0.99;                % AR-1 宏观慢漂移相关系数
Drift.sigma_drift = 0.5;                 % AR-1 漂移波动方差 (LSB)
Drift.sys_offset  = 1.2;                 % 封装/系统级静态失调 (LSB)
Drift.V_droop_max = 2.0;                 % 基准电压下垂最大偏差 (LSB)
Drift.tau_recover = 5.0;                 % 基准下垂恢复时间常数 (时钟周期)

% --- 1.4 相干频谱参数 (Coherent Sampling Setup) ---
FFT.N_points = 8192;                     % FFT 点数 (同时也是采样点数)
FFT.J_large  = 71;                       % 信号周期数 (质数，保证相干)
FFT.Fin      = FFT.J_large * ADC.Fs / FFT.N_points; % 相干信号频率
t = (0:FFT.N_points-1) / ADC.Fs;         % 时间向量
V_in_diff = 0.94 * ADC.V_ref * sin(2 * pi * FFT.Fin * t); % 差分输入正弦波

%% ========================================================================
% 2. 预计算与内存分配 (Pre-computations)
% ========================================================================
fprintf('>>> [2/4] 编译底层硬件查找表 (LUT) 与确定性误差矩阵...\n');

% 2.1 最大似然估计 (MLE) 查找表
% LUT_MLE(k+1) 对应冗余阵列中“1”的个数为 k 时的残差估计值
LUT_MLE = zeros(1, ADC.N_red + 1);
for k = 0:ADC.N_red
    if k > 0 && k < ADC.N_red
        LUT_MLE(k+1) = sqrt(2) * base_sigma_n * erfinv(2*k/ADC.N_red - 1);
    else
        LUT_MLE(k+1) = 2.5 * sign(k - 0.5); % 边界截断
    end
end

% 2.2 高阶阈值学习算法 (HT-LA) 查找表
% 存储精确期望值与线性近似的差值，尺寸 N_red × (N_red+1)
LUT_HTLA = zeros(ADC.N_red, ADC.N_red + 1);
for n_avg = 1:ADC.N_red
    for k = 0:n_avg
        y_val = (2*k - n_avg) / n_avg;   % 归一化偏差 y = (2k-n)/n
        y_safe = max(min(y_val, 1-1e-15), -1+1e-15); % 防止 erfinv 越界
        exact_full = sqrt(2) * base_sigma_n * erfinv(y_safe); % 精确期望值
        linear_base = sqrt(pi/2) * base_sigma_n * y_val;      % 线性近似
        delta_y = exact_full - linear_base;                   % 非线性修正项
        % 6-bit 量化截断，模拟硬件存储精度
        LUT_HTLA(n_avg, k+1) = round(max(min(delta_y, 0.5), -0.5) * 64) / 64;
    end
end

% 2.3 预生成确定性微观下垂矩阵 (每次转换中固定)
micro_drift_base = Drift.V_droop_max * exp(-(1:ADC.N_red) / Drift.tau_recover);
micro_drift_matrix = repmat(micro_drift_base, FFT.N_points, 1); % [8192×22]

%% ========================================================================
% 3. 蒙特卡洛全景仿真引擎 (Monte Carlo Simulation Engine)
% ========================================================================
fprintf('>>> [3/4] 启动物理级良率仿真引擎 (N_MC = %d)...\n', N_MC);
num_algs = 5;                            % 待评估算法数量
res_sndr = zeros(num_algs, N_MC);        % 存储每次运行的 SNDR 结果 (dB)
res_energy = zeros(num_algs, N_MC);      % 存储每次运行的平均追踪能耗 (fJ)
res_false_lock_ala = zeros(1, N_MC);     % ALA 算法的假锁率 (%)
res_false_lock_ht  = zeros(1, N_MC);     % HTLA 算法的假锁率 (%)

% 用于存储代表性运行的频谱数据
SpecData = struct();

wb = waitbar(0, 'Running Publication-Grade Circuit-Aware Simulations...');
for mc = 1:N_MC
    % 设置随机种子，确保每次蒙特卡洛运行独立且可复现
    rng(seed_start + mc * 888); 
    Noise.comp_th_LSB = base_sigma_n;     % 比较器噪声标准差（可在此处加入随机变化）
    
    % --- 3.1 电容失配注入 (模拟工艺偏差) ---
    weights_ideal = (ADC.V_ref) ./ (2.^(1:ADC.N_main)); % 理想二进制权重
    weights_real  = zeros(1, ADC.N_main);               
    for bit = 1:ADC.N_main
        % 根据面积缩放定律计算失配方差：高位电容面积大，失配小
        sigma_w = Mismatch.sigma_C_Cu * sqrt(2^(ADC.N_main - bit)) * weights_ideal(end);
        weights_real(bit) = weights_ideal(bit) + randn * sigma_w;
    end
    
    % --- 3.2 主阵列量化 (包含采样噪声和比较器噪声) ---
    [~, V_res_analog, comp_matrix] = run_main_SAR_core(V_in_diff, ADC, Noise, weights_real, FFT.N_points);
    V_res_TARGET = V_res_analog / ADC.LSB;   % 残余电压转换为 LSB 单位
    % 理想静态校准后的输出（用于正交性隔离）
    V_out_base = 2 * sum(comp_matrix .* weights_real', 1) - sum(weights_real);
    
    % --- 3.3 复合动态漂移环境生成 ---
    % 宏观漂移：AR-1 过程，模拟温度/老化引起的缓慢变化
    macro_fluc = zeros(FFT.N_points, 1);
    for i = 2:FFT.N_points
        macro_fluc(i) = Drift.rho * macro_fluc(i-1) + sqrt(1-Drift.rho^2) * Drift.sigma_drift * randn();
    end
    macro_drift_matrix = repmat(macro_fluc + Drift.sys_offset, 1, ADC.N_red); 
    % 总漂移 = 宏观漂移 + 微观确定性下垂 [8192×22]
    RW_drift = macro_drift_matrix + micro_drift_matrix; 
    
    % --- 3.4 冗余阵列追踪与残差估计 (五种算法对比) ---
    % 注意：每个函数调用必须独立成行，避免语法错误
    [e_mle, E_mle, ~, ~] = run_redundant_array_RW(V_res_TARGET, ADC.N_red, base_sigma_n, 'MLE', LUT_MLE, ADC, RW_drift);
    [e_ata, E_ata, ~, ~] = run_redundant_array_RW(V_res_TARGET, ADC.N_red, base_sigma_n, 'ATA', [], ADC, RW_drift);
    [e_ala, E_ala, ~, freeze_res_ala] = run_redundant_array_RW(V_res_TARGET, ADC.N_red, base_sigma_n, 'ALA', [], ADC, RW_drift);
    [e_ht,  E_ht,  ~, freeze_res_ht]  = run_redundant_array_RW(V_res_TARGET, ADC.N_red, base_sigma_n, 'HTLA', LUT_HTLA, ADC, RW_drift);
    [e_adapt, E_adapt, ~, ~] = run_redundant_array_RW(V_res_TARGET, ADC.N_red, base_sigma_n, 'ADAPT', LUT_HTLA, ADC, RW_drift);
    
    % 将估计值和能耗存入元胞数组，便于统一处理
    est_all = {e_mle, e_ata, e_ala, e_ht, e_adapt};
    E_all   = {E_mle, E_ata, E_ala, E_ht, E_adapt}; 
    
    % --- 3.5 纯净频域评估 (扣除宏观漂移，仅评估微观补偿效果) ---
    for alg = 1:5
        V_out_final = V_out_base + (est_all{alg} - (macro_fluc' + Drift.sys_offset)) * ADC.LSB;
        [f_axis, PSD_val, sndr_val] = calc_fft(V_out_final, ADC.Fs, FFT.N_points, FFT.J_large);
        
        res_sndr(alg, mc)   = sndr_val;
        res_energy(alg, mc) = mean(E_all{alg}); 
        
        % 捕获代表性运行的频谱用于最终出图
        if mc == rep_mc_idx
            SpecData.f = f_axis;
            if alg == 1, SpecData.PSD_mle = PSD_val; SpecData.sndr_mle = sndr_val; end
            if alg == 4, SpecData.PSD_ht  = PSD_val; SpecData.sndr_ht  = sndr_val; end
        end
    end
    
    % 捕获代表性运行的原始频谱 (含失配但无追踪)
    if mc == rep_mc_idx
        V_out_raw = 2 * sum(comp_matrix .* weights_ideal', 1) - sum(weights_ideal);
        [~, SpecData.PSD_raw, SpecData.sndr_raw] = calc_fft(V_out_raw, ADC.Fs, FFT.N_points, FFT.J_large);
    end
    
    % --- 3.6 假锁概率监控 (仅适用于有冻结机制的算法) ---
    thresh = 2 * base_sigma_n; % 假锁判决物理阈值 (2倍噪声标准差)
    res_false_lock_ala(mc) = sum(abs(freeze_res_ala) > thresh & freeze_res_ala ~= 0) / FFT.N_points;
    res_false_lock_ht(mc)  = sum(abs(freeze_res_ht)  > thresh & freeze_res_ht  ~= 0) / FFT.N_points;
    
    waitbar(mc / N_MC, wb, sprintf('Yield Analysis Progress: %d / %d', mc, N_MC));
end
close(wb);

%% ========================================================================
% 4. 自动化生成 LaTeX 级评估报告 (LaTeX-Ready Automated Report)
% ========================================================================
fprintf('>>> [4/4] 导出学术评估报告与论断...\n');
alg_names = {'MLE (Static)', 'ATA (Continuous)', 'ALA (1-Flip)', 'HT-LA (Proposed)', 'Adaptive (Mixed)'};
mean_sndr = mean(res_sndr, 2);
mean_ener = mean(res_energy, 2);
fl_rates  =[NaN, NaN, mean(res_false_lock_ala)*100, mean(res_false_lock_ht)*100, NaN];

fprintf('\n=========================================================================\n');
fprintf('  SAR ADC Residual Estimation Performance (N_MC = %d)\n', N_MC);
fprintf('-------------------------------------------------------------------------\n');
fprintf('  Algorithm        | SNDR (dB) | Energy (fJ) | False Lock (%%) \n');
fprintf('-------------------------------------------------------------------------\n');
for i = 1:5
    if isnan(fl_rates(i)), fl_str = 'N/A'; else, fl_str = sprintf('%5.2f', fl_rates(i)); end
    fprintf('  %-16s | %9.2f | %11.2f | %14s \n', alg_names{i}, mean_sndr(i), mean_ener(i), fl_str);
end
fprintf('=========================================================================\n\n');

% 自动生成 LaTeX 表格代码，可直接复制到论文中
fprintf('>>>[Auto-Generated LaTeX Table Code]:\n');
fprintf('\\begin{table}[htbp]\n\\centering\n\\caption{Performance Comparison of Tracking Algorithms}\n');
fprintf('\\begin{tabular}{lccc}\n\\toprule\n');
fprintf('\\textbf{Algorithm} & \\textbf{SNDR (dB)} & \\textbf{Energy (fJ)} & \\textbf{False Lock (\\%%)} \\\\\n\\midrule\n');
for i = 1:5
    if isnan(fl_rates(i)), fl_str = 'N/A'; else, fl_str = sprintf('%.2f', fl_rates(i)); end
    fprintf('%-16s & %.2f & %.2f & %s \\\\\n', alg_names{i}, mean_sndr(i), mean_ener(i), fl_str);
end
fprintf('\\bottomrule\n\\end{tabular}\n\\label{tab:performance}\n\\end{table}\n\n');

%% ========================================================================
% 5. 学术级核心图表渲染 (Publication-Quality Figure Rendering)
% ========================================================================
fprintf('>>> 渲染学术级高清图表...\n');
f_MHz = SpecData.f / 1e6; % 转换为 MHz，坐标轴更美观

% -------------------------------------------------------------------------
% [Fig 1] 高频高分辨率频谱对比 (Spectrum Comparison)
% -------------------------------------------------------------------------
fig1 = figure('Name', 'Output Spectrum Comparison', 'Position',[100 100 850 500], 'Color', 'w');
hold on; 

% 绘制原始频谱、MLE静态估计、HTLA动态补偿频谱
plot(f_MHz, SpecData.PSD_raw, 'Color', COLOR.raw, 'LineWidth', 1.0, 'DisplayName', sprintf('Raw (Mismatch) : %.1f dB', SpecData.sndr_raw));
plot(f_MHz, SpecData.PSD_mle, 'LineStyle', '--', 'Color', COLOR.mle, 'LineWidth', 1.5, 'DisplayName', sprintf('MLE (Static) : %.1f dB', SpecData.sndr_mle));
plot(f_MHz, SpecData.PSD_ht, 'LineStyle', '-', 'Color', COLOR.htla, 'LineWidth', 1.5, 'DisplayName', sprintf('HT-LA (Proposed) : %.1f dB', SpecData.sndr_ht));

% 标注信号主频位置
sig_idx = FFT.J_large + 1;
plot(f_MHz(sig_idx), SpecData.PSD_raw(sig_idx), 'v', 'MarkerSize', 8, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k', 'HandleVisibility', 'off');

% 坐标轴与图例设置
xlabel('Frequency (MHz)', 'FontWeight', 'bold');
ylabel('Power Spectral Density (dBFS)', 'FontWeight', 'bold');
title('Fig. 1: Measured Output Spectrum (Coherent, No Window)', 'FontSize', 14, 'FontWeight', 'bold');
axis([0 ADC.Fs/2/1e6 -160 0]);
legend('Location', 'southwest', 'FontSize', 11, 'Box', 'off');

% -------------------------------------------------------------------------
% [Fig 2] 蒙特卡洛 SNDR 箱线/散点图 (SNDR Boxplot with Jitter)
% -------------------------------------------------------------------------
fig2 = figure('Name', 'SNDR Yield Analysis', 'Position',[200 200 750 450], 'Color', 'w');
hold on;
bplot = boxplot(res_sndr', 'Labels', {'MLE','ATA','ALA','HT-LA','Adaptive'}, 'Symbol', '');
set(bplot, 'LineWidth', 1.5);

% 添加抖动散点，展示数据分布细节
x_centers = 1:5;
for i = x_centers
    jitter = (rand(1, N_MC) - 0.5) * 0.2; 
    scatter(repmat(i, 1, N_MC) + jitter, res_sndr(i,:), 20, 'k', 'filled', 'MarkerFaceAlpha', 0.4);
end

ylabel('SNDR (dB)', 'FontWeight', 'bold');
title('Fig. 2: Robustness Across Monte Carlo Variations', 'FontSize', 14, 'FontWeight', 'bold');
ylim([min(res_sndr(:))-2, max(res_sndr(:))+2]);

% -------------------------------------------------------------------------
% [Fig 3] 能量与假锁风险的权衡 (Energy vs False Lock Trade-off)
% -------------------------------------------------------------------------
fig3 = figure('Name', 'Energy vs Robustness', 'Position',[300 300 800 400], 'Color', 'w');

% 左侧子图：平均能耗柱状图（带误差棒）
subplot(1,2,1); hold on;
bar_h = bar(1:5, mean_ener, 0.6, 'FaceColor', 'flat', 'EdgeColor', 'k', 'LineWidth', 1.2);
bar_h.CData(1,:) = COLOR.mle; bar_h.CData(2,:) = COLOR.ata; 
bar_h.CData(3,:) = COLOR.ala; bar_h.CData(4,:) = COLOR.htla; bar_h.CData(5,:) = COLOR.adapt;
errorbar(1:5, mean_ener, std(res_energy,0,2), 'k.', 'LineWidth', 1.5, 'CapSize', 8);
set(gca, 'XTick', 1:5, 'XTickLabel', {'MLE','ATA','ALA','HT-LA','Adapt'}, 'XTickLabelRotation', 30);
ylabel('Tracking Energy / Conv. (fJ)', 'FontWeight', 'bold');
title('(a) Power Allocation', 'FontWeight', 'bold');

% 右侧子图：假锁率对比（仅含ALA和HTLA）
subplot(1,2,2); hold on;
fl_means = [fl_rates(3), fl_rates(4)];
bar_fl = bar(1:2, fl_means, 0.5, 'FaceColor', 'flat', 'EdgeColor', 'k', 'LineWidth', 1.2);
bar_fl.CData(1,:) = COLOR.ala; bar_fl.CData(2,:) = COLOR.htla;
set(gca, 'XTick', 1:2, 'XTickLabel', {'ALA (1-Flip)','HT-LA (2-Flip)'});
ylabel('False Lock Probability (%)', 'FontWeight', 'bold');
title('(b) Vulnerability vs Robustness', 'FontWeight', 'bold');

fprintf('>>> 仿真与渲染全部完成。祝您的 JSSC/TCAS-I 论文金榜题名！\n');

%% ========================================================================
% 6. 核心底层物理模型引擎 (Core Physical Modeling Engines)
% ========================================================================

% -------------------------------------------------------------------------
% 函数名: run_main_SAR_core
% 功能:   执行主 SAR ADC 量化过程，包含采样噪声和比较器噪声
% 输入:   V_in_diff - 差分输入电压 (1×N_pts)
%         ADC       - ADC结构体 (包含 N_main, LSB, V_ref)
%         Noise     - 噪声结构体 (kT_C_LSB, comp_th_LSB)
%         weights   - 实际DAC权重 (1×N_main)
%         N_pts     - 采样点数
% 输出:   V_dac        - 最终DAC输出电压
%         V_res_analog - 残余电压 (同 V_dac)
%         comp_matrix  - 比较器决策矩阵 (N_main × N_pts)
% -------------------------------------------------------------------------
function[V_dac, V_res_analog, comp_matrix] = run_main_SAR_core(V_in_diff, ADC, Noise, weights, N_pts)
    % 采样噪声注入 (差分结构噪声折半?)
    samp_noise = (Noise.kT_C_LSB * ADC.LSB / sqrt(2)) * randn(1, N_pts); 
    V_dac_p =  V_in_diff/2 + samp_noise;   % 正端 DAC 电压
    V_dac_n = -V_in_diff/2 - samp_noise;   % 负端 DAC 电压
    comp_matrix = zeros(ADC.N_main, N_pts);
    
    for bit = 1:ADC.N_main
        % 比较器热噪声注入
        comp_noise = (Noise.comp_th_LSB * ADC.LSB) * randn(1, N_pts); 
        comp_out = ((V_dac_p - V_dac_n) + comp_noise) >= 0; % 比较器判决
        comp_matrix(bit, :) = comp_out; 
        
        % 根据判决结果更新 DAC 电压
        V_dac_p(comp_out) = V_dac_p(comp_out) - weights(bit); 
        V_dac_n(~comp_out) = V_dac_n(~comp_out) - weights(bit);
    end
    V_dac = V_dac_p - V_dac_n; 
    V_res_analog = V_dac_p - V_dac_n;        
end

% -------------------------------------------------------------------------
% 函数名: run_redundant_array_RW
% 功能:   模拟冗余阵列的追踪过程，根据指定算法估计残余漂移
% 输入:   V_res    - 主量化残余电压 (1×nT, LSB)
%         N_red    - 冗余周期数
%         sig_th   - 比较器噪声标准差 (LSB)
%         mode     - 算法模式: 'MLE','ATA','ALA','HTLA','ADAPT'
%         LUT      - 查找表 (MLE用向量，HTLA/ADAPT用矩阵)
%         ADC      - ADC结构体 (用于单位电容值)
%         RW_drift - 漂移矩阵 (nT × N_red)
% 输出:   est         - 最终残差估计值 (1×nT)
%         E_track_fJ  - 每个采样点的总追踪能耗 (fJ)
%         k_final     - 冻结后统计的“1”的个数
%         freeze_res  - 冻结时刻的综合残差 (用于假锁检测)
% -------------------------------------------------------------------------
function[est, E_track_fJ, k_final, freeze_res] = run_redundant_array_RW(V_res, N_red, sig_th, mode, LUT, ADC, RW_drift)
    nT = length(V_res);                   % 采样点数
    V_track = V_res;                       % 当前追踪残余电压
    dac_switched = zeros(1, nT);           % 累积切换次数 (偏移估计整数部分)
    E_LSB_fJ = ADC.Cu_fF * (ADC.V_ref^2);  % 单次切换能量 (fJ)
    E_track_fJ = zeros(1, nT);              % 累计能耗
    
    % 初始化搜索状态: MLE模式从不搜索，其他模式开始都处于搜索状态
    if strcmp(mode, 'MLE')
        is_searching = false(1, nT);
    else
        is_searching = true(1, nT);
    end
    
    pD = zeros(1, nT);                      % 上一周期判决符号
    flip_count = zeros(1, nT);              % 翻转计数
    k_ones = zeros(1, nT);                   % 冻结后“1”的个数
    n_avg = zeros(1, nT);                    % 冻结后周期数
    ata_sum = zeros(1, nT);                  % ATA累积和
    ata_count = zeros(1, nT);                % ATA累积次数
    freeze_res = zeros(1, nT);                % 冻结时刻综合残差
    
    for step = 1:N_red
        current_drift = RW_drift(:, step)';   % 当前周期漂移
        % 符号检测: 残余+漂移+噪声 <=0 -> -1，否则 +1
        D = ones(1, nT); 
        D(V_track + current_drift + sig_th * randn(1, nT) <= 0) = -1;
        
        % 对仍在搜索状态的采样点更新累积切换值和残余电压
        search_idx = is_searching;
        dac_switched(search_idx) = dac_switched(search_idx) + D(search_idx); 
        V_track(search_idx)      = V_track(search_idx) - D(search_idx); 
        E_track_fJ(search_idx)   = E_track_fJ(search_idx) + E_LSB_fJ; 
        
        % 对已冻结的采样点统计“1”的个数和周期数
        lock_idx = ~is_searching;
        k_ones(lock_idx) = k_ones(lock_idx) + (D(lock_idx) == 1);
        n_avg(lock_idx)  = n_avg(lock_idx) + 1;
        
        if step > 1
            % 检测翻转事件
            new_flip = (D ~= pD) & is_searching;
            flip_count(new_flip) = flip_count(new_flip) + 1;
            just_frozen = false(1, nT);
            
            % 根据算法模式决定冻结条件
            if strcmp(mode, 'ALA')
                just_frozen = is_searching & (flip_count >= 1);      % 1次翻转后冻结
            elseif strcmp(mode, 'HTLA')
                just_frozen = is_searching & (flip_count >= 2);      % 2次翻转后冻结
            elseif strcmp(mode, 'ADAPT')
                % 自适应模式: 根据噪声水平选择冻结阈值
                just_frozen = is_searching & ( (sig_th < 0.5 & flip_count >= 1) | (sig_th >= 0.5 & flip_count >= 2) );
            end
            
            % 记录冻结瞬间的综合残差，并标记为冻结
            freeze_res(just_frozen) = V_track(just_frozen) + current_drift(just_frozen);
            is_searching(just_frozen) = false;
        end
        
        % ATA算法: 对已翻转的点累积 dac_switched 值
        if strcmp(mode, 'ATA')
            valid_ata_state = (flip_count >= 1);
            ata_sum(valid_ata_state) = ata_sum(valid_ata_state) + dac_switched(valid_ata_state);
            ata_count(valid_ata_state) = ata_count(valid_ata_state) + 1;
        end
        pD = D; 
    end
    k_final = k_ones;
    
    % --- 后端数字重建 (根据算法模式计算最终估计值) ---
    if strcmp(mode, 'MLE')
        % 最大似然估计: 直接查表
        est = LUT(k_ones + 1); 
    elseif strcmp(mode, 'ATA')
        % 平均时间平均: 有翻转则取平均，否则用最后一次 dac_switched
        est = zeros(1, nT); 
        has_flipped = ata_count > 0;
        est(has_flipped)  = ata_sum(has_flipped) ./ ata_count(has_flipped); 
        est(~has_flipped) = dac_switched(~has_flipped);                     
    elseif strcmp(mode, 'ALA') 
        % 一次翻转冻结: 采用线性近似修正
        est = dac_switched; 
        val = n_avg > 0; 
        est(val) = est(val) + sqrt(pi/2) * sig_th * ((2*k_ones(val) - n_avg(val)) ./ n_avg(val)); 
    elseif strcmp(mode, 'HTLA')
        % 两次翻转冻结: 采用精确非线性修正 (查表)
        est = dac_switched; 
        val = n_avg > 0; 
        y_val = (2*k_ones(val) - n_avg(val)) ./ n_avg(val); 
        safe_avg = max(1, n_avg);          % 防止下标为0
        safe_k = min(max(0, k_ones), safe_avg); % 防止越界
        lut_idx = sub2ind(size(LUT), safe_avg(val), safe_k(val)+1);
        est(val) = est(val) + sqrt(pi/2) * sig_th * y_val + LUT(lut_idx);
    elseif strcmp(mode, 'ADAPT')
        % 自适应模式: 根据噪声水平选择线性或非线性修正
        est = dac_switched; 
        val = n_avg > 0; 
        y_val = (2*k_ones(val) - n_avg(val)) ./ n_avg(val); 
        base_lin = sqrt(pi/2) * sig_th * y_val;
        if sig_th < 0.5
            est(val) = est(val) + base_lin; 
        else
            safe_avg = max(1, n_avg); 
            safe_k = min(max(0, k_ones), safe_avg); 
            lut_idx = sub2ind(size(LUT), safe_avg(val), safe_k(val)+1);
            est(val) = est(val) + base_lin + LUT(lut_idx); 
        end
    end
end

% -------------------------------------------------------------------------
% 函数名: calc_fft
% 功能:   计算信号的相干 FFT，返回单边频谱和 SNDR
% 输入:   V_out   - 输出数字码序列 (1×N)
%         Fs      - 采样率 (Hz)
%         N       - FFT 点数
%         J_large - 信号周期数，用于定位信号 bin
% 输出:   f    - 频率向量 (1×N/2+1)
%         PSD  - 功率谱密度 (dB)
%         sndr - 信噪失真比 (dB)
% -------------------------------------------------------------------------
function [f, PSD, sndr] = calc_fft(V_out, Fs, N, J_large)
    w = ones(1, N);                         % 矩形窗 (无窗)
    V_win = V_out .* w; 
    Y = fft(V_win) / N;                      % 归一化 FFT
    
    % 单边谱恢复幅度
    Y_mag = abs(Y(1:N/2+1)); 
    Y_mag(2:end-1) = 2 * Y_mag(2:end-1);    % 除直流和奈奎斯特外加倍
    
    PSD = 20 * log10(Y_mag + eps); 
    f = Fs * (0:N/2) / N;
    
    % 信号功率 (相干采样确保能量集中在单一 bin)
    sig_bin = J_large + 1; 
    sig_power = (Y_mag(sig_bin)^2) / 2; 
    
    % 总交流功率扣除信号功率得到噪声功率
    total_ac_power = sum((Y_mag(2:end).^2) / 2); 
    noise_power = total_ac_power - sig_power; 
    
    sndr = 10 * log10(sig_power / noise_power);
end