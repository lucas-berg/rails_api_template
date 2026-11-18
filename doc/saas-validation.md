# SaaS 五步实施验收记录

日期：2026-11-18。范围以 [五步实施计划](saas-implementation-plan.md) 为准；运行方式见 [运行手册](saas-operations.md) 和 [数据生命周期手册](saas-data-lifecycle.md)。

## 实施结果

| 步骤 | 已交付内容 | 主要验证 |
| --- | --- | --- |
| 1. 账号认证与事务邮件 | 固定 90 天 JWT、邮箱确认与重确认、会话设备信息及撤销、凭证版本、邮件 outbox | 两客户端隔离；90 天边界和不续期；密码/封禁撤销；浏览器 Cookie 与 JSON Bearer 分离；邮件回滚、重试和补投 |
| 2. 团队与成员协作 | Team/Member、四种角色、七天邀请、所有权转移、偏好、同事务审计 | 跨团队 ID、自我提权、admin 管理 owner/admin 拒绝；过期/撤销/重发邀请；独立数据库连接的并发邀请和所有权操作 |
| 3. 后台与运行保障 | super_admin/support、受控恢复/重试、共享 Redis 限流、CORS、就绪检查、请求/任务日志关联 | 直接后台请求与导出拒绝；管理员修改审计回滚；真实 Redis 双客户端计数；任务上下文清理；未知策略默认拒绝 |
| 4. 通知与私有文件 | 安全与活动通知、偏好、en/zh-CN 回退、PNG/JPEG/PDF 校验、私有下载、头像、摘要与首次使用 API | 消息隔离及失权、重试、语言回退；真实文件格式、伪造类型、私有路由、上传中断、重复删除和存储故障 |
| 5. 导出与删除 | JSON 元数据导出、24 小时过期、七天删除冷静期、检查点清理、独立删除台账与恢复重放 | 导出中失权、存储上传失败；最后 owner 保护；冷静期取消；文件/头像/导出清理；台账失败与重放顺序；365 天审计及 30 天加密收件地址保留 |

不使用 Pundit。没有新增商业计费、套餐权益、商业配额、API Key、对外 Webhook、企业 SSO 或通用业务导入。导出包括文件元数据，不打包文件内容；文件检查不是防病毒扫描。

## 最终自动检查

- 完整 RSpec：**337 个用例，0 失败**，包含真实浏览器登录及多连接并发测试，随机种子 `20141`。
- API 契约生成：**149 个用例，0 失败**；其中一例删除隔离测试不纳入公开接口文档。
- OpenAPI：**42 个路径、66 个操作**，与当前 JSON 路由逐项核对；全部操作有成功响应，没有默认 Active Storage 公开路径或原始 JWT 示例。
- 从空临时文件重新生成 OpenAPI 后，与 `doc/openapi.yaml` 比较无差异。文件上传使用 multipart binary，下载使用 binary，删除确认接口包含必需的当前密码。
- `rails code:analysis` 全部通过：Brakeman 0 安全警告，RuboCop 检查 302 个文件无违规，Reek 0 警告，Rails Best Practices 0 警告。
- 测试数据库迁移成功；独立临时数据库创建、结构准备和清理成功。重新导出 schema 及运行 AnnotateRb 无文件漂移。
- Yarn 不可变安装、前端构建及 Rails 资源预编译成功。
- 两份 Dockerfile 的 Hadolint 检查通过；当前业务代码的生产镜像构建成功，本地标签为 `rails-api-template:saas-validation`。
- 开发 Docker Compose 在独立项目、独立数据库/Redis 卷与随机本地端口上构建并通过健康检查；`/api/v1/status` 与 `/api/v1/ready` 均返回 200。验证结束后清理了本次临时容器和卷，未占用已有数据库及 Redis 端口。

复现核心检查：

```bash
RAILS_ENV=test bundle exec rails db:prepare
HEADLESS=true bundle exec rspec
RAILS_ENV=test bundle exec rails code:analysis
RAILS_ENV=test bundle exec annotaterb models

# 使用尚不存在的临时文件，避免旧契约内容被合并保留。
OPENAPI=1 OPENAPI_OUTPUT=tmp/openapi-review.yaml bundle exec rspec spec/requests/api --order defined
diff -u doc/openapi.yaml tmp/openapi-review.yaml

corepack yarn install --immutable
corepack yarn build
corepack yarn exec env RAILS_ENV=test bundle exec rails assets:precompile
docker build -t rails-api-template:saas-validation .
```

运行前应按 `.env.sample` 准备本地 PostgreSQL、Redis 和测试配置。随机测试会随新增用例改变数量；本文记录本次交付时的结果。

## 集成回归关注点

- 管理后台的 CSV/JSON 导出被实际禁用，隐藏链接不是唯一控制。
- 认证限流覆盖真实后台登录路径、HTML、JSON 与尾随斜杠变体。
- 已进入不可逆删除阶段的账号不能通过普通后台恢复；团队即使清理失败也无法再读取团队文件。
- 旧资料更新与 Devise 登录记录写入在用户行锁内刷新状态，避免匿名化完成后写回邮箱或 IP。
- 文件清理和数据导出保留必要存储引用，工作进程中断或存储异常后可以安全恢复。
- 删除台账在不可逆决定提交后、实际清理前写入；恢复时先重放 Team，再重放 User，避免恢复到旧所有权关系时错误阻塞。

## 提交边界与运行边界

变更按文档、认证/团队协作、后台、通知、文件、运行上下文、导出、删除、会话资料、索引与注释、权限修复、接口契约及最终说明拆分提交。提交记录保留在当前 `saas-template` 分支，未推送远端。

本次验证使用本地数据库、Redis、测试邮件通道和临时文件存储。没有向真实用户发邮件，也没有执行生产发布。生产启用前需按运行手册配置真实 SMTP、共享私有存储、GoodJob 工作进程、稳定密钥和独立备份的删除台账目录；真实灾备恢复与外部渠道验收由目标环境执行。
