# SaaS 运行与恢复说明

本轮目标：保留账号、团队、邀请、通知、审计及删除；使用 Pundit 授权和自建 Rails /admin。文件、头像和业务导出不再提供。

## 配置与启动

按 .env.sample 配置 PostgreSQL、JWT_SECRET_KEY、稳定的 SECRET_KEY_BASE、APP_PUBLIC_URL、DEFAULT_EMAIL_SENDER、SMTP 和 RATE_LIMIT_REDIS_URL。确认与邀请链接使用公开地址，独立邀请前端可配置 INVITATION_ACCEPT_URL。

本地 Docker Compose 包含 Web、PostgreSQL 和 Redis；本机启动也需要数据库与 Redis。GoodJob 使用 PostgreSQL，Redis 仅用于共享限流。生产单独运行 `bundle exec good_job start`，启用邮件、通知和删除扫描器。

生产明确配置 CORS_ALLOWED_ORIGINS。新用户必须确认邮箱；历史未知邮箱不会自动确认。JWT 固定90天，退出/撤销、改密和封禁即时失效，恢复不会复活旧凭证。

## 登录与授权

Devise/JWT 验证身份，Pundit 判断可见资源和允许动作。User 与 AdminUser 分开登录；JSON API 仅使用 Bearer，后台浏览器使用 AdminUser Cookie 与 CSRF。任务根据实际记录恢复上下文，身份、角色、团队状态均在执行时重新检查。

平台入口为 /admin，登录 /admin/login，退出 /admin/logout。support 只读；super_admin 可维护平台管理员、封禁/恢复账号、暂停/恢复团队、重试失败投递和删除任务，必须提供原因并留下审计。GoodJob 和 Flipper 也只允许 super_admin。

后台按明确字段展示，拒绝自动 CSV/JSON 导出；不展示密码、JWT摘要、邮件密文和任务租约。无硬删除或批量写操作。

## 就绪与限流

- GET /api/v1/status 保持进程存活接口。
- GET /api/v1/ready 检查 PostgreSQL/Redis，不可用返回503且隐藏内部配置。
- 登录每IP每分钟10次；确认/重置分别每邮箱每15分钟3次；邀请每团队每小时30次。
- 多实例共享 Redis；邮箱计数键使用摘要。429 返回 Retry-After。
- request_id、job_id、team_id 关联日志；记录授权后的团队上下文，任务结束或失败清理，不记录密码/完整令牌/邮件正文。

## 邮件与通知恢复

业务写入与邮件/通知意图同事务，提交后投递。任务入队失败由周期扫描补投；发送中的租约防止旧任务覆盖新尝试结果，SMTP 本身不能保证恰好一次。

检查 SMTP、工作进程和队列，修复后由 super_admin 对失败记录填写原因重试。过期、撤销、已接受或邀请人失权的邀请不再发送；移除成员不再收到团队活动消息。

用户语言优先于团队语言，最后回退en；支持en和zh-CN。安全通知不受可选活动偏好影响。删除恢复见 [删除手册](saas-data-lifecycle.md)。

## 发布与回退

先运行前向迁移、检查管理员和依赖就绪，再启动任务进程。模块移除迁移应在旧版本工作进程停止后执行，不能让旧 worker 继续处理文件/导出任务。

发布前运行完整RSpec、代码分析、资源构建和OpenAPI一致性检查；结果见 [验收记录](saas-validation.md)。数据库移除变更不能靠回退应用代码恢复已移除的业务记录；有历史数据的环境应先保存备份。开发与生产数据库不在本轮自动迁移清空。
