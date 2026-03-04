# 版本管理策略

## 版本号规范

遵循 [Semantic Versioning 2.0.0](https://semver.org/)：

```
MAJOR.MINOR.PATCH
```

### 版本号规则

| 类型 | 说明 | 示例 |
|------|------|------|
| **MAJOR** | 不兼容的 API 变更 | v5.0.0 → v6.0.0 |
| **MINOR** | 向后兼容的功能新增 | v5.0.0 → v5.1.0 |
| **PATCH** | 向后兼容的问题修复 | v5.1.0 → v5.1.1 |

### 预发布版本

```
MAJOR.MINOR.PATCH-<pre-release>.<build>
```

**示例**：
- `v5.1.0-alpha.1` - Alpha 测试版
- `v5.1.0-beta.2` - Beta 测试版
- `v5.1.0-rc.1` - Release Candidate

## 分支策略

### 分支结构

```
main (生产)
  ↑
  └── develop (开发)
         ↑
         ├── feat/* (功能分支)
         ├── fix/* (修复分支)
         └── release/* (发布分支)
```

### 主分支

#### `main`
- **用途**: 生产环境分支
- **保护规则**:
  - 禁止直接推送
  - 必须通过 Pull Request
  - 必须通过 CI/CD 检查
  - 必须有代码审查批准
- **内容**: 稳定的、经过测试的代码
- **发布**: 每次合并创建版本标签

#### `develop`
- **用途**: 开发集成分支
- **保护规则**:
  - 禁止直接推送
  - 必须通过 Pull Request
  - 必须通过 CI/CD 检查
- **内容**: 所有功能分支的集成
- **发布**: 定期合并到 `main`

### 功能分支

#### 命名规范
```
feat/<feature-name>
```

**示例**：
- `feat/false-freezing-analysis`
- `feat/dlr-baseline-fix`
- `feat/documentation-overhaul`

#### 生命周期
1. 从 `develop` 创建
2. 开发并提交
3. 创建 Pull Request 到 `develop`
4. 代码审查
5. 合并后删除分支

### 修复分支

#### 命名规范
```
fix/<issue-description>
```

**示例**：
- `fix/residual-baseline-misalignment`
- `fix/lut-index-collapse`
- `fix/double-compensation`

#### 生命周期
1. 从 `develop` 或 `main` 创建（根据紧急程度）
2. 快速修复
3. 创建 Pull Request
4. 优先代码审查
5. 合并后删除分支

### 发布分支

#### 命名规范
```
release/v<version>
```

**示例**：
- `release/v5.0.0`
- `release/v4.1.0`

#### 生命周期
1. 从 `develop` 创建
2. 更新版本号
3. 更新 CHANGELOG.md
4. 创建版本标签
5. 合并到 `main` 和 `develop`
6. 删除分支

## 发布流程

### 1. 准备发布

```bash
# 从 develop 创建发布分支
git checkout develop
git pull origin develop
git checkout -b release/v5.0.0
```

### 2. 更新版本信息

#### 更新版本号

在以下文件中更新版本号：
- `README.md` - 版本徽章
- `CHANGELOG.md` - 版本历史
- `Code/Modularized_Framework/README.md` - 模块版本

#### 更新 CHANGELOG.md

```markdown
## [5.0.0] - 2026-03-04

### Added
- 新功能 1
- 新功能 2

### Changed
- 变更 1
- 变更 2

### Fixed
- 修复 1
- 修复 2

### Deprecated
- 废弃的功能

### Removed
- 移除的功能

### Security
- 安全修复
```

### 3. 测试发布

```bash
# 运行完整测试套件
cd Code/Modularized_Framework/Core
main
```

### 4. 创建版本标签

```bash
# 提交所有更改
git add .
git commit -m "chore(release): prepare release v5.0.0"

# 创建带注释的标签
git tag -a v5.0.0 -m "Version 5.0.0

New Features:
- Add false freezing rate analysis module
- Add RUN_MODE 3 for FFR analysis

Critical Fixes:
- Fix residual baseline misalignment
- Fix LUT index collapse
- Fix double compensation issue

Documentation:
- Update README with API documentation
- Add comprehensive CHANGELOG"
```

### 5. 合并到主分支

```bash
# 合并到 main
git checkout main
git merge release/v5.0.0
git push origin main
git push origin v5.0.0
```

### 6. 合并回 develop

```bash
# 合并回 develop
git checkout develop
git merge release/v5.0.0
git push origin develop
```

### 7. 清理发布分支

```bash
# 删除本地和远程分支
git branch -d release/v5.0.0
git push origin --delete release/v5.0.0
```

## 版本历史管理

### CHANGELOG.md 规范

遵循 [Keep a Changelog](https://keepachangelog.com/) 格式：

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- 新功能（未发布）

## [5.0.0] - 2026-03-04

### Added
- 新功能 1
- 新功能 2

### Changed
- 变更 1

### Fixed
- 修复 1

## [4.0.0] - 2026-02-28

### Added
- 新功能 1
```

### 版本标签管理

#### 查看所有标签
```bash
git tag -l
```

#### 查看标签详情
```bash
git show v5.0.0
```

#### 删除标签
```bash
# 本地
git tag -d v5.0.0

# 远程
git push origin --delete v5.0.0
```

## 回滚策略

### 回滚到上一个版本

```bash
# 查看历史
git log --oneline

# 回滚到指定标签
git checkout v5.0.0

# 或创建回滚分支
git checkout -b hotfix/rollback-v5.0.0 v5.0.0
```

### 紧急修复流程

1. 从 `main` 创建 `hotfix/*` 分支
2. 快速修复问题
3. 测试验证
4. 合并到 `main` 并打新标签
5. 合并回 `develop`

```bash
git checkout main
git checkout -b hotfix/critical-bug
# ... 修复 ...
git commit -m "fix: critical bug fix"
git checkout main
git merge hotfix/critical-bug
git tag -a v5.0.1 -m "Hotfix v5.0.1"
git push origin main v5.0.1
```

## 代码审查流程

### Pull Request 模板

```markdown
## 变更类型
- [ ] 新功能
- [ ] Bug 修复
- [ ] 文档更新
- [ ] 性能优化
- [ ] 代码重构

## 变更描述
简要描述本次变更的内容和目的

## 测试情况
- [ ] 单元测试通过
- [ ] 集成测试通过
- [ ] 手动测试通过

## 关联 Issue
Closes #123

## 检查清单
- [ ] 代码符合项目规范
- [ ] 提交信息符合规范
- [ ] 没有引入新的警告
- [ ] 更新了相关文档
- [ ] CHANGELOG.md 已更新
```

### 审查标准

1. **代码质量**
   - 代码清晰易读
   - 遵循项目编码规范
   - 没有明显的性能问题

2. **功能正确性**
   - 实现符合需求
   - 边界条件处理正确
   - 错误处理完善

3. **测试覆盖**
   - 有足够的测试用例
   - 测试覆盖主要场景
   - 所有测试通过

4. **文档完整性**
   - API 文档已更新
   - 使用示例已提供
   - CHANGELOG.md 已更新

## 持续集成/持续部署 (CI/CD)

### 自动化检查

每次 Pull Request 触发以下检查：

1. **代码风格检查**
   - MATLAB 代码规范
   - 文件命名规范

2. **静态分析**
   - MATLAB Code Analyzer
   - 代码复杂度检查

3. **单元测试**
   - 算法模块测试
   - 核心功能测试

4. **集成测试**
   - 完整仿真流程测试
   - 性能基准测试

### 发布自动化

合并到 `main` 后自动执行：

1. 创建版本标签
2. 生成发布说明
3. 部署到生产环境
4. 通知相关团队

## 版本兼容性

### 向后兼容性

- **MINOR** 和 **PATCH** 版本必须保持向后兼容
- **MAJOR** 版本可以破坏向后兼容性
- 废弃的 API 必须至少保留一个 MINOR 版本

### 迁移指南

当引入破坏性变更时，提供迁移指南：

```markdown
## Migration Guide for v6.0.0

### Breaking Changes

#### API Signature Changes

**Old API:**
```matlab
[est, pwr_switch] = run_dlr(V_res, N_red, sig_th)
```

**New API:**
```matlab
[est, pwr_switch, k_final] = run_dlr(V_res, N_red, sig_th, RW_drift)
```

**Migration Steps:**
1. Add `k_final` to output variables
2. Pass `RW_drift` parameter (can be empty array if not needed)
```

## 版本发布检查清单

### 发布前
- [ ] 所有功能已实现
- [ ] 所有 Bug 已修复
- [ ] 所有测试通过
- [ ] 文档已更新
- [ ] CHANGELOG.md 已更新
- [ ] 版本号已更新
- [ ] 代码审查已完成

### 发布时
- [ ] 创建发布分支
- [ ] 创建版本标签
- [ ] 合并到 main
- [ ] 合并回 develop
- [ ] 删除发布分支

### 发布后
- [ ] 推送标签到远程
- [ ] 生成发布说明
- [ ] 通知团队成员
- [ ] 更新文档网站
- [ ] 监控生产环境

## 版本命名约定

### 稳定版本
- `v5.0.0` - 正式发布版本

### 开发版本
- `v5.1.0-dev` - 开发中版本

### 预发布版本
- `v5.1.0-alpha.1` - Alpha 测试版
- `v5.1.0-beta.1` - Beta 测试版
- `v5.1.0-rc.1` - Release Candidate

## 参考资源

- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Flow](https://guides.github.com/introduction/flow/)
