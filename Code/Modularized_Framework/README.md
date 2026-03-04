# SAR ADC 验证框架 - 模块化版本

[![Version](https://img.shields.io/badge/version-v5.0.0-blue.svg)](https://github.com)

## 项目概述

本框架提供 SAR ADC 残差估计算法的多维度性能评估，支持 **7 种算法**的对比分析。

---

## 项目结构

```
Modularized_Framework/
├── Core/
│   ├── main.m                         # 主运行脚本 (入口)
│   ├── config.m                       # 全局配置
│   ├── run_algorithm_comparison.m    # 多维度对比评估
│   ├── run_false_freezing_analysis.m # 假死率分析 NEW
│   ├── run_monte_carlo.m             # 蒙特卡洛仿真
│   ├── run_main_sar.m                # SAR 量化引擎
│   ├── calc_fft.m                    # FFT 分析
│   ├── generate_figures.m             # 图表生成
│   ├── generate_report.m             # 报告生成
│   └── algorithms/                   # 算法模块
│       ├── run_mle.m                 # MLE v3.0
│       ├── run_be.m                  # BE v3.0
│       ├── run_dlr.m                 # DLR v6.0
│       ├── run_ata.m                 # ATA v6.0
│       ├── run_ala.m                 # ALA v5.0
│       ├── run_htla.m                # HT-LA v2.0
│       └── run_adaptive.m            # Adaptive v2.0
└── Modules/                           # 辅助模块
```

---

## 快速开始

```matlab
cd 'SAR_ADC_Verification/Code/Modularized_Framework/Core'
main
```

---

## 运行模式

| RUN_MODE | 功能 | 输出 |
|:--------:|------|------|
| 1 | 完整验证框架 | 完整仿真报告 |
| 2 | 多维度算法对比评估 | Fig_1~4 + 报告 |
| 3 | 假死率分析 | Fig_5 + 数据 |

---

## 算法版本说明

| 算法 | 版本 | 核心逻辑 | PVT 鲁棒 |
|------|------|---------|:--------:|
| **MLE** | v3.0 | LUT 查表 | ❌ |
| **BE** | v3.0 | LUT 查表 | ❌ |
| **DLR** | v6.0 | 整数追踪 | ✅ |
| **ATA** | v6.0 | 动态追踪 + 两段式平均 | ✅ |
| **ALA** | v5.0 | 1-Flip 冻结 + 算术平均 | ✅ |
| **HT-LA** | v2.0 | 2-Flip 迟滞 + LUT | ✅ |
| **Adaptive** | v2.0 | 自适应分支选择 | ✅ |

---

## 输出说明

| 类型 | 路径 |
|------|------|
| 图表 | `../../Results/Fig_*.png` |
| 报告 | `../../Results/Report_*.txt` |
| 数据 | `../../Results/Data_*.mat` |

---

## 版本信息

- **版本**: v5.0.0
- **更新日期**: 2026-03-04
