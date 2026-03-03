% =========================================================================
% run_dlr.m - DLR (基准技术：Dynamic LSB Repeat) 算法实现
% =========================================================================
% 功能：实现基准技术 DLR (Dynamic LSB Repeat)，完整独立实现
% 输入：
%   V_res    - 目标残差电压 (1×N_pts)
%   N_red    - 冗余周期数
%   sig_th   - 噪声阈值 (LSB)
%   RW_drift - 随机游走漂移矩阵 (N_pts × N_red)
% 输出：
%   est        - 数字估计值 (1×N_pts)
%   pwr_switch - 切换功耗指示 (1×N_pts)
%   k_final    - 最终"1"的计数 (1×N_pts)
%   freeze_res - 冻结时的残差（DLR 不使用，全 0）
% =========================================================================

function [est, pwr_switch, k_final, freeze_res] = run_dlr(V_res, N_red, sig_th, RW_drift)
    nT = length(V_res);
    
    % 初始化追踪变量
    V_track = V_res;
    dac_switched = zeros(1, nT);
    pwr_switch = zeros(1, nT);
    k_ones = zeros(1, nT);
    pD = zeros(1, nT);
    freeze_res = zeros(1, nT);
    
    % DLR 从不搜索，直接累积
    for step = 1:N_red
        % 注入漂移和噪声
        drift_val = RW_drift(:, step)';
        D = ones(1, nT);
        D(V_track + drift_val + sig_th * randn(1, nT) <= 0) = -1;
        
        % DLR：始终累积 DAC 切换
        dac_switched = dac_switched + D;
        V_track = V_track - D;
        pwr_switch = pwr_switch + 1;
        
        % 统计"1"的个数
        k_ones = k_ones + (D == 1);
        
        pD = D;
    end
    
    % DLR 核心：直接输出累积的 DAC 切换值
    est = dac_switched;
    k_final = k_ones;
end
