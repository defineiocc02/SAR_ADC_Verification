# SAR ADC 验证框架 - 模块化版本

## 项目概述

本框架提供SAR ADC残差估计算法的多维度性能评估，支持7种算法的对比分析。

---

## 项目结构

```
Modularized_Framework/
├── Core/
│   ├── main.m                         # 主运行脚本 (入口)
│   ├── config.m                       # 全局配置
│   ├── run_algorithm_comparison.m    # 多维度对比评估 ⭐
│   ├── run_monte_carlo.m             # 蒙特卡洛仿真
│   ├── run_main_sar.m                # SAR量化引擎
│   ├── calc_fft.m                    # FFT分析
│   ├── generate_figures.m             # 图表生成
│   ├── generate_report.m             # 报告生成
│   └── algorithms/                   # 算法模块
│       ├── run_mle.m                 # MLE
│       ├── run_be.m                  # BE
│       ├── run_dlr.m                 # DLR
│       ├── run_ata.m                 # ATA v5.0
│       ├── run_ala.m                 # ALA v3.0
│       ├── run_htla.m                # HT-LA
│       └── run_adaptive.m            # Adaptive
└── README.md                          # 本文档
```

---

## 快速开始

```matlab
cd 'c:\Users\Administrator\Desktop\SAR_ADC_Verification\Code\Modularized_Framework\Core'
main
```

---

## 运行模式

| RUN_MODE | 功能 |
|----------|------|
| 1 | 完整验证框架 (已注释) |
| 2 | 多维度算法对比评估 (当前) |

---

## 算法版本说明

| 算法 | 版本 | 核心逻辑 |
|------|------|---------|
| **ATA** | v5.0 | 动态追踪 + 两段式拼接 + Watchdog |
| **ALA** | v3.0 | 1-Flip冻结 + 两段式线性映射 + Watchdog |

### ATA v5.0 特性 (Miki 2015)
- 翻转后继续动态追踪（移动靶子）
- D_DEC解码：(1,0)/(0,1)保持， (1,1)=+1， (0,0)=-1
- 两段式拼接：Pre-Toggle求和 + Post-Toggle平均
- Watchdog：60%预算未翻转强制处理

### ALA v3.0 特性 (Zhao 2024)
- 1-Flip后立即冻结（固定靶子）
- 两段式线性映射：`V_res^ = Search_Sum + (2k-(N-x))/(N-x) * LSB`
- 不依赖噪声参数，抗PVT漂移
- Watchdog：60%预算未翻转强制冻结

---

## 对比评估特性

- **噪声扫描**：0.4 - 1.2 LSB (9点)
- **初始误差扫描**：0 - 4.0 LSB (9点)
- **Monte Carlo**：50次/配置
- **LUT错位测试**：验证PVT漂移鲁棒性

---

## 输出说明

| 类型 | 路径 |
|------|------|
| 对比图表 | `Results/Fig_*.png` |
| 对比报告 | `Results/Report_*.txt` |
| 数据文件 | `Results/Data_*.mat` |

---

## 版本信息

- 更新日期: 2025-03
- 版本: v3.0
