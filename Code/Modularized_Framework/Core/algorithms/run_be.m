% =========================================================================
% run_be.m - BE (基准技术：贝叶斯估计) 算法实现
% =========================================================================
% 功能：实现基准技术 BE (贝叶斯估计)，完整独立实现
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
%   freeze_res - 冻结时的残差（BE 不使用，全 0）
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
