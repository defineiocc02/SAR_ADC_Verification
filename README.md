# SAR ADC 残差估计算法验证框架

## 项目概述

本项目是用于验证 SAR ADC（逐次逼近型模数转换器）残差估计算法的完整动态行为级仿真框架，支持多种算法的多维度性能评估与对比。

### 核心算法

| 算法 | 版本 | 描述 | 参考文献 |
|------|------|------|---------|
| **MLE** | v3.0 | 最大似然估计（基准） | - |
| **BE** | v3.0 | 贝叶斯估计 | - |
| **DLR** | v3.0 | 动态LSB重复 | - |
| **ATA** | v6.0 | 自适应追踪平均 | Miki 2015 |
| **ALA** | v5.0 | 异步LSB平均（1-Flip） | Zhao 2024 |

---

## 版本历史

### v4.1.0 (2026-03-04)

**关键修复：ATA 算法数学重构**

- ✅ 实现论文 Eq (6) + Eq (7) 的完整两阶段重构
- ✅ 分离翻转前后的累加器
- ✅ 翻转后执行除法平均 `sum_phase2 / (N-M)`

**算法修复详情：**

| 算法 | 修复前 | 修复后 |
|------|--------|--------|
| **ALA** | 使用 erfinv 高斯映射 | 使用算术平均 `(2k-N_x)/N_x` |
| **ATA** | 翻转后冻结 DAC | DAC 持续追踪 + Eq (7) 平均 |

---

### v4.0.0 (2026-03-04)

**关键修复：回归论文原始物理机制**

- ✅ ALA 删除 erfinv，使用 Eq (11) 算术平均
- ✅ ATA 实现 DAC 持续追踪，Eq (8) 步长更新
- ✅ MLE/BE LUT 生成逻辑验证

**物理机制修正：**

| 算法 | 核心公式 | sig_th 依赖 | PVT 鲁棒性 |
|------|----------|-------------|------------|
| **DLR** | Eq (9): est = Σ D | ❌ | ✅ |
| **ATA** | Eq (6)+(7): 两阶段重构 | ❌ | ✅ |
| **ALA** | Eq (11): (2k-N_x)/N_x | ❌ | ✅ |
| **MLE** | LUT 查表 | ✅ | ❌ |
| **BE** | LUT 查表 | ✅ | ❌ |

---

### v3.3.0 (2026-03-04)

**图表渲染优化**

- ✅ Y 轴缩放：`ylim([84, 93])`
- ✅ 图例位置：`Location, 'SouthEast'`
- ✅ LaTeX 转义修复
- ✅ Fig 2 注释框位置调整

---

### v3.2.3 (2026-03-04)

**接口一致性修复**

- ✅ run_ata 添加第四个输出参数 `freeze_res`

---

### v3.2.2 (2026-03-04)

**注释完善**

- ✅ run_ala.m, run_dlr.m, run_ata.m 完整版本管理

---

### v3.2.1 (2026-03-04)

**ALA 极端条件处理**

- ✅ 物理边界钳位：±2.5σ
- ✅ 低样本回退：N_x < 8 时退化为算术平均

---

### v3.2.0 (2026-03-04)

**核心算法修复**

- ✅ DLR 算法：移除错误概率映射
- ✅ ATA 算法：恢复 Miki 2015 物理机制
- ✅ ALA 算法：物理边界钳位

---

### v3.1.0 (2026-03-03)

**JSSC 级学术可视化**

- ✅ Times New Roman 字体
- ✅ 半对数坐标频谱图
- ✅ PDF 直方图归一化
- ✅ 统一线宽和标记尺寸

---

## 核心特性

- **动态行为建模**：单极性 SAR 量化器物理映射，真实残差电压输出
- **多维度扫描**：噪声范围 0.4-1.2 LSB，N_red 范围 4-24
- **严格 dBFS 归一化**：符合 IEEE 规范的 FFT 频谱分析
- **JSSC 级学术可视化**：
  - Times New Roman 字体
  - 半对数坐标频谱图
  - PDF 直方图归一化
  - 统一线宽和标记尺寸
- **PVT 鲁棒性验证**：ALA/ATA/DLR 不依赖先验噪声信息

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
│   │   │   ├── run_main_sar.m                 # SAR 量化引擎
│   │   │   ├── calc_fft.m                     # FFT 分析
│   │   │   ├── generate_figures.m             # 图表生成
│   │   │   ├── generate_report.m              # 报告生成
│   │   │   └── algorithms/                    # 7 个算法模块
│   │   │       ├── run_mle.m
│   │   │       ├── run_be.m
│   │   │       ├── run_dlr.m
│   │   │       ├── run_ata.m                  # v6.0
│   │   │       ├── run_ala.m                  # v5.0
│   │   │       ├── run_htla.m
│   │   │       └── run_adaptive.m
│   │   └── README.md                          # 框架说明
│   └── Modules/                               # 辅助模块
├── Results/                                   # 统一输出目录 ⭐
├── References/                                # 参考文献
├── archive/                                   # 归档旧代码
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
| 图表 | `Results/Fig_*.png` |
| 报告 | `Results/Report_*.txt` |
| 数据 | `Results/Data_*.mat` |

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

- 更新日期: 2026-03-04
- 当前版本: v4.1
- 主要更新: 
  - ATA 算法：实现 Eq (6)+(7) 完整两阶段重构
  - ALA 算法：删除 erfinv，使用 Eq (11) 算术平均
  - 所有算法：完善版本历史和物理机制注释
  - 图表渲染：Y轴缩放、LaTeX转义、框线位置优化
