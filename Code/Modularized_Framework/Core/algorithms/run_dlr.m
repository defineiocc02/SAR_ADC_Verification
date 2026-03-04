% =========================================================================
% run_dlr.m - DLR (Dynamic LSB Repeat - 动态 LSB 重复)
% =========================================================================
% 物理动作：纯动态追踪（Moving Target）
%   - 在 N_red 个周期内，DAC 每一个周期都根据比较器判决强制进行 ±1 LSB 的物理跳变
%   - DAC 一直在震荡，紧咬残差
%
% 数学输出：算法最终估计值 est 仅仅是 DAC 移动步数的整数累加
%   - 由于 DAC 一直在震荡，DLR 永远存在 ±1 LSB 的量化稳态误差
%   - 绝对无法输出带有小数的亚 LSB 精度
%
% 功耗：极差。每一个冗余周期都必须产生一次 pwr_switch 累加
% =========================================================================

function [est, pwr_switch, k_final] = run_dlr(V_res, N_red, sig_th, RW_drift)
    nT = length(V_res);
    
    V_track = V_res;
    dac_switched = zeros(1, nT);
    pwr_switch = zeros(1, nT);
    k_ones = zeros(1, nT);
    
    for step = 1:N_red
        drift_val = RW_drift(:, step)';
        noise = sig_th * randn(1, nT);
        
        decision = V_track + drift_val + noise;
        
        D = ones(1, nT);
        D(decision <= 0) = -1;
        
        dac_switched = dac_switched + D;
        V_track = V_track - D;
        pwr_switch = pwr_switch + 1;
        
        k_ones = k_ones + (D == 1);
    end
    
    est = dac_switched;
    k_final = k_ones;
end
