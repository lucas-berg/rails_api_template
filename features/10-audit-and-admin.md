# 审计与自建管理后台

移除 ActiveAdmin，使用普通 Rails 控制器、ERB 和独立样式实现 /admin。AdminUser 通过 Devise 登录；平台权限使用 Admin 命名空间 Pundit Policy，与团队角色分开。

support 只读；super_admin 可以维护平台管理员、封禁/恢复用户、暂停/恢复团队、重试失败邮件/通知及删除。所有修改要求原因并与审计同事务，不开放硬删除和批量操作。

首页显示真实用户/团队数量、失败任务和近期审计。列表提供分页、允许字段筛选及明确的详情；不显示密码、令牌摘要、密文和租约，不提供自动CSV/JSON导出。GoodJob/Flipper独立入口也要求super_admin。

使用明确资源控制器和少量共享partial，不新增动态资源注册器或后台框架。实现顺序及完整验收见 [五步计划](../doc/saas-implementation-plan.md)。
