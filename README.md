# SAR ADC 残差估计算法验证框架

## 项目概述

本项目是用于验证 SAR ADC（逐次逼近型模数转换器）残差估计算法的完整动态行为级仿真框架，支持多种算法的多维度性能评估与对比。

### 核心算法

| 算法 | 版本 | 描述 | 参考文献 |
|------|------|------|---------|
| **MLE** | - | 最大似然估计（基准） | - |
| **BE** | - | 贝叶斯估计 | - |
| **DLR** | - | 动态LSB重复 | - |
| **ATA** | v5.0 | 自适应追踪平均 | Miki 2015 |
| **ALA** | v3.0 | 异步LSB平均（1-Flip） | Zhao 2024 |

### 核心特性

- **动态行为建模**：单极性 SAR 量化器物理映射，真实残差电压输出
- **多维度扫描**：噪声范围 0.4-1.2 LSB，N_red 范围 4-24
- **严格 dBFS 归一化**：符合 IEEE 规范的 FFT 频谱分析
- **JSSC 级学术可视化**：
  - Times New Roman 字体
  - 半对数坐标频谱图
  - PDF 直方图归一化
  - 统一线宽和标记尺寸

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

- 更新日期: 2026-03-03
- 当前版本: v3.1
- 主要更新: 
  - 物理层修复：单极性 SAR 映射
  - FFT dBFS 归一化（IEEE 规范）
  - JSSC 级学术可视化
  - 数字域小数精度保留
  - DLR 算法优化
