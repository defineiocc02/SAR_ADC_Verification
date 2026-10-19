---
alwaysApply: false
description: 
---
# SAR ADC 验证项目 - Agent 操作指南

## ⚠️ 三大铁律 (必须遵守!)

1. **所有输出必须到 `Results/` 目录** - 严禁在其他位置创建文件!
2. **只运行 `Code/Modularized_Framework/Core/` 中的脚本** - `Code/Modules/` 是函数库，不要直接运行!
3. **保持随机种子 2026, N_MC≥30** - 确保结果可复现和统计意义!

## 📁 路径结构

```
SAR_ADC_Verification/
├── Code/
│   ├── Modularized_Framework/Core/  # 仅此目录可运行 (当前入口)
│   │   ├── main.m                   # 主运行脚本 (入口)
│   │   ├── config.m                 # 全局配置
│   │   ├── run_algorithm_comparison.m    # 多维度对比
│   │   ├── run_false_freezing_analysis.m # 假死率分析
│   │   ├── run_monte_carlo.m        # 蒙特卡洛仿真
│   │   ├── run_main_sar.m           # SAR 量化引擎
│   │   ├── calc_fft.m               # FFT 分析
│   │   ├── generate_figures.m       # 图表生成
│   │   ├── generate_report.m        # 报告生成
│   │   └── algorithms/              # 7 种残差估计算法
│   └── Modules/                     # 函数库 (不直接运行)
├── Results/                         # 所有输出到这里
│   ├── Fig_*.png / Fig_*.eps        # 图表
│   ├── Report_*.txt                 # TXT 报告
│   └── Data_*.mat                   # 数据
├── archive/
│   ├── old_core/                    # 已归档: Integrated_SAR_ADC_Verification.m、Clean_Baseline_Verification.m (勿运行)
│   └── old_results/                 # 已归档: 历史图表与报告
└── References/                      # 只读 PDF
```

> 注: 旧脚本 `Integrated_SAR_ADC_Verification.m` / `Clean_Baseline_Verification.m` 已归档至 `archive/old_core/`，现行流程使用 `Code/Modularized_Framework/Core/main.m`。

## 🚀 标准操作流程

```matlab
% 步骤 1: 切换到 Core 目录 (仓库根目录下)
cd('Code/Modularized_Framework/Core')

% 步骤 2: 运行主入口 (RUN_MODE 见 Core/README.md)
main
```

## 🔧 修改代码前 5 步思考

1. **理解目标** - 用户要什么？是否已有实现？
2. **定位代码** - 搜索并阅读至少 3 个相关文件
3. **理解约定** - 命名风格 (ADC.N_main)、中文注释、IEEE 规范
4. **评估影响** - 路径？可复现性？物理参数冲突？
5. **实施验证** - 小步修改，运行后检查 Results/

## 🎨 代码规范

- **命名**: `ADC.N_main`, `SS.Cs` (结构体 + 字段)
- **注释**: 中文 + 英文术语
- **调色板**: `COLOR.mle=[0.20,0.40,0.80]`, `COLOR.htla=[0.85,0.15,0.15]`
- **图表**: Times New Roman 字体，线宽 2.0，保存到仓库根目录 `Results/`

## ⚠️ 常见错误

| 错误 | 后果 | 避免 |
|------|------|------|
| 错误目录运行 | 文件丢失 | 始终从 `Code/Modularized_Framework/Core/` 运行 |
| 改随机种子 | 不可复现 | 保持 seed=2026 |
| N_MC<30 | 统计不足 | 出图必须≥30 |
| 运行 Modules / archive 旧脚本 | 报错或产出过期结果 | 只运行 `Core/` 脚本 |

## ✅ 提交前检查清单

- [ ] 输出都在 `Results/`
- [ ] 随机种子=2026
- [ ] N_MC≥30
- [ ] 图表符合 IEEE 规范
- [ ] 未改 References/PDF
- [ ] 中文注释 + 规范命名

## 📞 不确定时

1. 搜索代码库 (SearchCodebase)
2. 阅读至少 3 个相关文件
3. 小步验证，每次改一个点
4. 检查 Results/ 输出

---
**更新**: 2026-10-19 | **维护**: SAR ADC 团队
