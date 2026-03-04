# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [5.0.0] - 2026-03-04

### Added
- New `run_false_freezing_analysis.m` module for False Freezing Rate analysis
- New RUN_MODE 3: False Freezing Rate analysis in `main.m`
- New Fig_5: False Freezing Rate vs. Comparator Noise curve
- JSSC-style visualization for false freezing rate comparison
- Comprehensive Git commit conventions document (`.trae/docs/GIT_COMMIT_CONVENTIONS.md`)
- Version management strategy document (`.trae/docs/VERSION_MANAGEMENT.md`)
- Enhanced `.gitignore` with comprehensive rules for MATLAB and development files

### Fixed
- **Critical**: Fixed residual calculation baseline misalignment for DLR/ATA/HT-LA/Adaptive
  - Changed from `V_res_before_LSB` to `V_res_typ_LSB` in RMS calculations
  - Ensures all algorithms use the same zero-mean baseline
- **Performance**: DLR residual compression ratio improved from 0.90x to ~1.5x
- **Performance**: ATA residual compression ratio improved from 0.71x to ~2.0x
- **Code Quality**: Removed all unused variables and linter warnings
- **Code Quality**: Modernized date functions from `datestr(now)` to `datetime("now")`

### Changed
- Output directory path in `run_false_freezing_analysis.m` corrected to project root `Results/`
- Enhanced code comments in `run_false_freezing_analysis.m` with detailed physical background
- Removed temporary log file `run_log_fixed.txt`

### Documentation
- Updated README.md with version badge and comprehensive API documentation
- Updated CHANGELOG.md with complete version history
- Added detailed Git workflow and release process documentation

## [4.1.0] - 2026-03-04

### Fixed
- **ATA Algorithm**: Implemented complete two-phase reconstruction (Eq 6 + Eq 7)
  - Separated pre-toggle and post-toggle accumulators
  - Added division averaging `sum_phase2 / (N-M)` for post-toggle phase

### Changed
- ATA algorithm version updated to v6.0

## [4.0.0] - 2026-03-04

### Fixed
- **ALA Algorithm**: Removed erfinv, using Eq (11) arithmetic average `(2k-N_x)/N_x`
- **ATA Algorithm**: Implemented DAC continuous tracking with Eq (8) step update
- **MLE/BE**: Verified LUT generation logic

### Changed
- ALA algorithm version updated to v5.0
- ATA algorithm version updated to v6.0
- DLR algorithm version updated to v6.0

## [3.3.0] - 2026-03-04

### Changed
- Y-axis scaling: `ylim([84, 93])` for SNDR plots
- Legend position: `Location, 'SouthEast'`
- LaTeX escape character fixes

## [3.2.3] - 2026-03-04

### Fixed
- Added fourth output parameter `freeze_res` to `run_ata.m`

## [3.2.2] - 2026-03-04

### Changed
- Added comprehensive comments to `run_ala.m`, `run_dlr.m`, `run_ata.m`

## [3.2.1] - 2026-03-04

### Fixed
- **ALA Algorithm**: Physical boundary clamping at ±2.5σ
- **ALA Algorithm**: Low sample fallback to arithmetic average when N_x < 8

## [3.2.0] - 2026-03-04

### Fixed
- **DLR Algorithm**: Removed incorrect probability mapping, restored integer accumulation
- **ATA Algorithm**: Restored Miki 2015 physical mechanism
- **ALA Algorithm**: Physical boundary clamping

## [3.1.0] - 2026-03-03

### Added
- JSSC-level academic visualization
  - Times New Roman font
  - Semi-logarithmic spectrum plots
  - PDF histogram normalization
  - Unified line width and marker size

## [3.0.0] - 2026-03-03

### Added
- Modularized framework structure
- 7 algorithm implementations: MLE, BE, DLR, ATA, ALA, HT-LA, Adaptive
- Multi-dimensional comparison evaluation
- PVT robustness verification

### Changed
- Complete project restructuring

## [2.0.0] - 2026-03-02

### Added
- Initial SAR ADC verification framework
- Basic algorithm implementations

## [1.0.0] - 2026-03-01

### Added
- Project initialization
- Basic SAR ADC behavioral model
