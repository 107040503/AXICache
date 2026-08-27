# AXICache RTL 仿真报告

## 1. 报告范围

本报告对应 `AXICache/rtl` 当前 SystemVerilog 源码和 `tb/tb_axi_l2_cache.sv` 定向测试平台。仿真在本次实现过程中重新编译和运行，不是对历史日志的转述。

## 2. 仿真环境

| 项目 | 配置 |
| --- | --- |
| 操作系统 | Windows，PowerShell |
| 仿真器 | Icarus Verilog 12.0 devel |
| 编译模式 | `-g2012 -Wall` |
| 仿真顶层 | `tb_axi_l2_cache` |
| DUT 顶层 | `axi_l2_cache` |
| 时钟周期 | 10ns，功能仿真假设 100MHz |
| 主存模型 | `tb/axi_memory_model.sv`，256KB byte-addressable memory |

运行命令：

```powershell
cd AXICache
powershell -ExecutionPolicy Bypass -File .\sim\run_iverilog.ps1
```

## 3. 生成证据

| 文件 | 内容 |
| --- | --- |
| `sim/compile.log` | Icarus 编译输出和数组灵敏度提示 |
| `sim/simulation.log` | 编译后仿真输出、PASS/FAIL 和统计值 |
| `sim/tb_axi_l2_cache.vcd` | 顶层控制与 AXI 波形 |
| `sim/tb_axi_l2_cache.vvp` | Icarus 编译产物 |
| `sim/filelist.f` | 可重复编译的源文件列表 |

本次日志结束标记：

```text
STAT hit=27 miss=27 bypass=2 writeback=1
ALL_TESTS_PASS
```

## 4. 验证计划与结果

| ID | 测试项目 | 激励与判定 | 结果 |
| --- | --- | --- | --- |
| TC-RST-001 | 目录初始化 | 复位后等待 1024 项扫描，`maint_busy` 拉低 | Pass |
| TC-RA-001 | Read allocate | 首次读取触发一次 8-beat refill，数据匹配主存 | Pass |
| TC-HIT-001 | Read hit | 同地址第二次读取不增加主存 read count | Pass |
| TC-WB-001 | Write-back | 写命中后主存保持旧值，Cache 返回新值 | Pass |
| TC-FLUSH-001 | Flush | dirty line 写回并失效，主存得到新数据 | Pass |
| TC-WT-001 | Write-through | 写分配后 Cache 与主存同时更新 | Pass |
| TC-WSTRB-001 | Byte strobe | `WSTRB=4'b1100` 只覆盖高 16bit | Pass |
| TC-CLEAR-001 | Clear | dirty line 直接失效且不写回 | Pass |
| TC-RNA-001 | Read no-allocate | 同地址两次 miss 均访问主存 | Pass |
| TC-WNA-001 | Write no-allocate | 数据直接写入主存，不安装 line | Pass |
| TC-BYPASS-001 | Cache disable | `Cache_en=0` 时两次读取均访问主存 | Pass |
| TC-LRU-001 | LRU | 五个同 set line 验证最近最少使用者被替换 | Pass |
| TC-LFU-001 | LFU | 设置不同访问次数，最小计数者被替换 | Pass |
| TC-DUAL-001 | 双口不同 set | 两个已缓存 line 同周期返回 | Pass |
| TC-DUAL-002 | 双口同 set | 同 set 不同 way 的两个 line 同周期返回 | Pass |
| TC-WBURST-001 | Write Burst | 四 beat INCR 写跨越 32B line 边界 | Pass |
| TC-RBURST-001 | Read Burst | 八 beat INCR 读跨越 line，逐拍数据与 `RLAST` 正确 | Pass |

## 5. 关键行为分析

### 5.1 Refill

read miss 经 `cache_core` 选择 invalid/victim way，`axi_master_engine` 发起：

```text
ARLEN   = 7
ARSIZE  = 2
ARBURST = INCR
```

八个 `RDATA` beat 组成 256bit line。最后一拍检查 `RLAST`，无错误后一次写入 8 个 word bank。

### 5.2 Writeback 与 flush

写回模式下写命中只更新 SRAM 和 dirty bit。flush 扫描到 dirty line 后发起八 beat write burst。仿真确认 flush 前主存保留旧值，flush 后主存变为 `32'hdead_beef`。

### 5.3 双 Slave 并发

测试先将两个 line 预热为 hit，再在同一时钟周期同时发出两个 AR 请求。测试平台记录两个 `RVALID` 首次出现的周期号，并要求相等。

分别验证：

- 不同 set：`0x1200` 与 `0x12a0`。
- 同 set 不同 tag/way：`0x1400` 与 `0x3400`，地址相差 `0x2000`，set index 相同。

两组均在日志中通过 `two slave hit responses complete in the same cycle` 判定。

### 5.4 替换算法

LRU 和 LFU 使用相差 `0x2000` 的地址构造同 set 冲突。测试通过主存 read burst 计数判断目标 line 是 hit 还是被替换后的 miss，避免只检查内部实现变量。

## 6. 波形检查建议

打开 `sim/tb_axi_l2_cache.vcd` 时建议分组观察：

1. `Clk`、`Rst_n`、`maint_busy`、`maint_done`。
2. `s0_arvalid/arready/rvalid/rready/rlast`。
3. `s1_arvalid/arready/rvalid/rready/rlast`。
4. `m_araddr/arlen/arvalid/arready` 和 `m_rvalid/rready/rlast`。
5. `m_awaddr/awlen/awvalid/awready`、`m_wvalid/wready/wlast`、`m_bvalid/bready`。
6. `Cache_clr`、`Cache_flush`、`Wr_mode`、`replace_mode`。

双口测试中应看到两个 Slave 的 `RVALID` 在同一周期有效。line refill 中应看到 `ARLEN=7`，随后八次 `RVALID&RREADY` 握手。

## 7. 指标解释

### 7.1 频率

testbench 使用 10ns 时钟，即按 100MHz 功能仿真。该结果只说明 RTL 在零延迟数字仿真下按此时钟驱动，没有形成死锁或功能错误，不代表 FPGA 时序已经收敛。

500MHz 仅在 `constraints/asic_500mhz.sdc` 中定义 2ns 目标。没有标准单元库、SRAM macro、综合网表或 STA 报告，不能将其表述为已达到 500MHz。

### 7.2 功能计数

最后一次回归得到：

- hit：27。
- miss：27。
- bypass：2。
- dirty line writeback：1。

计数用于确认测试确实经过命中、缺失、旁路和回写路径，不代表性能基准。

## 8. 覆盖率与残余风险

当前没有代码覆盖率工具，不能宣称行覆盖率、分支覆盖率或功能覆盖率百分比。已完成的是定向功能覆盖。

尚需增加：

- AXI `READY` 随机 backpressure。
- `BRESP/RRESP` error injection。
- 两个端口同时 miss、hit-under-miss 压力测试。
- 模式切换时存在多个 dirty line 的长时间测试。
- 16-beat WRAP Burst 和非法协议组合。
- 官方 SRAM 模型时序测试。

Icarus 的 `@* is sensitive to all words in array` 信息是大数组组合读取提示，不是功能错误。物理实现时仍需通过综合报告确认 SRAM 推断结果和关键路径。

## 9. 结论

当前 RTL 在 Icarus Verilog 12.0 下编译、运行并得到 `ALL_TESTS_PASS`。竞赛要求中的功能类项目已建立可重复仿真证据；FPGA 100MHz 与 ASIC 500MHz 尚需目标工具的实现和时序报告才能闭环。
