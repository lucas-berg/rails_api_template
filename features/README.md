# SaaS 功能范围

本轮修订按用户要求先更新文档，再执行代码。详细顺序见 [五步实施计划](../doc/saas-implementation-plan.md)，验证状态见 [验收记录](../doc/saas-validation.md)。

## 保留与调整

- 账号认证：Devise/JWT、固定90天、邮箱验证、会话撤销和设备信息。
- 团队：Team/Member、owner/admin/member/viewer、邀请、所有权转移、设置。
- 权限：Pundit标准Policy/Scope，移除旧授权分派器；平台使用Admin命名空间策略。
- 后台：自建 /admin dashboard、AdminUser登录、support只读、super_admin受控写入和审计。
- 内部能力：事务邮件、通知及偏好、团队摘要与首次使用API。
- 数据退出：账号与团队删除、冷静期、重试、匿名化与独立删除台账。

## 删除或暂不实现

Document、上传、文件下载/预览、头像及业务导出整体移除，不再作为其他模块依赖。ActiveAdmin和它独占的前端依赖删除。

支付、商业权益/配额、API Key、对外Webhook、SSO和通用导入仍是未来扩展；相应设计文件不代表实现承诺。独立删除台账恢复工具保留，不属于业务导出功能。

## 文档入口

- [架构](00-architecture.md)、[认证](01-authentication.md)、[团队](02-tenancy.md)、[权限](03-members-and-permissions.md)
- [资料与设置](04-profile-and-settings.md)、[通知](07-notifications.md)、[后台](10-audit-and-admin.md)、[摘要](11-onboarding-and-experience.md)
- [删除](12-data-lifecycle.md)、[运行保障](14-security-and-reliability.md)
- [运行手册](../doc/saas-operations.md)、[删除恢复手册](../doc/saas-data-lifecycle.md)、[OpenAPI](../doc/openapi.yaml)

本轮完成后用实际回归结果更新验收记录，不沿用修订前的测试数量或后台验证结论。
