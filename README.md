# AXICache

面向中国研究生创“芯”大赛“基于 AXI 总线接口的二级 Cache 设计”赛题的 SystemVerilog 实现。

## 当前状态

- 32KB、32B Cache line、四路组相联。
- 两个 AXI4 Slave 接口和一个 AXI4 Master 接口，数据位宽 32bit。
- 支持写回、写穿、读分配、写分配、LRU、LFU、clear、flush 和 Cache bypass。
- 两个 Slave 可同周期命中不同 Cache line，包括映射到同一 set 的不同 line。
- Icarus Verilog 定向仿真通过，日志包含 `ALL_TESTS_PASS`。
- 已提供 100MHz FPGA 和 500MHz ASIC 约束目标，但尚未在 P1/Fuxi 或 ASIC 综合工具中完成时序签核。

## 快速运行

环境要求：PowerShell、Icarus Verilog 12.0 或兼容版本。

```powershell
cd AXICache
powershell -ExecutionPolicy Bypass -File .\sim\run_iverilog.ps1
```

生成文件：

- `sim/simulation.log`：测试结果和统计计数。
- `sim/compile.log`：编译器警告和错误输出。
- `sim/tb_axi_l2_cache.vcd`：顶层 AXI 与控制信号波形。
- `sim/tb_axi_l2_cache.vvp`：Icarus 仿真可执行文件。

## 目录

```text
AXICache/
├── rtl/
│   ├── axi_l2_cache.sv
│   ├── axi_cache_slave_port.sv
│   ├── axi_master_engine.sv
│   ├── cache_core.sv
│   └── cache_sram_tdp.sv
├── tb/
│   ├── axi_memory_model.sv
│   └── tb_axi_l2_cache.sv
├── sim/
│   ├── filelist.f
│   └── run_iverilog.ps1
├── constraints/
│   ├── fpga_100mhz.sdc
│   └── asic_500mhz.sdc
├── scripts/
│   ├── fpga_yosys_synth.ys
│   └── asic_dc_synth.tcl
├── reports/
│   └── README.md
└── docs/
    ├── 详细设计方案.md
    ├── RTL仿真报告.md
    ├── 竞赛指标符合性矩阵.md
    └── 官方testcase对接说明.md
```

## 接口约定

顶层为 `axi_l2_cache`。官方总线名映射为：

- `AXI_mem_s0_*`：Slave0。
- `AXI_mem_s1_*`：Slave1。
- `AXI_mem_m_*`：主存 Master。
- `Cache_en`、`Rd_alct_en`、`Wr_alct_en`、`Wr_mode`、`replace_mode`：运行时模式控制。

实现接受标准 AXI4 握手和 FIXED/INCR/WRAP 地址生成，但当前 Slave 数据访问限定为 32bit 对齐传输，即 `AxSIZE=3'd2` 且地址低两位为零；不满足条件的事务返回 `SLVERR`。每个 Slave 前端串行处理一个 Burst，两个 Slave 之间可以并行。

## 已知边界

- 主存侧一次仅允许一个 AXI 事务在途，两个同时发生的 miss 会被仲裁串行处理。
- 同一 Cache line 的双端口访问会串行化；不同 line 的命中可并行。
- 未实现 ECC、MESI/一致性、原子访问和 AXI exclusive monitor。
- SRAM 模型是可综合双端口行为模型。FPGA 应确认目标工具的 BRAM 推断结果；ASIC 应替换为工艺 SRAM macro wrapper。
- 100MHz/500MHz 是约束目标，不是当前会话中的时序实测结果。
- `scripts/` 中的 Yosys/DC 文件是流程模板；本机未安装对应工具，尚未生成综合报告。

详细设计和验证证据见 [详细设计方案](docs/详细设计方案.md) 与 [RTL仿真报告](docs/RTL仿真报告.md)。
