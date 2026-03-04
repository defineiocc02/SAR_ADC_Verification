# Git 提交规范

## 提交信息格式

遵循 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type（类型）

| 类型 | 说明 | 示例 |
|------|------|------|
| `feat` | 新功能 | 添加假死率分析模块 |
| `fix` | 修复 Bug | 修复 DLR 残差计算基准未对齐问题 |
| `docs` | 文档更新 | 更新 README API 文档 |
| `style` | 代码格式调整 | 统一代码缩进风格 |
| `refactor` | 重构代码 | 重构算法模块结构 |
| `perf` | 性能优化 | 优化蒙特卡洛仿真效率 |
| `test` | 测试相关 | 添加单元测试 |
| `chore` | 构建/工具链更新 | 更新 .gitignore 规则 |
| `revert` | 回滚提交 | Revert: fix DLR 残差计算 |

### Scope（范围）

可选的模块范围：

- `core`: 核心框架
- `algo`: 算法模块
- `viz`: 可视化模块
- `docs`: 文档
- `config`: 配置文件

### Subject（主题）

- 使用现在时态
- 首字母小写
- 不超过 50 个字符
- 不以句号结尾

**示例**：
```
feat(algo): add false freezing rate analysis module
fix(core): resolve residual baseline misalignment in DLR
docs(readme): update API documentation
```

### Body（正文）

- 详细描述变更内容
- 说明变更原因
- 每行不超过 72 个字符

**示例**：
```
fix(core): resolve residual baseline misalignment in DLR

The RMS calculation was using V_res_before_LSB while algorithms
received V_res_typ_LSB, causing baseline misalignment.

This fix ensures all algorithms use the same zero-mean baseline
for consistent performance comparison.

Impact:
- DLR compression ratio: 0.90x -> ~1.5x
- ATA compression ratio: 0.71x -> ~2.0x
```

### Footer（脚注）

- 关联 Issue 或 PR
- 标注 Breaking Changes

**示例**：
```
Closes #123
Breaking Change: API signature changed for run_ata()
```

## 提交示例

### 功能添加
```
feat(algo): add false freezing rate analysis module

Implement new module to analyze noise-induced false freezing
in ALA and HT-LA algorithms.

Features:
- Monte Carlo simulation with 50,000 samples
- Noise range: 0.4-2.0 LSB
- Output: Fig_5 and data file

Closes #42
```

### Bug 修复
```
fix(core): resolve residual baseline misalignment

Fixed RMS calculation to use V_res_typ_LSB instead of
V_res_before_LSB, ensuring consistent zero-mean baseline
across all algorithms.

This resolves the issue where DLR and ATA showed
compression ratios < 1.0 due to baseline mismatch.

Impact:
- DLR: 0.90x -> 1.5x
- ATA: 0.71x -> 2.0x
```

### 文档更新
```
docs(readme): add comprehensive API documentation

Added detailed API documentation for all 7 algorithms,
including input/output parameters and usage examples.

Also added:
- Project structure overview
- Running mode descriptions
- Version history section
```

## 分支策略

### 主分支

- `main`: 生产环境分支，只接受经过测试的代码
- `develop`: 开发分支，集成所有功能分支

### 功能分支

命名格式：`feat/<feature-name>`

**示例**：
- `feat/false-freezing-analysis`
- `feat/dlr-baseline-fix`
- `feat/documentation-overhaul`

### 修复分支

命名格式：`fix/<issue-description>`

**示例**：
- `fix/residual-baseline-misalignment`
- `fix/lut-index-collapse`

### 版本分支

命名格式：`release/v<version>`

**示例**：
- `release/v5.0.0`
- `release/v4.1.0`

## 工作流程

1. **创建功能分支**
   ```bash
   git checkout -b feat/your-feature-name
   ```

2. **开发并提交**
   ```bash
   git add .
   git commit -m "feat(algo): add your feature"
   ```

3. **推送到远程**
   ```bash
   git push origin feat/your-feature-name
   ```

4. **创建 Pull Request**
   - 填写 PR 模板
   - 请求代码审查
   - 确保所有检查通过

5. **合并到 develop**
   - 通过 Squash and Merge 保持历史清晰
   - 删除功能分支

6. **发布版本**
   - 从 `develop` 创建 `release/vX.Y.Z` 分支
   - 更新 CHANGELOG.md
   - 合并到 `main` 并打标签

## 代码审查清单

- [ ] 提交信息符合规范
- [ ] 代码通过所有测试
- [ ] 没有引入新的警告
- [ ] 更新了相关文档
- [ ] CHANGELOG.md 已更新
- [ ] 没有敏感信息泄露

## 版本标签

创建版本标签：

```bash
git tag -a v5.0.0 -m "Version 5.0.0"
git push origin v5.0.0
```

标签命名遵循 [Semantic Versioning](https://semver.org/)：

- **MAJOR**: 不兼容的 API 变更
- **MINOR**: 向后兼容的功能新增
- **PATCH**: 向后兼容的问题修复

**示例**：
- `v5.0.0` - 重大版本更新
- `v5.1.0` - 新功能添加
- `v5.1.1` - Bug 修复
