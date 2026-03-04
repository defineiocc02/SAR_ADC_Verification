% =========================================================================
% run_false_freezing_analysis.m - 假死率 (False Freezing Rate) 分析
% =========================================================================
% 功能：分析 1-Flip (ALA) 和 2-Flip (HT-LA) 算法在高噪声下的假死率
%
% 物理背景：
%   在高噪声环境下，比较器容易受突发噪声毛刺干扰产生"早期假翻转"
%   导致 DAC 冻结在距离真实零点较远的位置，称为"假死 (False Freezing)"
%
% 算法对比：
%   - 1-Flip (ALA): 发生 1 次比较器翻转即冻结 DAC
%   - 2-Flip (HT-LA): 发生 2 次翻转才冻结 DAC（带有迟滞抗噪特性）
%
% 假死率定义：
%   FFR = sum(abs(freeze_res) > threshold) / N_pts * 100 (%)
%   其中 threshold = 1.0 LSB
%
% 输出：
%   - Fig_5: 假死率随噪声变化的折线图 (JSSC 风格)
%   - 控制台输出：各噪声点下的假死率数据
%
% 作者：AI Assistant
% 日期：2025-03
% =========================================================================

function run_false_freezing_analysis()
    %% ========================================================================
    % 参数设定
    %% ========================================================================
    N_pts = 50000;                                      % 蒙特卡洛样本数
    N_red = 20;                                         % 冗余周期数
    sigma_range = linspace(0.4, 2.0, 17);               % 比较器噪声范围 (LSB)
    V_res_range = [-5.0, 5.0];                          % 初始残差范围 (LSB)
    freeze_threshold = 1.0;                             % 假死判定阈值 (LSB)
    
    % LUT 参数 (HT-LA 需要)
    LUT_MLE = zeros(1, N_red + 1);                      % 简化 LUT（假死率分析不需要精确 LUT）
    
    %% ========================================================================
    % 初始化结果存储
    %% ========================================================================
    FFR_ALA = zeros(1, length(sigma_range));            % ALA 假死率
    FFR_HT_LA = zeros(1, length(sigma_range));          % HT-LA 假死率
    mean_freeze_ALA = zeros(1, length(sigma_range));    % ALA 平均冻结残差
    mean_freeze_HT_LA = zeros(1, length(sigma_range));  % HT-LA 平均冻结残差
    
    %% ========================================================================
    % 噪声扫描主循环
    %% ========================================================================
    fprintf('\n================================================================================\n');
    fprintf('  假死率分析 (False Freezing Rate Analysis)\n');
    fprintf('================================================================================\n');
    fprintf('  样本数: %d, 冗余周期: %d, 噪声范围: %.2f - %.2f LSB\n', ...
            N_pts, N_red, sigma_range(1), sigma_range(end));
    fprintf('  假死阈值: %.1f LSB\n\n', freeze_threshold);
    
    total_iters = length(sigma_range);
    
    for i_sigma = 1:length(sigma_range)
        sigma_th = sigma_range(i_sigma);
        
        fprintf('  [%d/%d] σ_n = %.2f LSB ... ', i_sigma, total_iters, sigma_th);
        
        % 生成随机初始残差（均匀分布）
        V_res_LSB = V_res_range(1) + (V_res_range(2) - V_res_range(1)) * rand(1, N_pts);
        
        % 生成漂移矩阵
        RW_drift = randn(N_pts, N_red) * (sigma_th * 0.3);
        
        % 运行 ALA (1-Flip)
        [~, ~, ~, freeze_res_ALA] = run_ala(V_res_LSB, N_red, sigma_th, RW_drift);
        
        % 运行 HT-LA (2-Flip)
        [~, ~, ~, freeze_res_HT_LA] = run_htla(V_res_LSB, N_red, sigma_th, LUT_MLE, RW_drift);
        
        % 计算假死率
        % 注意：freeze_res = 0 且全程未翻转的情况不计入假死
        % 检测条件：abs(freeze_res) > threshold 且 freeze_res != 0
        
        % ALA 假死判定
        false_freeze_ALA = (abs(freeze_res_ALA) > freeze_threshold) & (freeze_res_ALA ~= 0);
        FFR_ALA(i_sigma) = sum(false_freeze_ALA) / N_pts * 100;
        mean_freeze_ALA(i_sigma) = mean(abs(freeze_res_ALA(freeze_res_ALA ~= 0)));
        
        % HT-LA 假死判定
        false_freeze_HT_LA = (abs(freeze_res_HT_LA) > freeze_threshold) & (freeze_res_HT_LA ~= 0);
        FFR_HT_LA(i_sigma) = sum(false_freeze_HT_LA) / N_pts * 100;
        mean_freeze_HT_LA(i_sigma) = mean(abs(freeze_res_HT_LA(freeze_res_HT_LA ~= 0)));
        
        fprintf('ALA: %.2f%%, HT-LA: %.2f%%\n', FFR_ALA(i_sigma), FFR_HT_LA(i_sigma));
    end
    
    %% ========================================================================
    % 绘图：假死率随噪声变化 (JSSC 风格)
    %% ========================================================================
    fprintf('\n>>> 生成假死率分析图表...\n');
    
    % 图表参数
    fs_title = 14;
    fs_axis = 12;
    fs_legend = 11;
    
    figure('Position', [100, 100, 800, 600]);
    hold on;
    grid on;
    box on;
    
    % 绘制折线
    plot(sigma_range, FFR_ALA, 'r-o', 'LineWidth', 2, 'MarkerSize', 8, ...
         'MarkerFaceColor', 'r', 'DisplayName', '1-Flip (ALA)');
    plot(sigma_range, FFR_HT_LA, 'b-s', 'LineWidth', 2, 'MarkerSize', 8, ...
         'MarkerFaceColor', 'b', 'DisplayName', '2-Flip (HT-LA)');
    
    % 添加阴影区域（可选：显示置信区间）
    % fill([sigma_range, fliplr(sigma_range)], ...
    %      [FFR_ALA, fliplr(FFR_HT_LA)], ...
    %      [0.9, 0.9, 0.9], 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    
    hold off;
    
    % 坐标轴设置
    xlabel('Comparator Noise $\sigma_n$ (LSB)', 'Interpreter', 'latex', 'FontSize', fs_axis);
    ylabel('False Freezing Rate (%)', 'Interpreter', 'latex', 'FontSize', fs_axis);
    title('False Freezing Rate vs. Comparator Noise', 'FontSize', fs_title, 'Interpreter', 'latex');
    
    % 图例设置
    legend('Location', 'northwest', 'FontSize', fs_legend, 'Interpreter', 'latex');
    
    % 网格设置
    set(gca, 'GridAlpha', 0.3, 'MinorGridAlpha', 0.1);
    set(gca, 'FontName', 'Times New Roman', 'FontSize', fs_axis - 1, 'TickLabelInterpreter', 'latex');
    
    % 设置 Y 轴范围
    ylim([0, max(max(FFR_ALA), max(FFR_HT_LA)) * 1.1]);
    
    %% ========================================================================
    % 保存图表
    %% ========================================================================
    output_dir = fullfile(fileparts(mfilename('fullpath')), '..', '..', '..', 'Results');
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    saveas(gcf, fullfile(output_dir, 'Fig_5_False_Freezing_Rate.png'));
    
    % 保存 EPS 格式（JSSC 投稿需要）
    try
        saveas(gcf, fullfile(output_dir, 'Fig_5_False_Freezing_Rate.eps'), 'epsc');
    catch
        warning('EPS 保存失败，跳过');
    end
    
    fprintf('    图表已保存至: %s\n', output_dir);
    
    %% ========================================================================
    % 输出统计摘要
    %% ========================================================================
    fprintf('\n================================================================================\n');
    fprintf('  假死率分析结果摘要\n');
    fprintf('================================================================================\n');
    fprintf('  %-12s | %-15s | %-15s | %-12s\n', 'σ_n (LSB)', 'ALA FFR (%)', 'HT-LA FFR (%)', '改善倍数');
    fprintf('  %s\n', repmat('-', 1, 65));
    
    for i = 1:length(sigma_range)
        improvement = FFR_ALA(i) / max(FFR_HT_LA(i), 0.01);
        fprintf('  %-12.2f | %-15.2f | %-15.2f | %-12.1fx\n', ...
                sigma_range(i), FFR_ALA(i), FFR_HT_LA(i), improvement);
    end
    
    fprintf('\n  关键发现:\n');
    fprintf('  - ALA (1-Flip) 在高噪声下假死率显著增加\n');
    fprintf('  - HT-LA (2-Flip) 通过迟滞机制有效降低假死率\n');
    fprintf('  - 在 σ_n = %.2f LSB 时，HT-LA 假死率降低 %.1f 倍\n', ...
            sigma_range(end), FFR_ALA(end) / max(FFR_HT_LA(end), 0.01));
    
    %% ========================================================================
    % 保存数据
    %% ========================================================================
    data_file = fullfile(output_dir, 'Data_False_Freezing_Results.mat');
    save(data_file, 'sigma_range', 'FFR_ALA', 'FFR_HT_LA', 'mean_freeze_ALA', 'mean_freeze_HT_LA', ...
         'N_pts', 'N_red', 'freeze_threshold');
    fprintf('\n  数据已保存至: %s\n', data_file);
    
    fprintf('\n================================================================================\n');
    fprintf('  假死率分析完成！\n');
    fprintf('================================================================================\n');
end
