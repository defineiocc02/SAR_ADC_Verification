% =========================================================================
% run_ata.m - ATA (Miki 2015: Adaptive-Tracking-Average) 算法实现
% =========================================================================
% 功能：实现Miki (2015)提出的ATA算法
% 
% 算法物理动作：
%   Tracking阶段：检测到"01"或"10"翻转模式前，进行正常的1 LSB步进追踪
%   Averaging阶段：一旦检测到翻转，DAC不准冻结，必须继续随比较器结果追踪
%   比较器面对的是动态震荡的"移动靶子"
% 
% 数学逻辑（D_DEC解码）：
%   若(C_OUT[k], C_OUT[k-1])为(1,0)或(0,1)，则D_DEC[k] = D_DEC[k-1] (保持)
%   若为(1,1)，则D_DEC[k] = +1
%   若为(0,0)，则D_DEC[k] = -1
% 
% 两段式拼接逻辑：
%   Pre-Toggle: 翻转前的D_DEC求和（物理位移，不除）
%   Post-Toggle: 翻转后的D_DEC求平均（噪声平均，需除）
%   最终估计: est = Sum(Pre_Toggle) + Mean(Post_Toggle)
% 
% 设计约束：
%   - Watchdog机制：搜索周期超过60%仍未翻转，强制切入冻结模式
%   - 严禁在est计算中引入sig_th（噪声标准差）
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
% 版本：v5.0 (修正两段式拼接逻辑)
% =========================================================================

function [est, pwr_switch, k_final, freeze_res] = run_ata(V_res, N_red, sig_th, RW_drift)
    nT = length(V_res);
    
    V_track = V_res;
    pwr_switch = zeros(1, nT);
    freeze_res = zeros(1, nT);
    k_ones = zeros(1, nT);
    
    C_out = zeros(1, nT);
    D_dec = zeros(1, nT);
    pC = ones(1, nT);
    
    is_averaging = false(1, nT);  % 状态标志：false=搜索阶段，true=平均阶段
    
    pre_toggle_sum = zeros(1, nT);  % 翻转前D_DEC累积和
    post_toggle_sum = zeros(1, nT); % 翻转后D_DEC累积和
    post_toggle_count = zeros(1, nT); % 翻转后周期计数
    
    watchdog_threshold = 0.6;
    
    for step = 1:N_red
        drift_val = RW_drift(:, step)';
        
        C_out = ones(1, nT);
        C_out(V_track + drift_val + sig_th * randn(1, nT) <= 0) = -1;
        
        k_ones = k_ones + (C_out == 1);
        
        % 检测翻转模式：(1,0)或(0,1)
        toggle_detected = (C_out ~= pC);
        
        % 进入平均阶段
        is_averaging = is_averaging | toggle_detected;
        
        % D_DEC解码逻辑
        if step == 1
            D_dec = C_out;
        else
            is_toggle = (C_out == 1 & pC == -1) | (C_out == -1 & pC == 1);
            D_dec(is_toggle) = D_dec(is_toggle);
            D_dec(C_out == 1 & pC == 1) = 1;
            D_dec(C_out == -1 & pC == -1) = -1;
        end
        
        % 两段式拼接：分别累积
        search_idx = ~is_averaging;
        avg_idx = is_averaging;
        
        pre_toggle_sum(search_idx) = pre_toggle_sum(search_idx) + D_dec(search_idx);
        
        if any(avg_idx)
            post_toggle_sum(avg_idx) = post_toggle_sum(avg_idx) + D_dec(avg_idx);
            post_toggle_count(avg_idx) = post_toggle_count(avg_idx) + 1;
        end
        
        V_track = V_track - C_out;
        pwr_switch = pwr_switch + 1;
        
        % Watchdog机制：搜索周期超过60%仍未翻转
        watchdog_trigger = search_idx & (step / N_red > watchdog_threshold);
        if any(watchdog_trigger)
            is_averaging(watchdog_trigger) = true;
            freeze_res(watchdog_trigger) = V_track(watchdog_trigger);
        end
        
        pC = C_out;
    end
    
    % 最终估计：est = Sum(Pre_Toggle) + Mean(Post_Toggle)
    est = zeros(1, nT);
    
    has_post_toggle = post_toggle_count > 0;
    
    % 有翻转后平均的情况
    if any(has_post_toggle)
        est(has_post_toggle) = pre_toggle_sum(has_post_toggle) + ...
            post_toggle_sum(has_post_toggle) ./ post_toggle_count(has_post_toggle);
    end
    
    % 无翻转后平均的情况（全程搜索）
    no_post_toggle = ~has_post_toggle;
    if any(no_post_toggle)
        est(no_post_toggle) = pre_toggle_sum(no_post_toggle);
    end
    
    k_final = k_ones;
end
