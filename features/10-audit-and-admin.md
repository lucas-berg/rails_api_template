# 审计日志与运营后台

- 优先级：关键操作 P0，查询体验 P1。
- 当前状态：同事务审计、团队审计查询、独立平台角色及受控后台动作已实现。
- 依赖：01—03；生命周期运维见 12，无支付/API Key 审计前置。

## 审计

`AuditEvent` 记录可选 team_id、actor_type/id、action、target_type/id、request_id、脱敏 metadata、reason 和时间。系统清理可使用系统身份；不保存密码、完整令牌、邮件加密内容或任意原始请求体。

- 团队、成员、邀请、设置、文件和删除等关键成功操作与审计同事务；业务回滚不留下虚假成功事件。
- `GET /api/v1/teams/:team_id/audit_events` 只对 owner/admin 开放，不能读取其他团队审计。
- 业务 API 和 ActiveAdmin 均不开放审计修改/删除；维护任务按 365 天保留政策清理，删除账号/团队时脱敏相关 metadata/reason。
- 应用只读和权限控制不等于外部不可篡改存档。完整拒绝访问安全事件平台、外部归档尚未实现。

## 平台后台

| 角色 | 权限 |
| --- | --- |
| support | 只读允许的用户、团队、成员、邀请、审计、会话、投递、文件、导出及删除状态 |
| super_admin | 上述读取；受控暂停/恢复、失败投递/文件/删除重试、平台管理员维护和管理工具 |

[PlatformAuthorization](../lib/platform_authorization.rb) 默认拒绝未登记资源/动作；不能通过通用 CRUD、批量删除或直接状态编辑绕过业务服务。平台管理员不自动获得用户 API 身份。

- 暂停/恢复和人工重试要求原因，并记录 actor/request_id/reason。删除中的团队/账号或墓碑不能被普通恢复动作激活。
- `/admin/jobs`、`/admin/feature-flags` 仅 super_admin；平台用户、业务用户的登录和权限域独立。
- 导出/删除请求及删除墓碑可查询；失败删除可以受控重试。申请/取消删除仍由用户携当前密码使用 API 完成，后台不代用户发起或取消。
- 后台字段白名单隐藏原始令牌、加密投递内容、私有 blob key 等秘密。

## 验证与实现

[AuditEvent](../app/models/audit_event.rb)、[平台服务](../app/services/platform)、[后台资源](../app/admin) 为实现入口。[平台权限测试](../spec/requests/admin/platform_access_spec.rb)、[生命周期后台测试](../spec/requests/admin/data_lifecycle_spec.rb) 验证普通用户、support/super_admin 的允许与拒绝、危险动作原因及字段保护。

无感冒充用户、支付退款、API Key 管理、任意跨团队业务代操作和外部审计归档均未实现；后续增加必须独立定义授权、近期验证和审计。
