% =========================================================================
% run_htla.m - HT-LA (新技术：2-Flip Hysteresis + LUT) 算法实现
% =========================================================================
% 功能：实现新技术 HT-LA (2-Flip 迟滞 + LUT 补偿)，完整独立实现
% 输入：
%   V_res    - 目标残差电压 (1×N_pts)
%   N_red    - 冗余周期数
%   sig_th   - 噪声阈值 (LSB)
%   LUT      - 查找表 (1×(N_red+1))
%   RW_drift - 随机游走漂移矩阵 (N_pts × N_red)
% 输出：
%   est        - 数字估计值 (1×N_pts)
%   pwr_switch - 切换功耗指示 (1×N_pts)
%   k_final    - 最终"1"的计数 (1×N_pts)
%   freeze_res - 冻结时的残差 (1×N_pts)
% =========================================================================

function [est, pwr_switch, k_final, freeze_res] = run_htla(V_res, N_red, sig_th, LUT, RW_drift)
    nT = length(V_res);
    
    % 初始化追踪变量
    V_track = V_res;
    dac_switched = zeros(1, nT);
    pwr_switch = zeros(1, nT);
    k_ones = zeros(1, nT);
    n_avg = zeros(1, nT);
    flip_count = zeros(1, nT);
    pD = zeros(1, nT);
    freeze_res = zeros(1, nT);
    is_searching = true(1, nT);
    
    % 主循环：遍历所有冗余周期
    for step = 1:N_red
        % 注入漂移和噪声
        drift_val = RW_drift(:, step)';
        D = ones(1, nT);
        D(V_track + drift_val + sig_th * randn(1, nT) <= 0) = -1;
        
        % 搜索状态：累积 DAC 切换
        search_idx = is_searching;
        dac_switched(search_idx) = dac_switched(search_idx) + D(search_idx);
        V_track(search_idx) = V_track(search_idx) - D(search_idx);
        pwr_switch(search_idx) = pwr_switch(search_idx) + 1;
        
        % 锁定状态：统计"1"的个数和平均次数
        lock_idx = ~is_searching;
        k_ones(lock_idx) = k_ones(lock_idx) + (D(lock_idx) == 1);
        n_avg(lock_idx) = n_avg(lock_idx) + 1;
        
        if step > 1
            new_flip = (D ~= pD) & is_searching;
            flip_count(new_flip) = flip_count(new_flip) + 1;
            
            just_frozen = is_searching & (flip_count >= 2);
            freeze_res(just_frozen) = V_track(just_frozen) + drift_val(just_frozen);
            is_searching(just_frozen) = false;
        end
        
        pD = D;
    end
    
    % ========================================================================
    % HT-LA 核心修复：1D LUT 概率映射 (消除双重补偿与查表锁死)
    % ========================================================================
    est = dac_switched;
    valid = n_avg > 0;
    
    if any(valid)
        k = k_ones(valid);
        n = n_avg(valid);
        
        % 计算概率 p
        p = k ./ n;
        
        % 将可变长度的 n_avg 的概率，等比例映射到 1D LUT 的网格上
        N_LUT = length(LUT) - 1;
        k_mapped = round(p .* N_LUT);
        
        % 直接查表 (正规生成的 LUT 中点必为 0)
        est(valid) = est(valid) + LUT(k_mapped + 1);
    end
    k_final = k_ones;
end
