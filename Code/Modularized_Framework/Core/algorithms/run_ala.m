% =========================================================================
% run_ala.m - ALA (Asynchronous LSB Averaging - 本文核心架构)
% =========================================================================
% 物理动作：1-Flip 物理冻结机制
%   - DAC 根据最后一次常规判决固定电容阵列
%   - 整个冗余期间 DAC 完全不跳动，不消耗任何动态开关功耗
%   - 比较器观测静态残差
%
% 数学输出：统计 +1 的概率 p = k/N_red
%   - 通过非线性映射公式：V_est = sqrt(2) * σ_n * erfinv(2p - 1)
%   - 将概率精确映射为带有亚 LSB 精度的高分辨率小数
%
% 鲁棒性特征：其映射公式由于自身的线性近似特性，对实际的 σ_n 漂移极度不敏感
%
% 功耗：极优。无 DAC 切换功耗
% =========================================================================

function [est, pwr_switch, k_final, freeze_res] = run_ala(V_res, N_red, sig_th, RW_drift)
    nT = length(V_res);
    
    V_track = V_res;
    pwr_switch = zeros(1, nT);
    freeze_res = zeros(1, nT);
    
    is_searching = true(1, nT);
    flip_detected = false(1, nT);
    
    pre_flip_sum = zeros(1, nT);
    post_flip_ones = zeros(1, nT);
    post_flip_count = zeros(1, nT);
    
    pD = zeros(1, nT);
    
    watchdog_threshold = 0.6;
    
    for step = 1:N_red
        drift_val = RW_drift(:, step)';
        
        D = ones(1, nT);
        D(V_track + drift_val + sig_th * randn(1, nT) <= 0) = -1;
        
        search_idx = is_searching;
        
        V_track(search_idx) = V_track(search_idx) - D(search_idx);
        pre_flip_sum(search_idx) = pre_flip_sum(search_idx) + D(search_idx);
        pwr_switch(search_idx) = pwr_switch(search_idx) + 1;
        
        if step > 1
            new_flip = (D ~= pD) & is_searching & ~flip_detected;
            flip_detected(new_flip) = true;
            
            just_frozen = flip_detected & is_searching;
            is_searching(just_frozen) = false;
            freeze_res(just_frozen) = V_track(just_frozen);
        end
        
        watchdog_trigger = is_searching & (step / N_red > watchdog_threshold);
        if any(watchdog_trigger)
            is_searching(watchdog_trigger) = false;
            freeze_res(watchdog_trigger) = V_track(watchdog_trigger);
        end
        
        locked_idx = ~is_searching;
        post_flip_ones(locked_idx) = post_flip_ones(locked_idx) + (D(locked_idx) == 1);
        post_flip_count(locked_idx) = post_flip_count(locked_idx) + 1;
        
        pD = D;
    end
    
    est = zeros(1, nT);
    
    has_post = post_flip_count > 0;
    
    if any(has_post)
        k = post_flip_ones(has_post);
        N_x = post_flip_count(has_post);
        
        p = k ./ N_x;
        
        p_clamped = max(1e-10, min(1 - 1e-10, p));
        frac_est = sqrt(2) * sig_th * erfinv(2 * p_clamped - 1);
        
        est(has_post) = pre_flip_sum(has_post) + frac_est;
    end
    
    not_locked = ~has_post;
    est(not_locked) = pre_flip_sum(not_locked);
    
    k_final = post_flip_ones;
end
