# SAR_ADC_Verification

![状态](https://img.shields.io/badge/%E7%8A%B6%E6%80%81-%E5%8E%9F%E5%9E%8B%E9%AA%8C%E8%AF%81-0969da?style=flat-square) ![类型](https://img.shields.io/badge/%E7%B1%BB%E5%9E%8B-%E6%95%B0%E5%80%BC%E9%AA%8C%E8%AF%81-6e7781?style=flat-square) ![技术栈](https://img.shields.io/badge/%E6%8A%80%E6%9C%AF%E6%A0%88-MATLAB-6e7781?style=flat-square) ![许可](https://img.shields.io/badge/%E8%AE%B8%E5%8F%AF-%E6%9C%AA%E6%8C%87%E5%AE%9A-6e7781?style=flat-square)

> 16-bit SAR ADC 冗余残差估计算法的 MATLAB 行为级数值验证与对比。

## 这是什么

在明确的噪声与失配假设下，比较 MLE、BE、DLR、ATA、ALA、HT-LA、Adaptive 七种冗余残差估计算法对 16-bit SAR ADC 动态性能的影响。模型包含 kT/C 采样噪声、比较器热噪声、单位电容失配、AR-1 慢漂移与基准下垂，输出 SNDR、残差压缩比与频谱图。仓库同时提供一组可在 Octave 下自动运行的数值契约测试，用于锁定查表与频谱计算的约定，而不是验证某个电路指标。

## 当前状态

| 项 | 值 |
|---|---|
| 阶段 | 数值整改完成，图表待重跑（原型 / 研究性验证） |
| 最近验证 | 2026-10-19 CI `Numerical contracts` 在 `main`（`0e7d6de`）通过；覆盖查表符号与端点、谱功率守恒、直流偏移不变性、Nyquist 与奇数点记录 |
| 关键指标 | 16-bit、1 MSPS、`A_in = 0.99·V_ref`、`N_red = 22`、`σ_n = 0.8 LSB` 下 ALA SNDR 97.02 dB（**修复前历史值**，见 `Results/Report_SAR_Comparison_20260305_093725.txt`；整改后尚未重跑，不作当前结论） |
| 结论边界 | SNDR 只在上述浮点行为级条件下成立；不含 PVT、比较器建立、相关噪声、功耗与硅片数据。`Results/` 的图表不用于证明算法排名 |

`Results/` 下 12 个文件是冻结的历史证据，均**早于**数值整改提交 `8c34d78`（2026-10-02），未经重新生成：

| 文件 | 最后更新提交 | 说明 |
|---|---|---|
| `Results/Fig_1_SNDR_vs_Sigma_PVT.png` / `.eps` | `1128c3d`（2026-03-05） | SNDR–比较器噪声扫描 |
| `Results/Fig_2_FFT_Spectrum_Comparison.png` / `.eps` | `1128c3d` | 典型工况频谱对比 |
| `Results/Fig_3_SNDR_vs_Nred.png` / `.eps` | `1128c3d` | 收敛效率 |
| `Results/Fig_4_Residual_PDF_Dynamic.png` / `.eps` | `1128c3d` | 残差分布与压缩比 |
| `Results/Data_Dynamic_Results.mat` | `1128c3d` | 上述图对应的 `results` / `cfg` |
| `Results/Report_SAR_Comparison_20260305_093725.txt` | `1fd688a`（2026-03-05） | 与 `Reports/` v1.3.0 报告对应的数据源 |
| `Results/Report_SAR_Comparison_20260304_162151.txt`、`..._162851.txt` | `76a05d5`（2026-03-04） | 更早两次运行，留作对照 |

## 快速开始

### 依赖

- MATLAB R2024a 或更新版本（`Results/` 内报告由 R2024a Update 6 / `24.1.0.2689473` 生成；更早版本未验证）。
- 主流程只用到 base MATLAB，不需要额外 toolbox；`Code/Modules/microLUT.m` 例外，它调用 `blackmanharris`，需要 Signal Processing Toolbox。
- Octave（CI 在 `ubuntu-latest` 上通过 apt 安装，版本随镜像浮动）只够跑 `tests/` 的数值契约，不能跑完整绘图流程。

### 运行

```bash
git clone git@github.com:defineiocc02/SAR_ADC_Verification.git
cd SAR_ADC_Verification
matlab -batch "cd Code/Modularized_Framework/Core; main"
```

入口是 `Code/Modularized_Framework/Core/main.m`，运行模式由该文件第 17 行的 `RUN_MODE` 决定：

| `RUN_MODE` | 内容 | 输出位置 |
|---|---|---|
| 1 | 完整框架：`config` → `run_monte_carlo` → `generate_figures` → `generate_report` | `ModularResults/`（未跟踪，近期未重跑） |
| 2 | 多维度算法对比（当前默认） | `Results/`：`Fig_1`–`Fig_4` 的 png/eps、`Report_SAR_Comparison_<时间戳>.txt`、`Data_Dynamic_Results.mat` |
| 3 | 假死率分析（1-Flip ALA vs 2-Flip HT-LA） | `Results/`：`Fig_5_False_Freezing_Rate.png/.eps`、`Data_False_Freezing_Results.mat` |

模式 2 会覆盖 `Results/` 里已被跟踪的文件，跑完 `git status` 会变脏——这是预期行为，不要为了保持干净而回退这些文件。

### 验证

```bash
octave --no-gui --quiet --eval "addpath('tests'); run_numeric_tests"
```

通过时打印 `PASS: count-specific likelihood, signed endpoints, spectral power, DC invariance, Nyquist and odd records.`，任一断言失败即非零退出。该测试同时是 CI 的唯一检查入口。

## 目录结构

```
Code/Modularized_Framework/Core/          当前入口 main.m，配置、对比、蒙特卡洛、假死率与出图脚本
Code/Modularized_Framework/Core/algorithms/  7 种残差估计算法实现
Code/Modules/                             早期单脚本实验，不被 Core 调用
tests/                                    Octave/MATLAB 数值契约测试（CI 入口）
Results/                                  已冻结的历史图表与报告（整改前生成）
Reports/                                  技术报告 v1.3.0 及报告管理规范
docs/                                     整改审计与旧首页快照
archive/                                  旧核心脚本与旧结果，不参与现行流程
References/                               4 篇参考论文 PDF
```

## 设计与用法

**前置条件（所有频谱量）**：记录必须是长度 ≥ 16 的有限实数序列，否则 `ADC:InvalidRecord`；`fs`、满量程峰值、`f_in` 必须为正标量且 `f_in < fs/2`。FFT 前先减去均值，因此直流只从记录中移除，不是在功率里扣除。单边谱取 `floor(N/2)+1` 个 bin，偶长度只对 `2..end-1` 翻倍，**Nyquist bin 不翻倍**。窗能量归一化后 `density = |X|²/(fs·Σw²)`，`bin_power = density·fs/N`，参考功率取 `full_scale_peak²/2`（满量程正弦的 RMS 功率），因此纵轴单位是 **dBFS/bin**，不是密度；密度单位是输入单位的平方每赫兹。实现见 [adc_spectrum.m](Code/Modularized_Framework/Core/adc_spectrum.m)，不做 100/120 dB 之类的人为饱和。

**SNDR**。仓库内有两条路径，数值不应混用：

1. 对比主路径（`RUN_MODE=2`）：矩形窗、要求相干采样，`SNDR = 10·log10(P_fund / Σ_{k≠DC,fund} P_k)`，即除直流与基频外所有 bin 的功率都算进分母。谐波因此计入噪声项，得到的是 SNDR 而非 SNR。基频必须落在 bin 上，偏差超过 `df·1e-7` 直接报 `ADC:Noncoherent`。
2. 正弦拟合路径（`adc_spectrum` 第三输出）：对 `[1, sin, cos]` 做最小二乘拟合，信号功率取拟合音的方差，噪声功率取残差均方值，同样保留谐波。该路径允许 Blackman-Harris 窗（`2πn/(N-1)` 形式，ENBW = `fs·Σw²/(Σw)²`），不强制相干。

两条路径的退化行为一致：全直流记录返回 `NaN`，零噪声返回 `Inf`，不设上限。CI 用 `0.8` 幅度基频加 `0.008` 幅度三次谐波锁定 40 dB 的理论值来校验。

**ENOB**。仓库内没有 ENOB 计算，代码中不存在 `6.02` / `1.76` 常量。若需换算只能按 `ENOB = (SNDR − 1.76)/6.02` 自行派生，前提是满量程正弦输入且 SNDR 含谐波；这是派生量，不是本仓库的输出，不应作为独立证据引用。

**SFDR**。只在独立脚本 [microLUT.m](Code/Modules/microLUT.m) 中计算，不在 Core 管线内，也不被 CI 覆盖。条件为 16384 点、输入落在第 53 bin、幅度 90% 满量程、`σ_n = 0.6 LSB`、`N_red = 22`、`rng(2026)`；加 Blackman-Harris 窗并做相干增益补偿，幅度按 `20·log10(|Y|/(N/2)/win_cg/A_sig)` 归一化到 dBc。计算时遮蔽基频 ±10 个 bin，取剩余 bin 最大值，`SFDR = −max(P_spur)`。注意该脚本不强制相干采样容差，±10 bin 的掩蔽会隐藏近载杂散，且只对比"线性估算"与"6-bit 微表补偿"两条曲线。

**残差压缩比**。定义为 `RMS(处理前) / RMS(处理后)`，两侧使用同一零均值基线 `V_res_LSB = V_res/V_LSB − 0.5`；小于 1 表示该算法在当前条件下反而放大了残差。

**相干采样参数**。`RUN_MODE=2` 用 `N_FFT = 8192`、`N_prime = 127`、`fs = 1 MHz`，即 `f_in = 127/8192·fs ≈ 15.503 kHz`；幅度取 `0.99·V_ref`，对应报告里注明的 0.09 dB 幅度损失。噪声扫描 16 点覆盖 0.25–1.0 LSB，冗余周期扫描为 `[4 8 12 16 20 24]`，种子固定 `20261002`——这是**单次噪声实现**，不是蒙特卡洛良率。

## 已知限制

- 全部结果是浮点行为级仿真，不含 PVT、比较器建立、相关噪声与功耗；96–97 dB 量级的 SNDR 不能外推到硅片或论文指标。
- `Results/` 与 `Reports/` 的数值均由整改前代码（`1128c3d` 及更早）产生，`8c34d78` 修正了查表分母与频谱约定后尚未重跑，因此这些图表不能用于算法排名。
- 比较脚本中漂移项对估计器可见，属于 oracle 条件；Adaptive 也使用了输入噪声参数选择策略，不能宣称完全无需先验。
- SFDR 只存在于独立脚本，口径与 Core 的 dBFS/bin 不同，且未被 CI 保护，容易随重构失效。
- `RUN_MODE=1` 的完整框架输出到 `ModularResults/`，该目录未跟踪、近期无运行记录，可用性未验证。

## 相关仓库

暂无直接关联的仓库。

## 许可

未指定许可证，保留所有权利。仓库内没有 `LICENSE` 文件，因此也不提供任何再分发或商用授权；如需复用请先联系仓库所有者。
