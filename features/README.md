# SaaS 基础功能设计目录

本目录记录当前 Rails API 模板的功能边界、实现位置、验证范围和后续设计。当前五步范围使用 **Team / Member / team_id**，JWT 固定有效 **90 天**，采用普通 Ruby 权限策略，**不使用 Pundit**。用户验证邮箱后主动创建团队或接受邀请，不自动创建个人团队。

截至 2026-11-18，五步内的核心代码及针对性自动测试已落地；这不代表全部历史设计、生产部署、真实邮件投递或备份演练已经完成。以下“已实现”仅指仓库内能力，生产运行准备见运行手册。

## 入口文档

- [五步实施计划](../doc/saas-implementation-plan.md)：当前交付范围、操作顺序和验收条件。
- [运行手册](../doc/saas-operations.md)：环境、迁移、邮件、任务、限流和上线排查。
- [数据生命周期手册](../doc/saas-data-lifecycle.md)：导出、删除、保留周期及备份恢复后重放删除台账。
- [OpenAPI](../doc/openapi.yaml)：接口合同；实际注册入口以 [路由](../config/routes.rb) 为准。
- [统一架构约定](00-architecture.md)：数据归属、授权、事务与兼容边界。

## 当前实现与扩展

| 模块 | 当前状态 | 尚未包含 |
| --- | --- | --- |
| [01 账号与认证](01-authentication.md) | 邮箱确认、90 天 JWT、会话撤销、凭证版本、浏览器兼容 | MFA、SSO、完整社交登录 |
| [02 团队与多租户](02-tenancy.md) | Team/Member、主动建队、有效成员隔离、暂停和删除状态 | 数据库行级安全、独立租户数据库 |
| [03 成员、邀请与权限](03-members-and-permissions.md) | 固定四角色、邀请闭环、所有权转移、普通 Ruby Policy | 自定义角色、席位配额 |
| [04 用户资料与团队设置](04-profile-and-settings.md) | 资料、语言/时区、团队设置、受保护头像 | 团队品牌、自定义域名 |
| [05 套餐、订阅与支付](05-plans-and-billing.md) | 扩展设计，未实现 | 整个商业计费模块 |
| [06 功能权益、用量与配额](06-entitlements-and-quotas.md) | 扩展设计，未实现 | 商业权益、计量和配额 |
| [07 邮件、站内通知与偏好](07-notifications.md) | 事务邮件 outbox、通知白名单、站内/邮件投递和偏好 | 营销公告、渠道回执/退信自动处理 |
| [08 附件上传与文件管理](08-files-and-storage.md) | 私有文件、类型校验、授权下载/图片预览、可恢复清理 | 防病毒引擎、浏览器直传、存储商业配额 |
| [09 开放 API、密钥与 Webhook](09-api-and-webhooks.md) | API Key 与对外 Webhook 为未实现扩展；现有业务 JSON API 已提供 | 服务身份、公开集成、签名回调 |
| [10 审计日志与运营后台](10-audit-and-admin.md) | 同事务审计、只读查询、平台角色、受控恢复/重试 | 无感冒充、不可篡改外部归档 |
| [11 首次使用、工作台与通用体验](11-onboarding-and-experience.md) | 入门/工作台 API，保留认证页面和邀请接受页 | 完整用户控制台、业务入门流程 |
| [12 数据导出、删除与保留](12-data-lifecycle.md) | 私有 JSON 导出、冷静期删除、恢复检查点和独立删除台账 | 通用导入、附件内容打包、自动备份 |
| [13 功能开关与发布配置](13-feature-flags-and-configuration.md) | 既有 Flipper、Team actor、仅超级管理员入口 | 开关元数据登记、完整变更审计和到期清理 |
| [14 安全、异步任务与运行保障](14-security-and-reliability.md) | 共享限流、健康检查、任务恢复、上下文和日志基础 | 生产告警验证、容量/SLO 验收、真实灾备演练 |
| [15 企业能力与按需扩展](15-enterprise-and-extensions.md) | 扩展设计，未实现 | SSO、MFA、成员同步等 |

05、06、09、15 以及各模块列出的扩展均不作为当前五步功能的前置依赖。文件大小上限、限流、任务重试预算属于运行保护，不是商业配额。

## 五步实施与源码对应

1. **账号认证与事务邮件**：User、AuthSession、MailDelivery；01、07、14。
2. **团队与成员协作**：Team、Member、Invitation、AuditEvent、手写策略和偏好；02—04。
3. **运营与运行保障**：ActiveAdmin、平台角色、审计查询、共享限流及手册；10、14。
4. **通知与文件**：Notification、NotificationDelivery、NotificationPreference、Document；07、08、11。
5. **导出与删除**：DataExport、DeletionRequest、DeletionTombstone、清理任务及恢复台账；12。

实际模型和约束见 [app/models](../app/models)、[迁移](../db/migrate) 与 [schema](../db/schema.rb)，行为测试见 [spec](../spec)。兼容的认证和资料接口保留原响应外壳；新增 SaaS API 使用统一 data/meta/errors 结构。

## 继续实施的规则

- 先确认功能是否属于当前范围；扩展使用 [模块模板](TEMPLATE.md) 补充需求与验收条件。
- 新增团队资源必须接入有效成员 scope、动作权限、审计、失败恢复和跨团队测试。
- 文档中的未来模型、接口及复选框是设计，不代表已有代码。不得因五步完成而批量勾选历史扩展。
- 上线前分别完成目标环境的邮件、存储、共享限流、任务、告警和备份恢复核验，并记录实际证据。
