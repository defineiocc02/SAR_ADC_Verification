% =========================================================================
% run_monte_carlo.m - 蒙特卡洛仿真引擎（完整版）
% =========================================================================
% 功能：执行蒙特卡洛仿真，调用所有算法模块
% 输入：cfg - 配置结构体
% 输出：results - 仿真结果结构体
% =========================================================================

function results = run_monte_carlo(cfg)

fprintf('>>> [2/5] 启动蒙特卡洛全景仿真引擎 (N_MC=%d)...\n', cfg.N_MC);

% 添加算法模块目录到路径
algorithms_dir = fullfile(fileparts(mfilename('fullpath')), 'algorithms');
addpath(algorithms_dir);

% 初始化输入信号
N_pts = cfg.FFT.N_points;
t = (0:N_pts-1) / cfg.ADC.Fs;
V_in_diff = 0.94 * cfg.ADC.V_ref * sin(2 * pi * cfg.FFT.Fin * t);

% 预分配结果
num_algs = 7;
num_offsets = length(cfg.offset_swp);
res_sndr = zeros(num_algs, num_offsets, cfg.N_MC);
res_rmse = zeros(num_algs, num_offsets, cfg.N_MC);
res_pwr  = zeros(num_algs, num_offsets, cfg.N_MC);
res_pole_prob_mle = zeros(1, num_offsets);
res_pole_prob_ht  = zeros(1, num_offsets);
res_false_lock_ala = zeros(1, num_offsets);
res_false_lock_ht  = zeros(1, num_offsets);

% 准备 LUT
% MLE 查找表
LUT_MLE = zeros(1, cfg.ADC.N_red + 1);
for k = 0:cfg.ADC.N_red
    if k > 0 && k < cfg.ADC.N_red
        LUT_MLE(k+1) = sqrt(2) * cfg.base_sigma_n * erfinv(2*k/cfg.ADC.N_red - 1);
    else
        LUT_MLE(k+1) = 2.5 * sign(k - 0.5);
    end
end

% BE 查找表
v_grid = linspace(-10*cfg.base_sigma_n, 10*cfg.base_sigma_n, 5000);
dv = v_grid(2) - v_grid(1);
prior = exp(-0.5 * (v_grid / cfg.base_sigma_n).^2);
LUT_BE = zeros(1, cfg.ADC.N_red + 1);
for k = 0:cfg.ADC.N_red
    p_v = 0.5 * (1 + erf(v_grid / (sqrt(2) * cfg.base_sigma_n)));
    likelihood = (p_v.^k) .* ((1 - p_v).^(cfg.ADC.N_red - k));
    posterior = likelihood .* prior;
    if sum(posterior) > 1e-100
        LUT_BE(k+1) = sum(v_grid .* posterior .* dv) / sum(posterior .* dv);
    else
        LUT_BE(k+1) = LUT_MLE(k+1);
    end
end

% HT-LA 微表
LUT_HTLA = zeros(cfg.ADC.N_red, cfg.ADC.N_red + 1);
for n_avg = 1:cfg.ADC.N_red
    for k = 0:n_avg
        y_val = (2*k - n_avg) / n_avg;
        y_safe = max(min(y_val, 1-1e-15), -1+1e-15);
        exact_full = sqrt(2) * cfg.base_sigma_n * erfinv(y_safe);
        linear_base = sqrt(pi/2) * cfg.base_sigma_n * y_val;
        delta_y = exact_full - linear_base;
        LUT_HTLA(n_avg, k+1) = round(max(min(delta_y, 0.5), -0.5) * 64) / 64;
    end
end

% 预生成确定性微观下垂
micro_drift_base = cfg.Drift.V_droop_max * exp(-(1:cfg.ADC.N_red) / cfg.Drift.tau_recover);
micro_drift_matrix = repmat(micro_drift_base, N_pts, 1);

% 蒙特卡洛循环
for o_idx = 1:num_offsets
    offset_val = cfg.offset_swp(o_idx);
    
    false_lock_ala_cnt = 0;
    false_lock_ht_cnt = 0;
    pole_mle_cnt = 0;
    pole_ht_cnt = 0;
    total_samples = 0;
    
    for mc = 1:cfg.N_MC
        rng(cfg.seed_start + mc * 100 + o_idx);
        
        % 噪声参数
        kT_C_LSB = cfg.Noise.kT_C_LSB;
        comp_th_LSB = cfg.base_sigma_n;
        
        % 电容失配建模
        weights_ideal = cfg.ADC.V_ref ./ (2.^(1:cfg.ADC.N_main));
        weights_real = zeros(1, cfg.ADC.N_main);
        for bit = 1:cfg.ADC.N_main
            sigma_w = cfg.Mismatch.sigma_C_Cu * sqrt(2^(cfg.ADC.N_main-bit)) * weights_ideal(end);
            weights_real(bit) = weights_ideal(bit) + randn * sigma_w;
        end
        
        % 主SAR量化
        [~, V_res_analog, comp_matrix] = run_main_sar(V_in_diff, cfg.ADC, kT_C_LSB, comp_th_LSB, weights_real, N_pts, offset_val);
        V_out_base = 2 * sum(comp_matrix .* weights_real', 1) - sum(weights_real);
        
        % 动态漂移
        macro_fluc = zeros(N_pts, 1);
        for i = 2:N_pts
            macro_fluc(i) = cfg.Drift.rho * macro_fluc(i-1) + sqrt(1-cfg.Drift.rho^2) * cfg.Drift.sigma_drift * randn();
        end
        macro_drift_matrix = repmat(macro_fluc + cfg.Drift.sys_offset, 1, cfg.ADC.N_red);
        RW_drift = macro_drift_matrix + micro_drift_matrix;
        
        V_res_TARGET = V_res_analog / cfg.ADC.LSB;
        
        % 运行七种算法
        [e_mle, pwr_mle, k_final_mle, ~] = run_mle(V_res_TARGET, cfg.ADC.N_red, cfg.base_sigma_n, LUT_MLE, RW_drift);
        [e_be,  pwr_be,  k_final_be,  ~] = run_be(V_res_TARGET, cfg.ADC.N_red, cfg.base_sigma_n, LUT_BE, RW_drift);
        [e_dlr, pwr_dlr, k_final_dlr, ~] = run_dlr(V_res_TARGET, cfg.ADC.N_red, cfg.base_sigma_n, RW_drift);
        [e_ata, pwr_ata, k_final_ata, ~] = run_ata(V_res_TARGET, cfg.ADC.N_red, cfg.base_sigma_n, RW_drift);
        [e_ala, pwr_ala, k_final_ala, freeze_res_ala] = run_ala(V_res_TARGET, cfg.ADC.N_red, cfg.base_sigma_n, RW_drift);
        [e_ht,  pwr_ht,  k_final_ht,  freeze_res_ht] = run_htla(V_res_TARGET, cfg.ADC.N_red, cfg.base_sigma_n, LUT_HTLA, RW_drift);
        [e_adapt, pwr_adapt, k_final_adapt, ~] = run_adaptive(V_res_TARGET, cfg.ADC.N_red, cfg.base_sigma_n, LUT_HTLA, RW_drift);
        
        est_all = {e_mle, e_be, e_dlr, e_ata, e_ala, e_ht, e_adapt};
        pwr_all = {pwr_mle, pwr_be, pwr_dlr, pwr_ata, pwr_ala, pwr_ht, pwr_adapt};
        
        for alg = 1:num_algs
            V_out_final = V_out_base + (est_all{alg} - (macro_fluc' + cfg.Drift.sys_offset)) * cfg.ADC.LSB;
            [~, ~, sndr_val] = calc_fft(V_out_final, cfg.ADC.Fs, N_pts, cfg.ADC, cfg.FFT.Fin);
            res_sndr(alg, o_idx, mc) = sndr_val;
            res_rmse(alg, o_idx, mc) = sqrt(mean((est_all{alg} - (V_res_TARGET - (macro_fluc' + cfg.Drift.sys_offset))).^2));
            res_pwr(alg, o_idx, mc) = mean(pwr_all{alg});
        end
        
        % 极点和假锁统计
        pole_mle_cnt = pole_mle_cnt + sum(k_final_mle == 0 | k_final_mle == cfg.ADC.N_red);
        frozen_ht_mask = freeze_res_ht ~= 0;
        if any(frozen_ht_mask)
            pole_ht_cnt = pole_ht_cnt + sum(k_final_ht(frozen_ht_mask) == 0 | k_final_ht(frozen_ht_mask) == cfg.ADC.N_red);
        end
        
        catastrophic_thresh = 2.0 * cfg.base_sigma_n;
        frozen_ala_idx = freeze_res_ala ~= 0;
        frozen_ht_idx  = freeze_res_ht ~= 0;
        false_lock_ala_samples = sum(abs(freeze_res_ala(frozen_ala_idx)) > catastrophic_thresh);
        false_lock_ht_samples  = sum(abs(freeze_res_ht(frozen_ht_idx)) > catastrophic_thresh);
        false_lock_ala_cnt = false_lock_ala_cnt + false_lock_ala_samples;
        false_lock_ht_cnt  = false_lock_ht_cnt  + false_lock_ht_samples;
        
        total_samples = total_samples + length(V_res_TARGET);
    end
    
    res_pole_prob_mle(o_idx) = pole_mle_cnt / total_samples;
    res_pole_prob_ht(o_idx)  = pole_ht_cnt / total_samples;
    res_false_lock_ala(o_idx) = false_lock_ala_cnt / total_samples;
    res_false_lock_ht(o_idx)  = false_lock_ht_cnt / total_samples;
    
    fprintf('    处理失调点 %d/%d: %.1f LSB\n', o_idx, num_offsets, offset_val);
end

% 统计处理
results.sndr_mean = mean(res_sndr, 3);
results.sndr_std = std(res_sndr, 0, 3);
results.rmse_mean = mean(res_rmse, 3);
results.rmse_std = std(res_rmse, 0, 3);
results.pwr_mean  = mean(res_pwr, 3);
results.pole_prob_mle = res_pole_prob_mle;
results.pole_prob_ht = res_pole_prob_ht;
results.false_lock_ala = res_false_lock_ala;
results.false_lock_ht = res_false_lock_ht;

fprintf('    蒙特卡洛仿真完成！\n\n');

end
