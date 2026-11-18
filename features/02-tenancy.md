# 团队与多租户

- 优先级：P0。
- 当前状态：Team/Member 与共享库显式租户隔离已实现。
- 依赖：01、03；删除生命周期依赖 12，无商业计费或配额前置。

## 当前行为

- User 是全局账号，可加入多个 Team；用户验证邮箱后主动创建团队或接受邀请，不自动创建个人团队。
- `Team(name, slug, status, timezone, locale)` 与 `Member(team_id, user_id, role, status)` 持久化租户和成员关系。团队和首位 owner 在同一事务创建。
- 团队列表从当前用户 active members 查询；资源从已授权团队 scope 查询。伪造请求体中的 team_id 不能改变归属，跨团队 ID 返回 404。
- `Current.team` 用于上下文，不能代替 scope；请求和任务完成后清理。后台任务执行时从数据库复核归属和必要权限。
- 团队默认 timezone=UTC、locale=en，支持 en/zh-CN。团队 slug 自动生成并有唯一约束。

## 状态与接口

| 状态 | 行为 |
| --- | --- |
| active | 按角色开放读写 |
| suspended | 允许有效成员读取，拒绝业务写入；owner/admin 可导出，平台可受控恢复 |
| deletion_pending | 删除冷静期，立即冻结业务写入；申请者可通过删除请求接口取消 |
| deleting | 已越过取消点，幂等清理和失败重试 |
| deleted | 匿名墓碑，成员和业务数据已清理；不得恢复成正常团队 |

- `GET/POST /api/v1/teams`：列出可见团队或创建团队。
- `GET/PATCH/PUT /api/v1/teams/:id`：查看及按权限更新名称、语言、时区。
- 不提供普通 Team DELETE；`POST /api/v1/teams/:team_id/deletion_request` 进入 12 的冷静期流程。
- 平台暂停/恢复走受控 ActiveAdmin 动作，不能覆盖删除中的状态。

## 实现与并发边界

[Team](../app/models/team.rb)、[Member](../app/models/member.rb)、[TeamContextController](../app/controllers/api/v1/team_context_controller.rb)、[Authorization](../app/services/authorization.rb) 和 [Teams 服务](../app/services/teams) 共同实现范围控制。团队外键、唯一索引和状态检查在数据库层补充模型校验。

创建团队、接受邀请、转移 owner 与账号删除共享用户 advisory lock；团队内写入使用团队行锁。删除申请中的用户不能新建团队、接受新成员身份或成为新的 owner，避免绕过最后 owner 保护。

## 验证与边界

[团队请求测试](../spec/requests/api/v1/teams_spec.rb) 与 [建队并发测试](../spec/services/teams/create_concurrency_spec.rb) 覆盖首位 owner 原子性、跨团队隐藏、暂停写入和并发。成员、附件、通知、导出的隔离测试分别随对应模块提供。

本次新增独立团队业务表，不擅自把历史业务数据归到任意团队。将模板接入既有业务时，仍需制定逐表归属、回填核对和回滚方案。数据库行级安全、独立租户库和租户专属缓存平台属于后续扩展。
