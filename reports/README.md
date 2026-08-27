# Reports

此目录用于保存综合和时序工具生成的证据，不预置虚构结果。

预期文件：

- `yosys_stat.rpt`：通用 RTL 综合预检统计。
- `dc_check_design.rpt`：Design Compiler 设计检查。
- `dc_qor.rpt`：ASIC QoR 摘要。
- `dc_area.rpt`：面积报告。
- `dc_timing_max.rpt`、`dc_timing_min.rpt`：setup/hold 路径报告。
- `dc_constraints.rpt`：未满足约束。
- P1/Fuxi 的资源、时序和 RAM 推断报告。

当前工作机没有 Yosys、Fuxi 或 Design Compiler，以上报告尚未生成。提交前应将真实工具输出放入本目录，并同步更新 `docs/竞赛指标符合性矩阵.md`。

