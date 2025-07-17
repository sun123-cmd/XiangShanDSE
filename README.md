# XiangShan LLC DSE

## Script Features

`run_coremark_with_l3_config.sh` is an automation script designed for:

1. **L3 Cache Size Configuration**: Automatically modify L3 cache configuration in `src/main/scala/top/Configs.scala`
2. **Recompilation**: Recompile XiangShan processor emulator with specified thread count
3. **CoreMark Testing**: Automatically execute CoreMark performance benchmark tests
4. **Result Comparison**: Compare results with NEMU reference model for verification

## Usage

### Basic Usage

```bash
# Use default configuration (L3 Cache = 1024KB, Compile threads = 2)
./run_coremark_with_l3_config.sh

# Specify L3 Cache size
./run_coremark_with_l3_config.sh 512    # 512KB L3 Cache
./run_coremark_with_l3_config.sh 1024   # 1MB L3 Cache  
./run_coremark_with_l3_config.sh 2048   # 2MB L3 Cache

# Specify both L3 Cache size and compile thread count
./run_coremark_with_l3_config.sh 1024 4  # 1MB L3 Cache, 4 compile threads
./run_coremark_with_l3_config.sh 2048 8  # 2MB L3 Cache, 8 compile threads
```

### Parameter Description

- **Parameter 1 (L3_CACHE_SIZE_KB)**: L3 cache size in KB
  - Default: 1024 (1MB)
  - Minimum: 256KB
  - Common values: 512, 1024, 2048, 4096

- **Parameter 2 (EMU_THREADS)**: Number of compilation threads
  - Default: 2
  - Recommended to set based on CPU core count

## L3 Cache Configuration Principles

XiangShan L3 Cache configuration formula:
```
L3_Cache_Size = sets × ways × blockSize × banks
```

Default parameters:
- **ways**: 8 (8-way set associative)
- **blockSize**: 64B (cache line size)
- **banks**: 1 (single bank)

Therefore: `sets = L3_Cache_Size_KB × 1024 ÷ (8 × 64 × 1) = L3_Cache_Size_KB × 2`

### Common Configuration Mapping

| L3 Cache Size | sets Value | Actual Capacity |
|---------------|------------|-----------------|
| 512KB         | 1024       | 512KB          |
| 1024KB        | 2048       | 1MB            |
| 2048KB        | 4096       | 2MB            |
| 4096KB        | 8192       | 4MB            |

## Script Execution Flow

1. **Parameter Validation**: Check input parameter validity
2. **Configuration Backup**: Automatically backup original `Configs.scala` file
3. **Configuration Modification**: Update L3 Cache sets value
4. **Build Cleanup**: Clear previous compilation files
5. **Recompilation**: Execute `make emu CONFIG=MinimalConfig`
6. **Test Execution**: Run CoreMark benchmark test
7. **Result Display**: Show compilation time, test time, and performance results
8. **Configuration Choice**: Ask whether to keep configuration changes

## Output Example

```
[INFO] === XiangShan L3 Cache Configuration and CoreMark Testing Script ===
[INFO] L3 Cache Size: 1024 KB
[INFO] Calculated sets value: 2048
[INFO] Compile threads: 2

[SUCCESS] Configuration file backed up to: src/main/scala/top/Configs.scala.backup.20241205_143022
[SUCCESS] L3 Cache sets value updated to: 2048
[SUCCESS] Compilation completed, time taken: 156 seconds
[SUCCESS] Generated emu file size: 67M
[SUCCESS] CoreMark test completed, time taken: 12 seconds

[SUCCESS] === Task Completion Summary ===
[INFO] L3 Cache configuration: 1024 KB (sets=2048)
[INFO] Compilation time: 156 seconds
[INFO] Test time: 12 seconds
[INFO] Backup file: src/main/scala/top/Configs.scala.backup.20241205_143022
```

## File Description

- **`src/main/scala/top/Configs.scala`**: XiangShan processor configuration file
- **`build/emu`**: Compiled processor emulator executable
- **`ready-to-run/coremark-2-iteration.bin`**: CoreMark test program
- **`ready-to-run/riscv64-nemu-interpreter-so`**: NEMU reference model

## Important Notes

1. **Environment Requirements**: Ensure NOOP_HOME environment variable is properly set
2. **Dependency Check**: Script automatically checks for required file existence
3. **Backup Mechanism**: Creates timestamped backup files on each run
4. **Error Handling**: Automatically restores original configuration on compilation failure
5. **Interactive Confirmation**: Option to keep or revert configuration changes after testing

## Performance Analysis Recommendations

Impact of different L3 Cache sizes on CoreMark performance:

- **512KB**: Basic configuration, suitable for resource-constrained environments
- **1MB**: Balanced configuration, recommended for daily use
- **2MB**: High-performance configuration, improves cache hit rate
- **4MB**: Large capacity configuration, suitable for big data processing

It's recommended to test multiple configurations and compare performance results to find the most suitable configuration for your application scenario.

## Troubleshooting

1. **Compilation Failure**: Check environment variables and dependencies
2. **Missing Test Files**: Verify file integrity in ready-to-run directory
3. **Permission Issues**: Ensure script has execute permissions (`chmod +x`)
4. **Insufficient Memory**: Reduce compilation thread count or increase system memory

Example for DSE on CoreMark:

```bash
make clean
make verilog
make sim-verilog CONFIG=MinimalConfig
make emu CONFIG=MinimalConfig EMU_THREADS=2 -j32
./build/emu -b 0 -e 0 -i ./ready-to-run/coremark-2-iteration.bin --diff ./ready-to-run/riscv64-nemu-interpreter-so
```


## Contact Information

For questions or suggestions, please contact: Wenhao Sun 
### Run with simulator



## Troubleshooting Guide

[Troubleshooting Guide](https://github.com/OpenXiangShan/XiangShan/wiki/Troubleshooting-Guide)

## Acknowledgement

The implementation of XiangShan is inspired by several key papers. We list these papers in XiangShan document, see: [Acknowledgements](https://docs.xiangshan.cc/zh-cn/latest/acknowledgments/). We very much encourage and expect that more academic innovations can be realised based on XiangShan in the future.

## LICENSE

Copyright © 2020-2025 Institute of Computing Technology, Chinese Academy of Sciences.

Copyright © 2021-2025 Beijing Institute of Open Source Chip

Copyright © 2020-2022 by Peng Cheng Laboratory.

XiangShan is licensed under [Mulan PSL v2](LICENSE).
