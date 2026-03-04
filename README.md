# SAR ADC 残差估计算法验证框架

[![Version](https://img.shields.io/badge/version-v5.0.0-blue.svg)](https://github.com)
[![MATLAB](https://img.shields.io/badge/MATLAB-R2024a-orange.svg)](https://www.mathworks.com)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## 项目概述

本项目是用于验证 SAR ADC（逐次逼近型模数转换器）残差估计算法的完整动态行为级仿真框架，支持 **7 种算法**的多维度性能评估与对比，符合 JSSC 级学术出版标准。

### 核心算法

| 算法 | 版本 | 描述 | PVT 鲁棒 | 参考文献 |
|------|------|------|:--------:|---------|
| **MLE** | v3.0 | 最大似然估计（LUT查表） | ❌ | - |
| **BE** | v3.0 | 贝叶斯估计（LUT查表） | ❌ | - |
| **DLR** | v6.0 | 动态 LSB 重复（整数追踪） | ✅ | - |
| **ATA** | v6.0 | 自适应追踪平均 | ✅ | Miki 2015 |
| **ALA** | v5.0 | 异步 LSB 平均（1-Flip） | ✅ | Zhao 2024 |
| **HT-LA** | v2.0 | 2-Flip 迟滞 + LUT 补偿 | ✅ | - |
| **Adaptive** | v2.0 | 自适应分支选择 | ✅ | - |

---

## 版本历史

### v5.0.0 (2026-03-04) - 重大更新

**新增功能**
- ✅ 新增假死率分析模块 `run_false_freezing_analysis.m`
- ✅ 新增运行模式 3：假死率分析
- ✅ 新增 Fig_5：假死率随噪声变化曲线

**关键修复**
- ✅ 修复残差计算基准面不一致问题（DLR/ATA/HT-LA/Adaptive）
- ✅ 统一使用零均值残差 `V_res_typ_LSB` 作为 RMS 计算基准

**性能改进**
- DLR 残差压缩比：0.90x → ~1.5x
- ATA 残差压缩比：0.71x → ~2.0x

---

### v4.1.0 (2026-03-04)

**关键修复：ATA 算法数学重构**
- ✅ 实现论文 Eq (6) + Eq (7) 的完整两阶段重构
- ✅ 分离翻转前后的累加器
- ✅ 翻转后执行除法平均 `sum_phase2 / (N-M)`

---

### v4.0.0 (2026-03-04)

**关键修复：回归论文原始物理机制**
- ✅ ALA 删除 erfinv，使用 Eq (11) 算术平均
- ✅ ATA 实现 DAC 持续追踪，Eq (8) 步长更新
- ✅ MLE/BE LUT 生成逻辑验证

---

### v3.3.0 (2026-03-04)

**图表渲染优化**
- ✅ Y 轴缩放：`ylim([84, 93])`
- ✅ 图例位置：`Location, 'SouthEast'`
- ✅ LaTeX 转义修复

---

## 核心特性

- **动态行为建模**：单极性 SAR 量化器物理映射，真实残差电压输出
- **多维度扫描**：噪声范围 0.4-1.2 LSB，N_red 范围 4-24
- **严格 dBFS 归一化**：符合 IEEE 规范的 FFT 频谱分析
- **JSSC 级学术可视化**：Times New Roman 字体、半对数坐标、PDF 归一化
- **PVT 鲁棒性验证**：ALA/ATA/DLR/HT-LA 不依赖先验噪声信息

---

## 项目结构

```
SAR_ADC_Verification/
├── Code/
│   ├── Modularized_Framework/
│   │   ├── Core/
│   │   │   ├── main.m                         # 主运行脚本 (入口)
│   │   │   ├── config.m                       # 全局配置
│   │   │   ├── run_algorithm_comparison.m     # 多维度对比评估 ⭐
│   │   │   ├── run_false_freezing_analysis.m  # 假死率分析 ⭐ NEW
│   │   │   ├── run_monte_carlo.m              # 蒙特卡洛仿真
│   │   │   └── algorithms/                    # 7 个算法模块
│   │   │       ├── run_mle.m                  # MLE v3.0
│   │   │       ├── run_be.m                   # BE v3.0
│   │   │       ├── run_dlr.m                  # DLR v6.0
│   │   │       ├── run_ata.m                  # ATA v6.0
│   │   │       ├── run_ala.m                  # ALA v5.0
│   │   │       ├── run_htla.m                 # HT-LA v2.0
│   │   │       └── run_adaptive.m             # Adaptive v2.0
│   │   └── Modules/                           # 辅助模块
│   └── Modules/                               # 辅助模块
├── Results/                                   # 统一输出目录 ⭐
│   ├── Fig_1_SNDR_vs_Sigma_PVT.png           # PVT 鲁棒性曲线
│   ├── Fig_2_FFT_Spectrum_Comparison.png     # FFT 频谱对比
│   ├── Fig_3_SNDR_vs_Nred.png                # 收敛效率曲线
│   ├── Fig_4_Residual_PDF_Dynamic.png        # 残差分布直方图
│   ├── Fig_5_False_Freezing_Rate.png         # 假死率分析 NEW
│   └── Report_SAR_Comparison_*.txt           # 详细分析报告
├── References/                                # 参考文献
├── archive/                                   # 归档旧代码
├── README.md                                  # 本文档
└── CHANGELOG.md                               # 变更日志
```

---

## 快速开始

### 环境要求

- MATLAB R2024a 或更高版本
- 信号处理工具箱（用于 FFT 分析）

### 运行方式

```matlab
% 进入项目目录
cd 'SAR_ADC_Verification/Code/Modularized_Framework/Core'

% 运行主脚本
main
```

### 运行模式

在 `main.m` 中设置 `RUN_MODE`：

| RUN_MODE | 功能 | 输出 |
|:--------:|------|------|
| 1 | 完整验证框架 | 完整仿真报告 |
| 2 | 多维度算法对比评估 | Fig_1~4 + 报告 |
| 3 | 假死率分析 | Fig_5 + 数据 |

```matlab
RUN_MODE = 2;  % 算法对比评估（默认）
```

---

## API 文档

### 核心函数

#### `run_algorithm_comparison()`

多维度算法对比评估主函数。

**功能**：
- 噪声扫描（0.4-1.2 LSB）
- N_red 扫描（4-24）
- SNDR、残差压缩、收敛效率分析

**输出**：
- `Fig_1~4`：JSSC 级学术图表
- `Report_SAR_Comparison_*.txt`：详细分析报告

---

#### `run_false_freezing_analysis()`

假死率分析函数。

**功能**：
- 对比 1-Flip (ALA) 和 2-Flip (HT-LA) 的假死率
- 噪声扫描（0.4-2.0 LSB）
- 50,000 样本蒙特卡洛仿真

**参数**：
| 参数 | 默认值 | 描述 |
|------|--------|------|
| `N_pts` | 50000 | 蒙特卡洛样本数 |
| `N_red` | 20 | 冗余周期数 |
| `sigma_range` | 0.4-2.0 LSB | 噪声扫描范围 |
| `freeze_threshold` | 1.0 LSB | 假死判定阈值 |

**输出**：
- `Fig_5_False_Freezing_Rate.png`：假死率曲线
- `Data_False_Freezing_Results.mat`：分析数据

---

### 算法函数

所有算法函数具有统一接口：

```matlab
[est, pwr_switch, k_final, freeze_res] = run_xxx(V_res, N_red, sig_th, ...)
```

| 输出参数 | 描述 |
|----------|------|
| `est` | 残差估计值 (LSB) |
| `pwr_switch` | DAC 切换次数（功耗指示） |
| `k_final` | 比较器输出 1 的次数 |
| `freeze_res` | 冻结时的残差电压 |

---

## 输出说明

| 文件 | 描述 |
|------|------|
| `Fig_1_SNDR_vs_Sigma_PVT.png` | PVT 鲁棒性：SNDR vs 比较器噪声 |
| `Fig_2_FFT_Spectrum_Comparison.png` | FFT 频谱对比（7 种算法） |
| `Fig_3_SNDR_vs_Nred.png` | 收敛效率：SNDR vs 冗余周期数 |
| `Fig_4_Residual_PDF_Dynamic.png` | 残差分布直方图 |
| `Fig_5_False_Freezing_Rate.png` | 假死率分析曲线 |
| `Report_SAR_Comparison_*.txt` | 详细分析报告 |
| `Data_*.mat` | MATLAB 数据文件 |

---

## 已知问题

| 问题 | 状态 | 描述 |
|------|------|------|
| DLR 整数精度限制 | 已知 | DLR 输出整数，无法达到亚 LSB 精度 |
| ATA 平均期间残差变化 | 已知 | 论文指出的固有缺陷，建议使用 ALA |

---

## 参考文献

1. **Zhao et al.**, "A 16-bit 1-MS/s SAR ADC with asynchronous LSB averaging achieving 95.1-dB SNDR and 98.1-dB DR", IEEE JSSC, 2024
2. **Miki et al.**, "Adaptive Tracking Average for SAR ADC", 2015
3. **Huang et al.**, "A 5-MS/s 16-bit low-noise and low-power split sampling SAR ADC with eased driving burden", 2025
4. **Chen et al.**, "A 0.7-V 0.6-μW 100-kS/s Low-Power SAR ADC With Statistical Estimation-Based Noise Reduction", 2017

---

## 版本信息

- **当前版本**: v5.0.0
- **更新日期**: 2026-03-04
- **维护者**: AI Assistant

---

## 许可证

MIT License
