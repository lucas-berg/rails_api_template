# 数据导出、删除与保留

- 优先级：删除保护 P0，异步导出 P1。
- 当前状态：团队 JSON 导出、团队删除/账号注销、冷静期取消、检查点恢复及独立删除台账已实现。
- 依赖：02、03、07、08、10、14。通用导入属于未实现扩展，无计费/取消订阅前置。

完整运维步骤、配置与故障边界见 [数据生命周期手册](../doc/saas-data-lifecycle.md)。

## 团队导出

- DataExport 归 Team 和 requested_by。owner/admin 可创建和读取自己的导出，不能读取另一位管理员的结果；暂停团队允许导出，删除中的团队不再生成/下载结果。
- 异步任务在执行和发布时复核身份、成员、角色与团队状态，下载时再次校验。任务使用执行锁/租约，重复任务不重复生成已完成结果。
- JSON 包含团队及设置、有效成员和有限用户公开字段、审计及 Document 元数据；**不包含附件二进制内容、密码、令牌、邮件加密内容或 API 凭据**。
- 返回 status 和 stage 供查询进度；stage 为 queued/snapshotting/uploading/completed/failed/expired，不是精确百分比。
- 生成前持久化 staging blob 关联，再上传到私有存储；失败可追踪和清理，不留下无法关联的上传对象。结果完成后有效 **24 小时**，过期不可下载并异步清理。
- 默认最大 JSON 50 MiB，MAX_EXPORT_BYTES 可配置且上限 500 MiB；这是运行内存/存储保护。任务有限重试，执行期间权限失效会拒绝发布。

## 删除状态与权限

- DeletionRequest 对一个主体最多有一条开放请求；主体类型仅 User/Team。默认冷静期 **7 天**，DELETION_COOLING_DAYS 支持 1—30 天。
- 团队 owner 可申请 Team 删除；用户仅可申请自己账号删除；申请与取消均校验当前密码。
- 团队申请后立即进入 deletion_pending 冻结业务写入，取消后恢复申请前 active/suspended 状态。账号冷静期继续登录以便取消，但不能新建团队、接受新成员关系或成为新 owner。
- 账号申请与实际执行时都检查最后 owner；必须先转移所有权或完成对应团队删除。用户/团队锁保护并发，不能靠延迟执行绕过。
- 请求 pending → processing → completed，失败进入 failed 并保留 stage。只有尚处 requested 检查点的 pending/failed 请求可取消；进入 processing 后不可取消。
- 开始执行先持久化不可取消决策并冻结主体，再把墓碑写入独立台账；台账成功后才清理文件、导出和业务记录。失败按检查点恢复，禁止直接硬删旁路。

## 清理范围与保留

- 清理成员、相关邀请、通知/投递/偏好、Document 私有字节与元数据、私有导出、邮件加密内容和登录会话，清除头像引用。
- 先确认远端文件实际删除再删除本地 blob 元数据；存储失败保留可重试定位信息，不把任务返回当作清理成功。
- User/Team 保留匿名墓碑以维持 ID 和审计引用；旧凭证失效，删除账号不可恢复登录。保留审计脱敏并按 **365 天**清理。
- 完成通知临时保存加密原收件地址，成功发送后清除；超过 **30 天**的残余收件地址由维护任务清理。SMTP 完成通知可能因确认失败而重复。
- 不自动清除所有数据库备份。独立文件台账必须持久保存并由运维另行保护，模板不自动提供生产备份服务。

## 实际接口与运维

| 接口/任务 | 行为 |
| --- | --- |
| `POST/GET .../exports` | 创建异步导出 202 / 本人导出列表 |
| `GET .../exports/:id`、`GET .../exports/:id/download` | 查询状态 / 授权私有下载 |
| `POST .../deletion_request` | 团队 owner 申请删除，202 |
| `POST /api/v1/user/deletion_request` | 本人申请注销，202 |
| `GET/DELETE /api/v1/deletion_requests/:id` | 申请者查询 / 携当前密码取消 |
| `data:deletions:export` | 将数据库墓碑导出为独立文件台账 |
| `data:deletions:replay` | 恢复数据库后、开放流量前重放删除台账 |

`...` 为 `/api/v1/teams/:team_id`。旧 Devise `DELETE /users` 也委托冷静期服务，不直接销毁 User。后台提供只读导出/删除查询及有原因的失败删除重试，不代用户取消。

恢复时按 **Team → User** 重放，检查创建时间指纹以防 ID 被复用。若旧备份的所有权关系仍阻塞账号删除，账号保持不可登录、恢复流程失败，必须人工修复后重放完成才开放流量。

## 已覆盖的自动验证

[导出请求](../spec/requests/api/v1/data_exports_spec.rb)、[导出任务](../spec/jobs/build_data_export_job_spec.rb)、[删除请求](../spec/requests/api/v1/deletion_requests_spec.rb)、[清理任务](../spec/jobs/process_deletion_job_spec.rb)、[存储故障恢复](../spec/jobs/process_deletion_job_storage_spec.rb)、[台账重放](../spec/services/lifecycle/replay_deletions_spec.rb) 和 [真实 Rake 任务](../spec/lib/tasks/data_lifecycle_spec.rb) 覆盖隔离、执行中失权、过期、重复任务、冷静期、最后 owner、文件删除失败、台账失败、保留清理和备份状态模拟。

这些测试不等于生产灾备演练；部署方需按手册验证独立台账持久化、真实存储故障和恢复耗时。

## 保留的后续扩展设计

通用业务导入尚未实现。未来可新增独立 Import 数据模型和接口，先做预检/预览、行级错误、业务唯一键去重和分批提交；CSV 导出需防公式注入。当前没有 imports 路由，也不将未知业务导入作为删除/导出的依赖。附件内容归档、大规模流式快照一致性和跨区域备份同样需单独设计与验收。
