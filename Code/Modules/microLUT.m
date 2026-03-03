%% 微表补偿频域有效性证明 (SFDR / 谐波压制分析)
clear; close all; clc;

% ==================== 1. 系统与信号参数 ====================
N_points = 16384;        % FFT 点数
f_in_bin = 53;           % 互质的输入频率 Bin
sigma_n  = 0.6;          % 比较器噪声 (LSB)
N_red    = 22;           % 冗余周期数
offset   = 0.0;          % 不刻意加入失调，测试正常工作条件
rng(2026);               % 固定随机种子

% 信号生成: 使用接近满量程的信号幅值（16-bit ADC 满量程 = 32768 LSB）
% 选择 90% 满量程以避免削波，更符合实际测试条件
A_sig = 0.9 * 2^15;      % 约 29491 LSB，接近满量程
t = (0:N_points-1) / N_points;
V_in_ideal = A_sig * sin(2 * pi * f_in_bin * t);

% ==================== 2. 预计算 6-bit 硬件微表 ====================
LUT = zeros(N_red, N_red+1);
for n = 1:N_red
    for k = 0:n
        y = 2*k/n - 1;
        y_safe = max(min(y, 1-1e-15), -1+1e-15); 
        V_exact = sqrt(2)*sigma_n * erfinv(y_safe);
        V_lin = sqrt(pi/2)*sigma_n * y;
        delta = V_exact - V_lin;
        LUT(n, k+1) = round(max(min(delta, 0.5), -0.5) * 64) / 64; % 6-bit量化
    end
end

% ==================== 3. 混合 ADC 仿真引擎 ====================
V_out_lin = zeros(1, N_points);
V_out_lut = zeros(1, N_points);

fprintf('正在运行正弦波全量程仿真及概率引擎计算 (%d 点)...\n', N_points);
tic;
for i = 1:N_points
    v_in = V_in_ideal(i);
    
    % --- 粗量化阶段 (假设前级 SAR 完美量化到整数 LSB) ---
    v_coarse = round(v_in); 
    
    % --- 残差生成 (带入动态失调) ---
    v_res = v_in - v_coarse + offset; 
    
    % --- 后端 2-Flip 概率估算引擎 ---
    v_track = v_res;
    dac_sw = 0; flip_cnt = 0; pD = NaN; frozen = false; k_cnt = 0; n_avg = 0;
    noise = randn(1, N_red) * sigma_n; % 当前样本的比较器噪声
    
    for step = 1:N_red
        D = sign(v_track + noise(step));
        if ~frozen
            dac_sw = dac_sw + D;
            v_track = v_track - D;
            if ~isnan(pD) && D ~= pD
                flip_cnt = flip_cnt + 1;
            end
            pD = D;
            if flip_cnt >= 2
                frozen = true;
            end
        else
            k_cnt = k_cnt + (D == 1);
            n_avg = n_avg + 1;
        end
    end
    
    % --- 后台数字重建 ---
    if n_avg > 0
        y = 2*k_cnt/n_avg - 1;
        V_lin_est = sqrt(pi/2)*sigma_n * y;
        V_lut_est = V_lin_est + LUT(n_avg, k_cnt+1);
        
        % 组合输出并扣除数字域失调
        V_out_lin(i) = v_coarse + dac_sw + V_lin_est - offset;
        V_out_lut(i) = v_coarse + dac_sw + V_lut_est - offset;
    else
        V_out_lin(i) = v_coarse + dac_sw - offset;
        V_out_lut(i) = v_coarse + dac_sw - offset;
    end
end
toc;

% ==================== 4. 频域 FFT 信号处理 ====================
% 加窗 (Blackman-Harris) 抑制频谱泄漏
win = blackmanharris(N_points)';
win_cg = sum(win)/N_points; % 相干增益补偿

% 计算线性估算的 FFT
Y_lin = fft(V_out_lin .* win);
P_lin = 20*log10(abs(Y_lin(1:N_points/2)) / (N_points/2) / win_cg / A_sig);

% 计算 LUT 补偿的 FFT
Y_lut = fft(V_out_lut .* win);
P_lut = 20*log10(abs(Y_lut(1:N_points/2)) / (N_points/2) / win_cg / A_sig);

% 频率轴归一化
freq = (0:N_points/2-1) / N_points;

% ==================== 5. SFDR 计算 ====================
% 屏蔽基频及其附近的 Bin，寻找最大杂散 (Spur)
signal_bins = max(1, f_in_bin-10) : min(N_points/2, f_in_bin+10);
P_lin_no_sig = P_lin; P_lin_no_sig(signal_bins) = -Inf;
P_lut_no_sig = P_lut; P_lut_no_sig(signal_bins) = -Inf;

sfdr_lin = -max(P_lin_no_sig);
sfdr_lut = -max(P_lut_no_sig);

fprintf('\n========== 频域性能对比 ==========\n');
fprintf('线性估算 SFDR: %.2f dBc\n', sfdr_lin);
fprintf('LUT补偿 SFDR : %.2f dBc\n', sfdr_lut);
fprintf('SFDR 改善幅度: %.2f dB\n', sfdr_lut - sfdr_lin);
fprintf('===================================\n');

% ==================== 6. 频谱可视化 ====================
figure('Position', [100 100 900 600]);

subplot(2,1,1);
plot(freq, P_lin, 'b', 'LineWidth', 1);
grid on;
axis([0 0.5 -120 5]);
title(sprintf('线性估算频谱 (SFDR = %.1f dBc)', sfdr_lin), 'FontSize', 12);
ylabel('幅度 (dBc)');
yline(-sfdr_lin, 'r--', '最大杂散', 'LabelHorizontalAlignment', 'left');

subplot(2,1,2);
plot(freq, P_lut, 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1);
grid on;
axis([0 0.5 -120 5]);
title(sprintf('LUT 微表补偿频谱 (SFDR = %.1f dBc)', sfdr_lut), 'FontSize', 12);
xlabel('归一化频率 (f/fs)');
ylabel('幅度 (dBc)');
yline(-sfdr_lut, 'r--', '最大杂散', 'LabelHorizontalAlignment', 'left');