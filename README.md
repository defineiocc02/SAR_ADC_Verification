# SAR ADC 残差估计算法验证框架

## 项目概述

本项目是用于验证 SAR ADC（逐次逼近型模数转换器）残差估计算法的完整框架，支持多种算法的多维度性能评估与对比。

### 核心算法

| 算法 | 版本 | 描述 | 参考文献 |
|------|------|------|---------|
| **MLE** | - | 最大似然估计（基准） | - |
| **BE** | - | 贝叶斯估计 | - |
| **DLR** | - | 动态LSB重复 | - |
| **ATA** | v5.0 | 自适应追踪平均 | Miki 2015 |
| **ALA** | v3.0 | 异步LSB平均（1-Flip） | Zhao 2024 |
| **HT-LA** | - | 迟滞追踪+LUT加速（2-Flip） | 新技术 |
| **Adaptive** | - | 自适应混合策略 | - |

### 核心特性

- **多维度扫描**：噪声范围 0.4-1.2 LSB，初始误差 0-4.0 LSB
- **LUT错位测试**：验证PVT漂移条件下算法鲁棒性
- **完整物理建模**：kT/C噪声、比较器热噪声、电容失配
- **学术级可视化**：SNDR趋势曲线、MSE热力图、功耗对比

---

## 项目结构

```
SAR_ADC_Verification/
├── Code/
│   ├── Modularized_Framework/
│   │   ├── Core/
│   │   │   ├── main.m                         # 主运行脚本
│   │   │   ├── config.m                       # 配置中心
│   │   │   ├── run_algorithm_comparison.m     # 多维度对比评估 ⭐
│   │   │   ├── run_monte_carlo.m              # 蒙特卡洛仿真
│   │   │   ├── run_main_sar.m                 # SAR量化引擎
│   │   │   ├── calc_fft.m                     # FFT分析
│   │   │   ├── generate_figures.m             # 图表生成
│   │   │   ├── generate_report.m              # 报告生成
│   │   │   └── algorithms/                    # 7个算法模块
│   │   │       ├── run_mle.m
│   │   │       ├── run_be.m
│   │   │       ├── run_dlr.m
│   │   │       ├── run_ata.m                  # v5.0
│   │   │       ├── run_ala.m                  # v3.0
│   │   │       ├── run_htla.m
│   │   │       └── run_adaptive.m
│   │   └── README.md                          # 框架说明
│   └── Modules/                               # 辅助模块
├── ComparisonResults/                         # 对比评估输出
├── ModularResults/                            # 完整验证输出
├── References/                                # 参考文献
└── README.md                                  # 本文档
```

---

## 快速开始

### 运行对比评估

```matlab
cd 'c:\Users\Administrator\Desktop\SAR_ADC_Verification\Code\Modularized_Framework\Core'
main
```

### 输出位置

| 类型 | 路径 |
|------|------|
| 图表 | `ComparisonResults/Fig_*.png` |
| 报告 | `ComparisonResults/Comparison_Report.txt` |

---

## 运行模式

在 `main.m` 中设置：

```matlab
RUN_MODE = 1;  % 完整验证框架
RUN_MODE = 2;  % 算法对比评估 (当前)
```

---

## 参考文献

1. Zhao et al., "A 16-bit 1-MS/s SAR ADC with asynchronous LSB averaging achieving 95.1-dB SNDR", IEEE JSSC, 2024
2. Miki et al., "Adaptive Tracking Average for SAR ADC", 2015
3. Huang et al., "A 5-MS/s 16-bit low-noise and low-power split sampling SAR ADC", 2025

---

## 版本信息

- 更新日期: 2025-03
- 当前版本: v3.0
- 主要更新: 多维度性能评估平台 + ATA v5.0/ALA v3.0重构
