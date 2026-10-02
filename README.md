# SAR ADC 残差算法行为验证

比较 MLE、贝叶斯估计、DLR、ATA、ALA、HT-LA 与自适应策略在明确噪声假设下的残差估计行为。

| 项目 | 当前范围 |
| --- | --- |
| 工程性质 | MATLAB 行为研究；部分数字数值契约可用 Octave 检查 |
| 来源与贡献 | 文献启发的算法实现与比较；工程扩展和论文电路需分别验证 |
| 当前状态 | 数值整改；历史比较图和排名待重新生成 |
| 已知边界 | 普通噪声扫描不等同 PVT；切换次数不等同实测功耗；浮点残差不等同最终整数 ADC 性能 |
| 许可 | 当前仓库缺少完整许可证文件，未据历史徽章新增授权条款 |

## 数值整改

- 各冗余比较次数使用各自的 MLE / BE 查表，禁止截取长表替代。
- 频谱入口统一到 `adc_spectrum`：直流处理、单边谱端点、满量程与窗能量有明确约定。
- 图上频谱量为 **dBFS/bin**；密度单独按输入单位平方每赫兹返回。
- 典型实验实际执行 22 次比较，未处理基准与算法输出来自同一批原始样本。
- Monte Carlo 入口为 HT-LA / Adaptive 提供它们约定的一维残差表。
- 固定随机种子的单次噪声扫描不再标为 Monte Carlo 良率。

本轮修改的检查结果以本分支 **Numerical contracts** 工作流为准。
检查覆盖查表符号、概率对称性、直流偏移不变性、已知谐波、谱功率和 Nyquist 端点；
不替代完整算法比较、文献公式复核或电路实验。

## 复现入口

MATLAB：

```matlab
addpath('tests');
run_numeric_tests;
addpath('Code/Modularized_Framework/Core');
run_algorithm_comparison;
```

Octave 可运行数值契约检查：

```bash
octave --no-gui --quiet --eval "addpath('tests'); run_numeric_tests"
```

完整绘图流程仍以 MATLAB 环境为准。每次发布保存种子、采样率、输入频率、
比较次数、查表噪声、输出量化方式、工具版本与代码版本。

## 结果与历史

- [整改记录与剩余工作](docs/AUDIT_20261002.md)
- [历史报告](Reports/README.md)
- [旧首页快照](docs/history/README_before_20261002.md)

`Results/` 和历史报告记录修复前结果，暂不用于证明算法排名、PVT 鲁棒性或期刊性能。
新的结果须在修复后的完整流程运行后生成，不通过修改旧数字来代替实验。
