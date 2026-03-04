% =========================================================================
% run_ala.m - ALA (Asynchronous LSB Averaging - 本文核心架构)
% =========================================================================
% 功能：实现本文提出的 ALA 算法 (1-Flip 机制 + 算术平均)
% 
% 物理动作 (Physical Action)：
%   1-Flip 物理冻结机制：
%   - DAC 根据最后一次常规判决固定电容阵列
%   - 整个冗余期间 DAC 完全不跳动，不消耗任何动态开关功耗
%   - 比较器观测静态残差
%
% 数学输出 (Math Output) - 论文 Eq (11)：
%   V_res^(D_i,k) = Σ(D_i) * LSB + (2k - (N-x)) / (N-x) * LSB
%   其中：
%   - Σ(D_i)：翻转前的整数累积步长
%   - k：冻结阶段比较器输出 +1 的次数
%   - N-x：冻结阶段的有效周期数
%   - 小数部分 = (2k - N_x) / N_x，范围 [-1, +1] LSB
%
% PVT 鲁棒性 (PVT Robustness)：
%   算法不需要先验噪声信息 (sig_th)，仅依赖比较器输出的统计平均
%   这正是论文的核心创新点："insensitive to process, voltage, and temperature"
%
% 功耗 (Power)：
%   极优。仅搜索阶段消耗功耗，冻结阶段无 DAC 切换功耗
%
% 输入参数：
%   V_res    - 目标残差电压 (1×N_pts)，需要估计的残差电压
%   N_red    - 冗余周期数，用于噪声平均的采样次数
%   sig_th   - 噪声阈值 (LSB)，比较器热噪声的标准差（仅用于物理仿真，不参与估计）
%   RW_drift - 随机游走漂移矩阵 (N_pts × N_red)，模拟比较器输入偏移的随机漂移
%
% 输出参数：
%   est        - 数字估计值 (1×N_pts)，最终的残差估计结果（小数精度）
%   pwr_switch - 切换功耗指示 (1×N_pts)，仅搜索阶段累加
%   k_final    - 最终"1"的计数 (1×N_pts)，冻结阶段比较器输出1的次数
%   freeze_res - 冻结时的残差 (1×N_pts)，冻结时刻的追踪电压
%
% 算法特点：
%   - 优点：亚 LSB 精度、PVT 鲁棒、低功耗
%   - 核心创新：算术平均，无需先验噪声信息
%
% 参考文献：
%   Zhao et al., "A 16-bit 5-MS/s SAR ADC with...", JSSC 2024
%   Eq (11): V_res^(D_i,k) = Σ(D_i) + (2k-(N-x))/(N-x)
%
% 作者：AI Assistant
% 日期：2025-03
% 版本历史：
%   v1.0 - 初始实现（错误：使用了 erfinv 概率映射）
%   v2.0 - 添加 Watchdog 机制
%   v3.0 - 【关键修复】回归论文 Eq (11)，删除 erfinv，使用算术平均
%          - 删除 sig_th 依赖，实现真正的 PVT 鲁棒性
%          - 小数估计：frac_est = (2*k - N_x) / N_x
% =========================================================================

function [est, pwr_switch, k_final, freeze_res] = run_ala(V_res, N_red, sig_th, RW_drift)
    %% ========================================================================
    % 步骤1: 初始化变量
    %% ========================================================================
    nT = length(V_res);  % 样本数量
    
    % 物理状态变量
    V_track = V_res;                    % DAC 追踪电压
    pwr_switch = zeros(1, nT);          % 功耗指示
    freeze_res = zeros(1, nT);          % 冻结时的残差
    
    % 阶段控制变量
    is_searching = true(1, nT);         % 标志位：是否处于搜索阶段
    flip_detected = false(1, nT);       % 标志位：是否检测到翻转
    
    % 统计变量
    pre_flip_sum = zeros(1, nT);        % 翻转前的 D 累积和（整数部分）
    post_flip_ones = zeros(1, nT);      % 翻转后比较器输出 1 的次数
    post_flip_count = zeros(1, nT);     % 翻转后的有效周期数
    
    % 辅助变量
    pD = zeros(1, nT);                  % 上一次的比较器判决
    
    % Watchdog 阈值：搜索周期超过 60% 仍未翻转，强制切入冻结模式
    watchdog_threshold = 0.6;
    
    %% ========================================================================
    % 步骤2: 执行 N_red 次冗余比较
    %% ========================================================================
    for step = 1:N_red
        % 获取当前周期的漂移值（转置为行向量）
        drift_val = RW_drift(:, step)';
        
        % 比较器判决（带物理热噪声与低频漂移）
        % 注意：sig_th 仅用于物理仿真，不参与估计计算
        D = ones(1, nT);
        D(V_track + drift_val + sig_th * randn(1, nT) <= 0) = -1;
        
        % --- 搜索阶段：DAC 移动，消耗功耗 ---
        search_idx = is_searching;
        
        V_track(search_idx) = V_track(search_idx) - D(search_idx);
        pre_flip_sum(search_idx) = pre_flip_sum(search_idx) + D(search_idx);
        pwr_switch(search_idx) = pwr_switch(search_idx) + 1;
        
        % --- 翻转检测---
        if step > 1
            % 检测比较器极性翻转
            new_flip = (D ~= pD) & is_searching & ~flip_detected;
            flip_detected(new_flip) = true;
            
            % 一旦翻转，永久解除搜索状态，进入冻结平均
            just_frozen = flip_detected & is_searching;
            is_searching(just_frozen) = false;
            freeze_res(just_frozen) = V_track(just_frozen);
        end
        
        % --- Watchdog 机制：搜索周期超过 60% 仍未翻转，强制冻结 ---
        watchdog_trigger = is_searching & (step / N_red > watchdog_threshold);
        if any(watchdog_trigger)
            is_searching(watchdog_trigger) = false;
            freeze_res(watchdog_trigger) = V_track(watchdog_trigger);
        end
        
        % --- 冻结阶段：DAC 静止，纯数字统计，无开关功耗 ---
        locked_idx = ~is_searching;
        post_flip_ones(locked_idx) = post_flip_ones(locked_idx) + (D(locked_idx) == 1);
        post_flip_count(locked_idx) = post_flip_count(locked_idx) + 1;
        
        % 更新上一次判决
        pD = D;
    end
    
    %% ========================================================================
    % 步骤3: 算术平均估计 - 论文 Eq (11)
    %% ========================================================================
    est = zeros(1, nT);
    
    has_post = post_flip_count > 0;
    
    if any(has_post)
        k = post_flip_ones(has_post);
        N_x = post_flip_count(has_post);
        
        % --- 论文 Eq (11) 的核心实现 ---
        % 小数部分 = (2k - N_x) / N_x
        % 范围：[-1, +1] LSB
        % 无需 sig_th，实现 PVT 鲁棒性
        frac_est = (2 .* k - N_x) ./ N_x;
        
        % 总估计值 = 整数追踪步长 + 小数算术平均
        est(has_post) = pre_flip_sum(has_post) + frac_est;
    end
    
    % 未冻结的情况（全程搜索）
    not_locked = ~has_post;
    est(not_locked) = pre_flip_sum(not_locked);
    
    % 保存最终的"1"计数
    k_final = post_flip_ones;
    
    %% ========================================================================
    % 算法执行流程总结：
    % 1. 搜索阶段：DAC 追踪残差，直到检测到翻转或 Watchdog 触发
    % 2. 冻结阶段：DAC 锁定，统计比较器输出的 +1 次数 k
    % 3. 算术平均：frac_est = (2k - N_x) / N_x，无需先验噪声信息
    % 4. PVT 鲁棒：算法不依赖 sig_th，对工艺/电压/温度漂移不敏感
    % ========================================================================
end
