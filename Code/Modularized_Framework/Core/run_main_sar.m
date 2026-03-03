% =========================================================================
% run_main_sar.m - 主 SAR ADC 量化引擎
% =========================================================================
% 功能：执行主 SAR ADC 量化过程，包含采样噪声和比较器噪声
% 输入：
%   V_in_diff - 差分输入电压 (1×N_pts)
%   ADC       - ADC结构体 (包含 N_main, LSB, V_ref)
%   kT_C_LSB  - kT/C 采样噪声标准差 (LSB)
%   comp_th_LSB - 比较器热噪声标准差 (LSB)
%   weights   - 实际DAC权重 (1×N_main)
%   N_pts     - 采样点数
%   offset_val - 失调值 (LSB)
% 输出：
%   V_dac        - 最终DAC输出电压
%   V_res_analog - 残余电压 (同 V_dac)
%   comp_matrix  - 比较器决策矩阵 (N_main × N_pts)
% =========================================================================

function [V_dac, V_res_analog, comp_matrix] = run_main_sar(V_in_diff, ADC, kT_C_LSB, comp_th_LSB, weights, N_pts, offset_val)
    % 采样噪声注入 (差分结构噪声折半)
    samp_noise = (kT_C_LSB * ADC.LSB / sqrt(2)) * randn(1, N_pts);
    V_dac_p =  V_in_diff/2 + samp_noise;   % 正端 DAC 电压
    V_dac_n = -V_in_diff/2 - samp_noise;   % 负端 DAC 电压
    comp_matrix = zeros(ADC.N_main, N_pts);
    
    for bit = 1:ADC.N_main
        % 比较器热噪声注入
        comp_noise = (comp_th_LSB * ADC.LSB) * randn(1, N_pts);
        comp_out = ((V_dac_p - V_dac_n) + comp_noise + offset_val * ADC.LSB) >= 0; % 比较器判决
        comp_matrix(bit, :) = comp_out;
        
        % 根据判决结果更新 DAC 电压
        V_dac_p(comp_out) = V_dac_p(comp_out) - weights(bit);
        V_dac_n(~comp_out) = V_dac_n(~comp_out) - weights(bit);
    end
    V_dac = V_dac_p - V_dac_n;
    V_res_analog = V_dac_p - V_dac_n;
end
