% =========================================================================
% config.m - 全局配置中心（完整版）
% =========================================================================
% 功能：定义所有全局参数、路径、算法配置和图表规范
% 调用方式：cfg = config;
% 输出：cfg 结构体（包含所有配置参数）
% =========================================================================

function cfg = config()

%% ========================================================================
%% 0. 项目路径配置 (相对路径)
%% ========================================================================
% config.m 位于 Code/Modularized_Framework/Core/
% 向上4级到达项目根目录
config_path = mfilename('fullpath');
if isempty(config_path)
    config_path = pwd;
end
[core_dir, ~, ~] = fileparts(config_path);
[framework_dir, ~, ~] = fileparts(core_dir);
[code_dir, ~, ~] = fileparts(framework_dir);
PROJECT_ROOT = fileparts(code_dir);

cfg.RESULTS_DIR = fullfile(PROJECT_ROOT, 'ModularResults');
cfg.FIGURES_DIR = fullfile(cfg.RESULTS_DIR, 'Figures');
cfg.REPORTS_DIR = fullfile(cfg.RESULTS_DIR, 'Reports');
cfg.LATEX_DIR = fullfile(cfg.RESULTS_DIR, 'LaTeX');
cfg.TEMP_DIR = fullfile(PROJECT_ROOT, 'Temp');

% 创建输出目录
if ~exist(cfg.FIGURES_DIR, 'dir'), mkdir(cfg.FIGURES_DIR); end
if ~exist(cfg.REPORTS_DIR, 'dir'), mkdir(cfg.REPORTS_DIR); end
if ~exist(cfg.LATEX_DIR, 'dir'), mkdir(cfg.LATEX_DIR); end
if ~exist(cfg.TEMP_DIR, 'dir'), mkdir(cfg.TEMP_DIR); end

%% ========================================================================
%% 1. SAR ADC 核心规格
%% ========================================================================
cfg.ADC.N_main    = 16;                      % 主 DAC 量化位数
cfg.ADC.N_red     = 22;                      % 冗余周期数 (SRM 决策次数)
cfg.ADC.V_ref     = 3.3;                     % 参考电压 (V)
cfg.ADC.V_fs      = 2 * cfg.ADC.V_ref;       % 差分满量程 (Vpp)
cfg.ADC.LSB       = cfg.ADC.V_fs / (2^cfg.ADC.N_main); % LSB 电压
cfg.ADC.Fs        = 5e6;                     % 采样率 (5 MSPS)
cfg.ADC.Cu_fF     = 0.015;                   % 单位电容 (15 aF)

%% ========================================================================
%% 2. 蒙特卡洛仿真参数
%% ========================================================================
cfg.N_MC = 30;                              % 蒙特卡洛次数
cfg.seed_start = 2026;                       % 固定随机种子保证可复现
cfg.offset_swp = linspace(0, 3.5, 4);        % 失调扫描范围 (LSB) - 减少点数
cfg.base_sigma_n = 0.587;                    % 基础比较器噪声 (LSB)

%% ========================================================================
%% 3. FFT 参数
%% ========================================================================
cfg.FFT.N_points = 8192;                     % FFT 点数
cfg.FFT.J_large  = 71;                       % 信号周期数 (质数)
cfg.FFT.Fin      = cfg.FFT.J_large * cfg.ADC.Fs / cfg.FFT.N_points; % 相干信号频率

%% ========================================================================
%% 4. 噪声参数
%% ========================================================================
cfg.Noise.kT_C_LSB = 22.2e-6 / cfg.ADC.LSB;  % kT/C 采样噪声标准差 (LSB)
cfg.Noise.comp_th_LSB = cfg.base_sigma_n;    % 比较器热噪声 (LSB)

%% ========================================================================
%% 5. 工艺失配参数
%% ========================================================================
cfg.Mismatch.sigma_C_Cu = 0.001;             % 单位电容失配率 (0.1% Pelgrom 定律)

%% ========================================================================
%% 6. 动态失调与漂移参数
%% ========================================================================
cfg.Drift.rho         = 0.99;                % AR-1 宏观慢漂移相关系数
cfg.Drift.sigma_drift = 0.5;                 % AR-1 漂移波动方差 (LSB)
cfg.Drift.sys_offset  = 1.2;                 % 封装/系统级静态失调 (LSB)
cfg.Drift.V_droop_max = 2.0;                 % 基准电压下垂最大偏差 (LSB)
cfg.Drift.tau_recover = 5.0;                 % 基准下垂恢复时间常数 (时钟周期)

%% ========================================================================
%% 7. Split-Sampling 架构参数 (Huang 2025)
%% ========================================================================
cfg.SS.Cs       = 20e-12;                    % 采样电容 (20 pF)
cfg.SS.CDAC     = 1e-12;                     % DAC 电容 (1 pF)
cfg.SS.CkT      = 1e-15;                     % 开关寄生电容 (1 fF)
cfg.SS.N_split  = 4;                         % Split 级数

%% ========================================================================
%% 8. 微表参数 (SFDR 测试)
%% ========================================================================
cfg.microLUT.N_samples = 4096;               % SFDR 测试样本数
cfg.microLUT.A_in      = 0.9;                % 输入信号幅度 (90% 满量程)
cfg.microLUT.f_in      = 1.0e6;              % 输入信号频率 (1 MHz)

%% ========================================================================
%% 9. 算法配置
%% ========================================================================
cfg.ALG_NAMES = {'MLE', 'BE', 'DLR', 'ATA', 'ALA', 'HTLA', 'Adapt'};
cfg.ALG_NAMES_FULL = {
    'MLE (Maximum Likelihood Estimation)', ...
    'BE (Bayesian Estimation)', ...
    'DLR (Dynamic LSB Repeat)', ...
    'ATA (Always Tracking Averaging)', ...
    'ALA (1-Flip Adaptive)', ...
    'HT-LA (2-Flip Hysteresis + LUT)', ...
    'Adaptive (Mixed Strategy)' ...
};

% 算法使能标志
cfg.ENABLE_ALG = true(1, 7);  % 全部启用

%% ========================================================================
%% 10. 学术图表规范 (IEEE JSSC/TCAS-I 标准)
%% ========================================================================
% 设置不显示图形窗口（后台运行模式）
set(0, 'DefaultFigureVisible', 'off');
set(0, 'DefaultAxesFontName', 'Times New Roman');
set(0, 'DefaultTextFontName', 'Times New Roman');
set(0, 'DefaultAxesFontSize', 14);
set(0, 'DefaultLineLineWidth', 2.0);
set(0, 'DefaultAxesLineWidth', 1.5);
set(0, 'DefaultAxesBox', 'on');
set(0, 'DefaultAxesXGrid', 'on');
set(0, 'DefaultAxesYGrid', 'on');
set(0, 'DefaultAxesGridLineStyle', ':');
set(0, 'DefaultAxesGridAlpha', 0.5);

% IEEE 经典调色板
cfg.COLOR.raw    = [0.70, 0.70, 0.70];   % 高级灰 (Raw)
cfg.COLOR.mle    = [0.20, 0.40, 0.80];  % 深靛蓝 (MLE)
cfg.COLOR.be     = [0.58, 0.40, 0.74];  % 紫色 (BE)
cfg.COLOR.dlr    = [0.50, 0.50, 0.50];   % 中灰 (DLR)
cfg.COLOR.ata    = [0.40, 0.20, 0.60];  % 绛紫色 (ATA)
cfg.COLOR.ala    = [0.90, 0.50, 0.10];  % 橙赤色 (ALA)
cfg.COLOR.htla   = [0.85, 0.15, 0.15];  % 砖红色 (HT-LA)
cfg.COLOR.adapt  = [0.15, 0.60, 0.30];  % 森林绿 (Adaptive)

%% ========================================================================
%% 11. 功能使能标志
%% ========================================================================
cfg.ENABLE_SFDR_TEST = true;               % 启用 SFDR 测试
cfg.ENABLE_LUT_COMP  = true;               % 启用 LUT 补偿
cfg.VERBOSE = true;                        % 详细输出模式

%% ========================================================================
%% 12. 启动信息
%% ========================================================================
if cfg.VERBOSE
    fprintf('======================================================================\n');
    fprintf('  INTEGRATED SAR ADC COMPREHENSIVE VERIFICATION FRAMEWORK\n');
    fprintf('  整合验证框架启动 - 目标期刊：IEEE JSSC/TCAS-I\n');
    fprintf('======================================================================\n\n');
    
    fprintf('>>> [1/5] 初始化系统参数与物理环境...\n');
    fprintf('    ADC 配置：%d-bit @ %.1f MS/s\n', cfg.ADC.N_main, cfg.ADC.Fs/1e6);
    fprintf('    冗余周期：%d, 基础噪声：%.3f LSB\n', cfg.ADC.N_red, cfg.base_sigma_n);
    fprintf('    蒙特卡洛：%d次，失调扫描：%.1f-%.1f LSB\n\n', ...
        cfg.N_MC, cfg.offset_swp(1), cfg.offset_swp(end));
end

end
