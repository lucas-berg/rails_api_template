# 邮件、站内通知与偏好

当前范围（2026-11-18）：文件、头像和业务导出已移除；使用自建 /admin、Pundit 授权及 Ransack 搜索。实现边界见 [五步计划](../doc/saas-implementation-plan.md)，测试与构建结果见 [验收记录](../doc/saas-validation.md)。

- 优先级：认证/邀请事务邮件 P0，活动通知 P1。
- 当前状态：MailDelivery outbox、固定事件通知、站内/邮件投递、偏好和失败恢复已实现。
- 依赖：01；团队活动依赖 02、03。不包含支付通知前置。

## 当前模型与投递

- MailDelivery 保存投递种类、事件键、状态、次数、租约和加密临时内容。确认、重置和邀请令牌不作为明文任务参数；Job 只接收投递记录 ID。
- 业务状态和邮件意图同事务，提交后投递；扫描任务补投遗漏任务。邀请发送前复核有效期、令牌、团队状态和邀请人的管理权限，旧邀请邮件会跳过。
- `Notification(user_id, team_id, event_key, kind, category, visible_at, read_at)` 不保存任意 payload；个人安全通知 team_id 为空。
- NotificationDelivery 记录渠道状态、重试和租约；事件键、接收人和渠道唯一约束防重复业务记录。发送前重查用户状态、团队状态和成员有效性。
- 团队删除申请/取消通知允许在 active/suspended/deletion_pending 状态投递，仍要求有效成员；其他团队活动只在 active 状态投递。
- 邮件发送采用有限重试、过期租约恢复和后台失败重试。SMTP 已发送但状态确认失败时可能重复投递，不能承诺绝对只发一次。

## 事件与偏好

当前白名单包含密码修改、账号暂停/恢复、邀请接受、成员角色变更、所有权转移、账号/团队删除申请与取消及团队删除完成。账号删除完成使用独立加密收件地址发送完成邮件，见 12。

- activity_in_app 默认 true，activity_email 默认 false；客户端只能提交布尔值。
- security_in_app/security_email 固定 true，不受活动偏好关闭影响。
- 通知文案按用户语言 → 团队语言 → en 回退，支持 en、zh-CN；邮件提供纯文本和受控链接。

## 实际接口

| 接口 | 行为 |
| --- | --- |
| `GET .../notifications` | 当前用户在该团队的可见通知 |
| `POST .../notifications/:id/read` | 仅本人消息标记已读，重复调用幂等 |
| `GET /api/v1/security_notifications` | 本人的个人安全通知 |
| `POST /api/v1/security_notifications/:id/read` | 个人安全通知已读 |
| `GET/PATCH/PUT /api/v1/notification_preferences` | 查看及更新活动通知偏好 |

`...` 为 `/api/v1/teams/:team_id`。普通用户不能通过这些入口创建任意通知或读取他人的消息。

## 验证与后续扩展

[通知请求测试](../spec/requests/api/v1/notifications_spec.rb)、[发布服务测试](../spec/services/notifications)、[邮件任务测试](../spec/jobs/send_mail_delivery_job_spec.rb) 和 [通知投递测试](../spec/jobs/send_notification_delivery_job_spec.rb) 覆盖事务回滚、去重、偏好、失效成员、过期租约、失败重试和语言回退。

营销公告、渠道送达回执、退信/投诉自动处理和支付事件未实现。部署方仍需验证实际 SMTP 送达、域名及渠道限制；配置见 [运行手册](../doc/saas-operations.md)。
