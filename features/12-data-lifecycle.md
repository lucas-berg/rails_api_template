# 删除生命周期（已移出范围）

整体移除 DeletionRequest、DeletionTombstone、冷静期、申请与取消、删除任务、重试、完成通知和台账恢复工具。当前模板不提供账号或团队删除接口，`DELETE /users` 也关闭。

保留历史已删除账号和团队的访问限制，保留普通暂停/恢复与审计功能。迁移边界见 [删除模块移除说明](../doc/saas-data-lifecycle.md)，执行顺序见 [五步计划](../doc/saas-implementation-plan.md)。
