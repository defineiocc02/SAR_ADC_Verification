% =========================================================================
% generate_figures.m - 图表生成引擎
% =========================================================================
% 功能：生成所有学术级图表
% 输入：
%   cfg - 配置结构体
%   results - 仿真结果结构体
% 输出：PDF 图表文件保存到 cfg.FIGURES_DIR
% =========================================================================

function generate_figures(cfg, results)

fprintf('>>> [3/5] 渲染学术级高清图表...\n');

% 获取算法名称和颜色
alg_names = cfg.ALG_NAMES;
colors = [cfg.COLOR.mle; cfg.COLOR.be; cfg.COLOR.dlr; cfg.COLOR.ata; ...
          cfg.COLOR.ala; cfg.COLOR.htla; cfg.COLOR.adapt];

% -------------------------------------------------------------------------
% Fig1: SNDR vs 失调
% -------------------------------------------------------------------------
fprintf('    生成 Fig1: SNDR vs 失调...\n');
fig1 = figure('Name', 'Fig1_SNDR', 'Position', [100, 100, 850, 600], 'Color', 'w', 'Visible', 'off');
for alg = 1:7
    plot(cfg.offset_swp, results.sndr_mean(alg, :), '-', ...
        'Color', colors(alg,:), 'LineWidth', 2, 'DisplayName', alg_names{alg});
    hold on;
end
xlabel('Dynamic Offset (LSB)', 'FontWeight', 'bold');
ylabel('SNDR (dB)', 'FontWeight', 'bold');
title('Fig. 1 SNDR vs Dynamic Offset', 'FontWeight', 'bold');
legend('Location', 'southwest');
grid on;
exportgraphics(fig1, fullfile(cfg.FIGURES_DIR, 'Fig1_SNDR_Sweep.pdf'), 'ContentType', 'vector');
close(fig1);

% -------------------------------------------------------------------------
% Fig6: 假锁定概率（物理洞察）
% -------------------------------------------------------------------------
fprintf('    生成 Fig6: 假锁定概率...\n');
fig6 = figure('Name', 'Fig6_FalseLock', 'Position', [350, 350, 850, 600], 'Color', 'w', 'Visible', 'off');
plot(cfg.offset_swp, results.false_lock_ala * 100, 'b-d', ...
    'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', 'ALA (1-Flip)');
hold on;
plot(cfg.offset_swp, results.false_lock_ht * 100, 'r-^', ...
    'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', 'HT-LA (2-Flip)');
xlabel('Dynamic Offset (LSB)', 'FontWeight', 'bold');
ylabel('False Lock Probability (%)', 'FontWeight', 'bold');
title('Fig. 6 False Lock Probability (Physical Insight: Large offset -> 0% is correct)', ...
    'FontWeight', 'bold');
legend('Location', 'northeast');
grid on;
exportgraphics(fig6, fullfile(cfg.FIGURES_DIR, 'Fig6_False_Lock.pdf'), 'ContentType', 'vector');
close(fig6);

% -------------------------------------------------------------------------
% Fig7: 极点概率（HT-LA 核心优势）
% -------------------------------------------------------------------------
fprintf('    生成 Fig7: 极点概率...\n');
fig7 = figure('Name', 'Fig7_PoleProb', 'Position', [400, 400, 850, 600], 'Color', 'w', 'Visible', 'off');
plot(cfg.offset_swp, results.pole_prob_mle * 100, 'g-s', ...
    'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', 'MLE Poles');
hold on;
plot(cfg.offset_swp, results.pole_prob_ht * 100, 'r-^', ...
    'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', 'HT-LA (Eliminated)');
xlabel('Dynamic Offset (LSB)', 'FontWeight', 'bold');
ylabel('Pole Probability (%)', 'FontWeight', 'bold');
title('Fig. 7 Pole Probability (HT-LA Core Advantage: Complete Elimination)', ...
    'FontWeight', 'bold');
legend('Location', 'northwest');
grid on;
exportgraphics(fig7, fullfile(cfg.FIGURES_DIR, 'Fig7_Pole_Prob.pdf'), 'ContentType', 'vector');
close(fig7);

fprintf('    图表已保存：%s\n\n', cfg.FIGURES_DIR);

end
