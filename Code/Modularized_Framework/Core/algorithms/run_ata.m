% =========================================================================
% run_ata.m - ATA (Adaptive-Tracking-Averaging - Miki 2015)
% =========================================================================
% 功能：实现 Miki (2015) 提出的 ATA 算法
% 
% 物理动作 (Physical Action)：
%   DAC 持续追踪模式：
%   - 在整个 N_red 周期内，DAC 始终在追踪跳变
%   - 追踪步长 D_DEC 根据比较器输出动态更新
%   - 如果连续两次比较器输出相同（'1/1' 或 '0/0'），步长加/减 1
%   - 如果连续两次比较器输出不同（翻转），步长保持不变
%
% 数学输出 (Math Output) - 论文 Eq (6) + Eq (7)：
%   阶段1（翻转前，共 M 次）：
%     V_res,ATA,1 = Σ D_OUT(i) * LSB
%   阶段2（翻转后，从 M+1 到 N）：
%     V_res,ATA,2 = Σ D_DEC(i) / (N-M) * LSB
%   最终估计值：
%     est = V_res,ATA,1 + V_res,ATA,2
%
% 关键特征：
%   论文批评："Since the residue voltage changes during tracking averaging,
%   many of the decisions are not produced based on the estimation target."
%   这意味着 ATA 在平均期间残差电压是变化的，导致估计精度下降
%
% 功耗 (Power)：
%   高。每个周期 DAC 都在跳变，消耗开关功耗
%
% 输入参数：
%   V_res    - 目标残差电压 (1×N_pts)，需要估计的残差电压
%   N_red    - 冗余周期数，用于噪声平均的采样次数
%   sig_th   - 噪声阈值 (LSB)，比较器热噪声的标准差
%   RW_drift - 随机游走漂移矩阵 (N_pts × N_red)，模拟比较器输入偏移的随机漂移
%
% 输出参数：
%   est        - 数字估计值 (1×N_pts)，最终的残差估计结果
%   pwr_switch - 切换功耗指示 (1×N_pts)，每个周期累加
%   k_final    - 最终"1"的计数 (1×N_pts)，比较器输出1的次数
%   freeze_res - 冻结时的残差 (1×N_pts)，ATA 无冻结，返回最终追踪电压
%
% 算法特点：
%   - 优点：实现简单
%   - 缺点：残差在平均期间变化，估计精度受限
%   - 应用：作为对比基准
%
% 参考文献：
%   Miki et al., "A 16-bit 5-MS/s SAR ADC...", JSSC 2015
%   Eq (6): V_res,ATA,1 = Σ D_OUT(i) * LSB
%   Eq (7): V_res,ATA,2 = Σ D_DEC(i) / (N-M) * LSB
%
% 作者：AI Assistant
% 日期：2025-03
% 版本历史：
%   v1.0 - 初始实现（错误：翻转后冻结 DAC）
%   v2.0 - 添加 Watchdog 机制
%   v3.0 - 实现 DAC 持续追踪，Eq (8) 步长更新
%   v4.0 - 【关键修复】添加 Eq (7) 除法平均，分离两阶段累加器
% =========================================================================

function [est, pwr_switch, k_final, freeze_res] = run_ata(V_res, N_red, sig_th, RW_drift)
    %% ========================================================================
    % 步骤1: 初始化变量
    %% ========================================================================
    nT = length(V_res);  % 样本数量
    
    % 物理状态变量
    V_track = V_res;                    % DAC 追踪电压
    D_DEC = zeros(1, nT);               % 追踪步长（论文 Eq (8)）
    pwr_switch = zeros(1, nT);          % 功耗指示
    
    % 两阶段累加器 - 论文 Eq (6) + Eq (7)
    sum_phase1 = zeros(1, nT);          % 翻转前的直接累加 D_OUT (Eq 6)
    sum_phase2 = zeros(1, nT);          % 翻转后的 D_DEC 累加 (Eq 7)
    N_minus_M = zeros(1, nT);           % 记录平均阶段的周期数 (N-M)
    has_flipped = false(1, nT);         % 标记是否已发生首次翻转
    
    % 统计变量
    k_final = zeros(1, nT);             % 比较器输出 1 的次数
    
    % 辅助变量
    prev_D = zeros(1, nT);              % 上一次的比较器判决
    
    %% ========================================================================
    % 步骤2: 执行 N_red 次冗余比较（DAC 持续追踪）
    %% ========================================================================
    for step = 1:N_red
        % 获取当前周期的漂移值（转置为行向量）
        drift_val = RW_drift(:, step)';
        
        % 比较器判决（带物理热噪声与低频漂移）
        noise = sig_th * randn(1, nT);
        D_OUT = ones(1, nT);
        D_OUT(V_track + drift_val + noise <= 0) = -1;
        
        % 统计比较器输出 1 的次数
        k_final = k_final + (D_OUT == 1);
        
        % --- 论文 Eq (8): 追踪步长更新逻辑 ---
        if step == 1
            % 第一个周期：步长直接等于判决结果
            D_DEC = D_OUT;
        else
            % 后续周期：根据连续判决结果更新步长
            % 如果连续两次判决相同，步长加/减 1
            % 如果连续两次判决不同（翻转），步长保持不变
            same_decision = (D_OUT == prev_D);
            D_DEC(same_decision) = D_DEC(same_decision) + D_OUT(same_decision);
            % D_DEC(~same_decision) 保持不变
        end
        
        % --- 检测首次翻转点 M ---
        if step > 1
            new_flip = (D_OUT ~= prev_D) & ~has_flipped;
            has_flipped(new_flip) = true;
        end
        
        % --- 根据阶段分离累加器 ---
        % 阶段1 (Eq 6): 未翻转前，直接累加 D_OUT
        phase1_idx = ~has_flipped;
        sum_phase1(phase1_idx) = sum_phase1(phase1_idx) + D_OUT(phase1_idx);
        
        % 阶段2 (Eq 7): 翻转后，累加 D_DEC 用于后续平均
        phase2_idx = has_flipped;
        sum_phase2(phase2_idx) = sum_phase2(phase2_idx) + D_DEC(phase2_idx);
        N_minus_M(phase2_idx) = N_minus_M(phase2_idx) + 1;
        
        % --- DAC 追踪跳变 ---
        V_track = V_track - D_DEC;
        
        % --- 功耗累加（每个周期都耗电）---
        pwr_switch = pwr_switch + 1;
        
        % 更新上一次判决
        prev_D = D_OUT;
    end
    
    % 记录最终追踪电压
    freeze_res = V_track;
    
    %% ========================================================================
    % 步骤3: 执行 Eq (7) 的除法重构
    %% ========================================================================
    % 避免除以 0
    valid_avg = N_minus_M > 0;
    frac_est = zeros(1, nT);
    frac_est(valid_avg) = sum_phase2(valid_avg) ./ N_minus_M(valid_avg);
    
    % 最终估计值 = 阶段1的整数 + 阶段2的平均小数
    est = sum_phase1 + frac_est;
    
    %% ========================================================================
    % 算法执行流程总结：
    % 1. DAC 在整个周期内持续追踪跳变
    % 2. 追踪步长 D_DEC 根据连续判决结果动态更新
    % 3. 每个周期都消耗开关功耗
    % 4. 阶段1：翻转前直接累加 D_OUT
    % 5. 阶段2：翻转后累加 D_DEC 并除以 (N-M) 取平均
    % 6. 关键缺陷：残差在平均期间变化，估计精度受限
    % ========================================================================
end
