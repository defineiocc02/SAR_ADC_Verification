% =========================================================================
% run_ala.m - ALA (复现技术：1-Flip) 算法实现
% =========================================================================
% 功能：实现复现技术 ALA (1-Flip 机制 + 两段式线性映射)
% 
% 算法原理（基于Zhao 2024）：
%   1. 第一阶段（搜索阶段）：1-Flip机制，检测到首次翻转后冻结
%   2. 第二阶段（平均阶段）：使用两段式线性映射进行残差估计
%   3. Watchdog机制：搜索周期超过60%仍未翻转，强制切入冻结模式
%   
% 两段式线性映射公式（不依赖噪声参数，对抗PVT漂移）：
%   V_res^ = Σ(翻转前D_i) + (2k - (N-x))/(N-x) * LSB
%   其中：k=冻结后"1"的数量，N-x=平均周期数
% 
% 输入参数：
%   V_res    - 目标残差电压 (1×N_pts)
%   N_red    - 冗余周期数
%   sig_th   - 噪声阈值 (LSB)
%   RW_drift - 随机游走漂移矩阵 (N_pts × N_red)
% 
% 输出参数：
%   est        - 数字估计值 (1×N_pts)
%   pwr_switch - 切换功耗指示 (1×N_pts)
%   k_final    - 最终"1"的计数 (1×N_pts)
%   freeze_res - 冻结时的残差 (1×N_pts)
% 
% 作者：AI Assistant
% 日期：2025-03
% 版本：v3.0 (添加Watchdog机制)
% =========================================================================

function [est, pwr_switch, k_final, freeze_res] = run_ala(V_res, N_red, sig_th, RW_drift)
    nT = length(V_res);
    
    V_track = V_res;
    dac_output = zeros(1, nT);
    pwr_switch = zeros(1, nT);
    freeze_res = zeros(1, nT);
    
    flip_count = zeros(1, nT);
    pD = zeros(1, nT);
    is_searching = true(1, nT);
    
    pre_flip_sum = zeros(1, nT);
    post_flip_ones = zeros(1, nT);
    post_flip_count = zeros(1, nT);
    
    watchdog_threshold = 0.6;
    
    for step = 1:N_red
        drift_val = RW_drift(:, step)';
        
        D = ones(1, nT);
        D(V_track + drift_val + sig_th * randn(1, nT) <= 0) = -1;
        
        search_idx = is_searching;
        dac_output(search_idx) = dac_output(search_idx) + D(search_idx);
        V_track(search_idx) = V_track(search_idx) - D(search_idx);
        pwr_switch(search_idx) = pwr_switch(search_idx) + 1;
        
        if step > 1
            new_flip = (D ~= pD) & is_searching;
            flip_count(new_flip) = flip_count(new_flip) + 1;
            
            just_frozen = is_searching & (flip_count >= 1);
            freeze_res(just_frozen) = V_track(just_frozen);
            is_searching(just_frozen) = false;
            
            pre_flip_sum(just_frozen) = dac_output(just_frozen);
        end
        
        % Watchdog机制：搜索周期超过60%仍未翻转，强制切入冻结模式
        watchdog_trigger = is_searching & (step / N_red > watchdog_threshold) & (flip_count == 0);
        is_searching(watchdog_trigger) = false;
        
        % 记录Watchdog触发时的累积和
        watchdog_just_frozen = watchdog_trigger & (post_flip_count == 0);
        pre_flip_sum(watchdog_just_frozen) = dac_output(watchdog_just_frozen);
        freeze_res(watchdog_just_frozen) = V_track(watchdog_just_frozen);
        
        locked_idx = ~is_searching;
        post_flip_ones(locked_idx) = post_flip_ones(locked_idx) + (D(locked_idx) == 1);
        post_flip_count(locked_idx) = post_flip_count(locked_idx) + 1;
        
        pD = D;
    end
    
    % 两段式线性映射（不依赖噪声参数）
    est = zeros(1, nT);
    
    has_locked = post_flip_count > 0;
    
    if any(has_locked)
        k = post_flip_ones(has_locked);
        N_x = post_flip_count(has_locked);
        
        correction = (2*k - N_x) ./ N_x;
        est(has_locked) = pre_flip_sum(has_locked) + correction;
    end
    
    not_locked = ~has_locked;
    est(not_locked) = dac_output(not_locked);
    
    k_final = post_flip_ones + flip_count;
end
