# SaaS 运行与恢复说明

## 配置与启动

复制 `.env.sample`，配置 PostgreSQL、`JWT_SECRET_KEY`、`APP_PUBLIC_URL`、`DEFAULT_EMAIL_SENDER`、SendGrid SMTP 凭据及 `RATE_LIMIT_REDIS_URL`。生产环境必须提供稳定的 `SECRET_KEY_BASE`，邮件临时令牌密文也依赖它；更换密钥前处理待发送邮件，避免旧密文无法解密。

`APP_PUBLIC_URL` 用于验证和邀请链接。独立产品前端可以配置 `INVITATION_ACCEPT_URL`；默认使用本应用最小邀请确认页面。`CORS_ALLOWED_ORIGINS` 为逗号分隔的完整来源，生产环境不默认允许任何跨站来源。

本地 Docker Compose 包含 PostgreSQL 和 Redis；使用 `bin/dev` 在本机运行时也需要相应服务。GoodJob 仍使用 PostgreSQL，Redis 只用于共享限流。

执行数据库迁移后启动应用和 GoodJob 工作进程。生产环境单独运行 `bundle exec good_job start`，开启已配置的 cron 扫描；不要仅启动 Web 进程却遗漏任务进程。

## 账号与权限

新用户需验证邮箱，已有开发用户也不会自动确认。JWT 固定 90 天有效，不滑动续期。密码修改、密码重置、封禁和会话撤销立即失效；用户恢复不会复活旧凭证。

账号会话 API 只显示 API JWT，不将浏览器 Cookie 会话冒充为 API 设备。浏览器认证继续保留 CSRF，并校验凭证版本。

平台支持账号使用 `support`，只能查询允许的资源。`super_admin` 可管理平台管理员、暂停/恢复账号与团队、重试失败邮件；这些操作填写原因并记录审计。GoodJob 和 Flipper 同样仅向 super_admin 开放。开发种子只在 development 创建演示管理员，不在生产初始化默认密码。

## 就绪与限流

- `GET /api/v1/status`：进程存活，保持原响应。
- `GET /api/v1/ready`：检查 PostgreSQL 和 Redis；依赖不可用时返回 503，不返回内部地址或凭据。
- 登录默认每 IP 每分钟 10 次。
- 邮箱确认/重置分别每邮箱每 15 分钟 3 次，邮箱规范化后只以摘要作为计数键。
- 邀请创建/重发默认每团队每小时 30 次，在成员及动作授权之后计数，其他团队的攻击者不能消耗配额。
- 限流返回 429 和 Retry-After。配置通过 `LOGINS_PER_MINUTE`、`RECOVERY_PER_PERIOD`、`INVITATIONS_PER_HOUR` 调整。

多实例共享同一个限流 Redis。测试以独立缓存覆盖限流行为，另有真实 Redis 双客户端共享计数测试；不要将各进程 MemoryStore 作为生产限流方案。

## 邮件故障处理

认证和邀请写入事务时创建 MailDelivery。提交后入队失败不会丢失意图，周期扫描会重新投递。投递记录包含状态、尝试次数、下次时间和错误类别，不显示令牌密文或原始异常正文。

1. 检查公开地址、发件人和 SMTP 凭据，以及 GoodJob 工作进程和队列积压。
2. 在管理后台查询失败记录；等待退避中的 pending 任务会自动重试。
3. 修复渠道后由 super_admin 对 failed 记录填写原因并重试。过期、已接受、已撤销或邀请者已失权的邀请不会继续发送。
4. 发送中的任务有租约，进程中断后扫描器可恢复；只有持有当前租约的任务能落库发送结果。

SMTP 成功后进程若在记录结果前中断，重试可能发送重复邮件；同一链接仍受服务端单次使用与邀请状态约束。不要把邮件次数当作业务操作次数。

## 发布与回归

前三步作为一个版本发布：认证、团队权限、审计和后台必须一起验收。对新部署先运行迁移、检查种子与管理员角色、启动工作进程，再检查 ready 和认证/邀请闭环。

发布前运行完整 RSpec 和 `bundle exec rails code:analysis`，更新模型注释与 OpenAPI。生成 OpenAPI 使用空的临时输出文件，确认差异后再替换 `doc/openapi.yaml`；不要在旧生成文件上追加。

发现错误先停止受影响写入口并保留日志、审计及任务记录。数据库变更以加表和字段为主；已有业务数据时不要直接逆向删除表来恢复旧应用。保留数据库快照，选择修复向前发布或经过验证的应用回退。

任务排查关联 request_id、job_id 和 team_id，日志不得记录密码、完整 JWT、确认链接或解密后的邮件内容。数据库恢复与最终删除台账的操作随数据生命周期模块补充。
