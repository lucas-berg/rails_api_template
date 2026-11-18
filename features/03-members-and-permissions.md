# 成员、邀请与权限

- 优先级：P0。
- 当前状态：固定四角色、邀请闭环和所有权转移已实现。
- 依赖：01、02、07；不依赖商业席位/配额。

## 权限与模型

`Member(team_id, user_id, role, status)` 对 team_id/user_id 唯一，status 为 active/removed。角色只属于成员关系，不放在全局 User 或长期 JWT。

| 角色 | 当前权限 |
| --- | --- |
| owner | 管理团队、成员和可授予角色；转移所有权；申请团队删除；管理自己的导出 |
| admin | 修改团队设置；仅邀请/调整/移除 member、viewer；查询审计、管理自己的导出 |
| member | 读取团队目录；文件等业务写入按资源策略执行 |
| viewer | 读取团队目录及允许的业务数据，不执行业务写入 |

普通 Ruby `TeamPolicy`、`MemberPolicy`、`InvitationPolicy` 和集中 `Authorization` 默认拒绝未知动作，**不使用 Pundit**。admin 不得管理 admin/owner 或提升自己；直接角色修改不能替代专门的所有权转移。

## 邀请与所有权

- Invitation 保存 normalized_email、role、SHA-256 token_digest、expires_at、accepted_at、revoked_at、invited_by_id；有效期 **7 天**。明文令牌仅作为加密邮件 outbox 的临时内容。
- 邀请邮箱规范化；每个团队邮箱至多一条待处理邀请。重发轮换令牌，旧链接失效；撤销后不能接受。
- 接受者必须登录、邮箱已确认且与目标邮箱匹配。重复接受不重复成员，也不能重新激活已被移除的成员。
- 团队行锁串行保护接受、角色变化、移除和转移；不得移除最后 owner。所有权只可转给已有有效成员，旧 owner 降为 admin。
- 删除申请中的用户不能新增成员关系或成为新 owner；所有权目标与账号删除通过用户 advisory lock 协调。
- 发送和重发在授权后使用团队级限流；这属于滥用保护，不是商业席位限制。

## 实际接口

| 接口 | 行为 |
| --- | --- |
| `GET .../members` | 有效成员目录 |
| `PATCH/PUT/DELETE .../members/:id` | 调整角色或移除；没有公共直接创建 Member 接口 |
| `GET/POST .../invitations` | 按可管理角色范围列出/创建邀请 |
| `POST .../invitations/:id/resend` | 轮换令牌并重新投递 |
| `DELETE .../invitations/:id` | 撤销邀请 |
| `POST /api/v1/invitations/accept` | 登录用户提交 token 接受 |
| `POST .../ownership_transfer` | 提交 member_id 转移所有权 |

`...` 为 `/api/v1/teams/:team_id`。另保留浏览器 `/invitations/accept` 页面，用于登录后接受邀请，不构成完整用户控制台。

## 验证与扩展

[成员测试](../spec/requests/api/v1/members_spec.rb)、[邀请测试](../spec/requests/api/v1/invitations_spec.rb) 覆盖角色边界、越权、错误邮箱、过期、撤销、令牌轮换、重复接受、成员移除后旧 JWT 失权和独立数据库连接的并发路径。业务变更、审计和邮件意图同事务回滚。

自定义角色、批量成员导入、目录同步和席位配额未实现；相关设计见 06、15，均不是当前成员协作的必需依赖。
