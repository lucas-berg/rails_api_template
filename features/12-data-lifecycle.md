# 账号与团队删除

保留删除申请、七天冷静期、取消、不可逆阶段、匿名化、失败重试及独立台账重放。业务数据导出和通用导入不在当前范围。

删除使用 Pundit 权限检查，唯一 owner 必须先转移所有权；任务重查权限和状态。删除阶段简化为 requested → ledger → records → completed，移除文件及导出清理。

接口保留 POST /api/v1/user/deletion_request、POST /api/v1/teams/:team_id/deletion_request、GET/DELETE /api/v1/deletion_requests/:id；DELETE /users 接入同一申请服务。

恢复工具 data:deletions:export / replay 处理独立删除台账，不是业务导出。详细操作和保留周期见 [运行说明](../doc/saas-data-lifecycle.md)。
