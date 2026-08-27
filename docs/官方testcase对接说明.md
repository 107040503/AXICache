# 官方 testcase 对接说明

## 1. 顶层模块

当前顶层：

```systemverilog
axi_l2_cache #(
    .ADDR_WIDTH(32),
    .DATA_WIDTH(32),
    .ID_WIDTH(4)
) dut (...);
```

总线前缀：

- `AXI_mem_s0_*`
- `AXI_mem_s1_*`
- `AXI_mem_m_*`

控制信号采用官方页面中的名称和极性：`Rst_n` 低有效、`Cache_en` 高有效、`Wr_mode=1` 表示 write-back、`replace_mode=1` 表示 LRU。

## 2. 需要与官方材料确认的项目

官方 testcase 到达后优先核对：

1. AXI ID 宽度。
2. 是否包含 `AWREGION/ARREGION`、USER 信号。
3. `adr_end`、clear/flush 结束地址是闭区间还是开区间。
4. 是否测试 narrow transfer 或非对齐访问。
5. clear 是否要求丢弃 dirty line，flush 是否要求写回后继续保持 valid。
6. 官方 SRAM 模型是 1RW、1R1W 还是 true dual-port。

当前实现把范围结束地址解释为闭区间，clear 直接失效，flush 写回后失效。

## 3. AXI 支持范围

- `AxSIZE=2`，即每 beat 4 bytes。
- 地址 4-byte 对齐。
- FIXED、INCR、WRAP 地址生成。
- 每个 Slave 前端一次处理一个 Burst。
- 两个 Slave 可并行。
- Master 一次一个主存事务。

如果官方 testcase 使用额外 AXI sideband，可在 `axi_l2_cache` 外增加薄 wrapper；不要修改 `cache_core` 的逐 word 请求接口。

## 4. 替换主存模型

当前 `tb/axi_memory_model.sv` 只用于自测。官方 testcase 可以直接驱动 `AXI_mem_m`，或用官方 DDR/SRAM 模型替换 `u_mem`。Cache refill 和 writeback 的主存事务均为：

```text
AxLEN   = 7
AxSIZE  = 2
AxBURST = INCR
```

旁路、no-allocate 和 write-through 使用 `AxLEN=0`。

## 5. 推荐回归顺序

1. 编译官方 testcase 与 `rtl/`。
2. 先运行 reset、单端口 read miss/hit。
3. 再运行 write-back、write-through 和分配策略。
4. 再运行 LRU/LFU、clear/flush。
5. 最后运行双端口并发、随机 backpressure 和 error response。
6. 将官方失败用例单独保留为回归项，并更新 `docs/RTL仿真报告.md`。

