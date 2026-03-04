% =========================================================================
% run_ata.m - ATA (Asynchronous Tracking and Averaging - Miki 2015)
% =========================================================================
% 功能：实现 Miki (2015) 提出的 ATA 算法
% 
% 物理动作 (Physical Action)：
%   两段式拼接：
%   - 阶段1（追踪）：DAC 像 DLR 一样跳变追踪残差，直到比较器发生第一次极性翻转
%   - 阶段2（冻结）：一旦检测到翻转，DAC 立刻物理冻结，不再耗电
%   - 比较器继续对固定的电压进行带噪判决
%
% 数学输出 (Math Output)：
%   est = (阶段1 的整数步长) + (阶段2 比较器输出的算术平均值)
%   - 阶段2 只是简单地求平均（Σ/N），严禁使用任何概率映射或 erfinv 函数
%
% 功耗 (Power)：
%   中等。只有追踪阶段消耗 pwr_switch
%
% 输入参数：
%   V_res    - 目标残差电压 (1×N_pts)，需要估计的残差电压
%   N_red    - 冗余周期数，用于噪声平均的采样次数
%   sig_th   - 噪声阈值 (LSB)，比较器热噪声的标准差
%   RW_drift - 随机游走漂移矩阵 (N_pts × N_red)，模拟比较器输入偏移的随机漂移
%
% 输出参数：
%   est        - 数字估计值 (1×N_pts)，最终的残差估计结果（整数 + 小数）
%   pwr_switch - 切换功耗指示 (1×N_pts)，仅追踪阶段累加
%   k_final    - 最终"1"的计数 (1×N_pts)，冻结阶段的有效周期数
%   freeze_res - 冻结时的残差 (1×N_pts)，冻结时刻的追踪电压
%
% 算法特点：
%   - 优点：比 DLR 功耗低，有小数精度
%   - 缺点：算术平均效率低于概率映射
%   - 应用：作为功耗-精度折中的基准
%
% 作者：AI Assistant
% 日期：2025-03
% 版本历史：
%   v1.0 - 初始实现
%   v2.0 - 添加 Watchdog 机制
%   v3.0 - 修复两段式拼接逻辑
%   v4.0 - 恢复 Miki 2015 原始物理机制：追踪→冻结→算术平均
%   v4.1 - 添加 freeze_res 输出参数，保持接口一致性
% =========================================================================

function [est, pwr_switch, k_final, freeze_res] = run_ata(V_res, N_red, sig_th, RW_drift)
    %% ========================================================================
    % 步骤1: 初始化变量
    %% ========================================================================
    nT = length(V_res);  % 样本数量
    
    % 物理状态变量
    V_track = V_res;                    % DAC 追踪电压
    dac_state = zeros(1, nT);           % 追踪阶段的 DAC 累加步数（整数）
    pwr_switch = zeros(1, nT);          % 功耗指示
    freeze_res = zeros(1, nT);          % 冻结时的残差
    
    % 阶段控制变量
    prev_C = zeros(1, nT);              % 上一次的比较器判决
    is_tracking = true(1, nT);          % 标志位：是否处于追踪阶段
    
    % 冻结阶段统计变量
    sum_avg = zeros(1, nT);             % 冻结阶段的判决累加和
    N_avg = zeros(1, nT);               % 冻结阶段的有效周期数

    %% ========================================================================
    % 步骤2: 执行 N_red 次冗余比较（两段式）
    %% ========================================================================
    for step = 1:N_red
        % 获取当前周期的漂移值（转置为行向量）
        drift_val = RW_drift(:, step)';
        
        % 比较器判决（带物理热噪声与低频漂移）
        noise = sig_th * randn(1, nT);
        C_out = ones(1, nT);
        C_out(V_track + drift_val + noise <= 0) = -1;
        
        % --- 翻转检测 ---
        if step > 1
            toggle = (C_out ~= prev_C);
            % 一旦翻转，永久解除追踪状态，进入冻结平均
            newly_frozen = toggle & is_tracking;
            is_tracking = is_tracking & ~toggle;
            
            % 记录冻结时的残差
            freeze_res(newly_frozen) = V_track(newly_frozen);
        end
        
        % --- 物理行为分发 ---
        track_mask = is_tracking;       % 追踪阶段
        avg_mask = ~is_tracking;        % 冻结阶段
        
        % [状态A：追踪阶段] - DAC 移动，消耗功耗
        dac_state(track_mask) = dac_state(track_mask) + C_out(track_mask);
        V_track(track_mask) = V_track(track_mask) - C_out(track_mask);
        pwr_switch(track_mask) = pwr_switch(track_mask) + 1;
        
        % [状态B：冻结阶段] - DAC 静止，纯数字统计，无开关功耗
        sum_avg(avg_mask) = sum_avg(avg_mask) + C_out(avg_mask);
        N_avg(avg_mask) = N_avg(avg_mask) + 1;
        
        % 更新上一次判决
        prev_C = C_out;
    end
    
    %% ========================================================================
    % 步骤3: 最终拼接重构 (Reconstruction)
    %% ========================================================================
    % 小数部分：冻结阶段的算术平均值
    frac_est = zeros(1, nT);
    valid_avg = N_avg > 0;
    
    % Miki 2015 的核心：直接使用算术平均作为亚 LSB 补偿，而不是概率映射
    frac_est(valid_avg) = sum_avg(valid_avg) ./ N_avg(valid_avg);
    
    % 总估计值 = 整数追踪步长 + 算术小数平均
    est = dac_state + frac_est;
    
    % 保存冻结阶段的长度供参考
    k_final = N_avg;
    
    %% ========================================================================
    % 算法执行流程总结：
    % 1. 追踪阶段：DAC 跳变追踪残差，直到检测到翻转
    % 2. 冻结阶段：DAC 锁定，统计比较器输出的算术平均
    % 3. 拼接：整数步长 + 小数平均
    % ========================================================================
end
