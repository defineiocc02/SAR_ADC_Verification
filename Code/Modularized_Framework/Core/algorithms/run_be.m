% =========================================================================
% run_be.m - BE (基准技术：贝叶斯估计) 算法实现
% =========================================================================
% 功能：实现基准技术 BE (贝叶斯估计)，完整独立实现
% 
% 物理动作 (Physical Action)：
%   静态观测模式：
%   - DAC 物理冻结，完全不跳动
%   - 比较器对固定的残差进行 N_red 次观测
%   - 统计输出 '1' 的次数 k
%
% 数学输出 (Math Output)：
%   通过查找表 (LUT) 将 k 映射到残差估计值
%   - LUT 由先验分布（高斯）和似然函数联合计算
%   - 输出为后验期望估计
%
% 功耗 (Power)：
%   极优。无 DAC 切换功耗
%
% 输入参数：
%   V_res    - 目标残差电压 (1×N_pts)
%   N_red    - 冗余周期数
%   sig_th   - 噪声阈值 (LSB)
%   LUT      - 查找表 (1×(N_red+1))
%   RW_drift - 随机游走漂移矩阵 (N_pts × N_red)
%
% 输出参数：
%   est        - 数字估计值 (1×N_pts)
%   pwr_switch - 切换功耗指示 (1×N_pts)，BE 无切换，全为 0
%   k_final    - 最终"1"的计数 (1×N_pts)
%   freeze_res - 冻结时的残差（BE 不使用，全 0）
%
% 算法特点：
%   - 优点：理论上最优（在高斯先验下）
%   - 缺点：强依赖 LUT 准确性，LUT 错位会导致失效
%   - 应用：作为性能上限的理论基准
%
% 参考文献：
%   论文 Eq (3) + Eq (4)：后验概率分布与期望估计
%
% 作者：AI Assistant
% 日期：2025-03
% 版本历史：
%   v1.0 - 初始实现
%   v2.0 - 优化代码结构，添加完整注释
%   v3.0 - 【关键修复】确保 LUT 依赖逻辑，明确 PVT 敏感性
%          - LUT 必须在外部生成，算法本身不计算
%          - LUT 错位会导致算法自然失效（物理宿命）
% =========================================================================

function [est, pwr_switch, k_final, freeze_res] = run_be(V_res, N_red, sig_th, LUT, RW_drift)
    nT = length(V_res);
    
    % BE 与 MLE同样不进行前端搜索，做全长计数后查表
    pwr_switch = zeros(1, nT);
    freeze_res = zeros(1, nT);
    k_ones = zeros(1, nT);
    
    for step = 1:N_red
        drift_val = RW_drift(:, step)';
        D = ones(1, nT);
        D(V_res + drift_val + sig_th * randn(1, nT) <= 0) = -1;
        k_ones = k_ones + (D == 1);
    end
    
    est = LUT(k_ones + 1);
    k_final = k_ones;
end
