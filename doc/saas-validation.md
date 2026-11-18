# SaaS 修订验收记录

日期：2026-11-18。本轮已完成文件、头像与业务导出移除，采用 Pundit 授权，自建 `/admin` 并保留 Ransack 搜索。实现提交为 `43a047f`；实施计划和 Ransack 补充要求均先于代码提交。

## 当前行为

- Devise/JWT 负责登录，固定有效期为90天；Pundit 负责 API、服务和平台后台授权，保留 Team/Member 及其角色。
- 自建后台提供真实统计、12类资源列表与详情、分页、搜索、带原因和审计的管理操作。support 只读，super_admin 执行允许的修改；浏览器保留 CSRF。
- Ransack 6.1 保留在依赖中。所有后台搜索先应用 Pundit Scope，再使用明确的模型字段白名单；禁止敏感字段、任意关联与额外 scope。审计动作使用嵌套的 `q[...]` 参数，避免 Rails 路由参数冲突。
- Document、DataExport、上传、下载、预览、头像、业务导出接口及专属任务和配置已移除，旧入口返回404。
- 删除旧 Authorization 分派器、平台授权适配器、TeamMemberships/Ransackable concern 和通用重试分派；保留实际需要的事务、锁、审计和任务恢复机制。

## 验证结果

下列专项属于全量测试的一部分，不累加为另一组总数。

| 验证 | 实际结果 |
| --- | --- |
| `HEADLESS=true bundle exec rspec` | **368项，0失败**，包括真实数据库并发用例 |
| 后台请求 | 38项通过：登录/恢复、搜索/分页、权限、敏感字段、CSRF、原因和审计回滚 |
| 真实 Chrome | 3项通过；完成登录 → Ransack 搜索账号 → 暂停账号 → 查看审计详情，已检查后台截图 |
| Ransack 模型边界 | 38项通过，覆盖允许条件、密码/令牌/密文拒绝、关联和 scope 禁止、查询范围保留 |
| 退役入口 | 17项通过，确认文件/头像/导出、旧后台资源和默认上传入口返回404 |
| 移除迁移 | 3项通过，隔离 PostgreSQL schema 验证历史数据、外键、运行中旧任务拒绝及不可逆回滚提示 |
| `RAILS_ENV=test bundle exec rails code:analysis` | Brakeman 0安全警告；RuboCop 285文件无问题；Reek、Rails Best Practices 0警告 |
| 自动加载与模型注释 | Zeitwerk 通过；AnnotateRb 无变更 |
| OpenAPI | 135项 API 测试通过，从新文件生成后与提交文档无差异；**32条路径、51个操作**，无文件/头像/导出路径 |
| 前端 | Yarn immutable 安装、JS构建、Rails资源预编译均通过 |
| 生产 Docker | 最终镜像构建通过；独立 Web/PostgreSQL16/Redis7 均健康，`/status`、`/ready`、`/admin/login` 与实际后台样式均200，旧模块路径404 |

最终生产镜像为 `rails-api-template:saas-refactor-verify`，镜像ID为 `sha256:2202505fb56c4aaea33dc0226ea32eaaedcf173447a8e156d46bdbb8c5b95595`。隔离数据库已达到迁移 `20261118170000`：两个废弃业务表和头像列不存在，通用 Active Storage 三张表保留。验证项目的容器、网络和卷已清理。

## 数据与发布边界

迁移只在本机测试数据库、独立迁移测试 schema 和隔离 Docker 数据库验证，**未执行开发或生产数据库的删除迁移**。历史迁移保留，前向移除迁移不可逆；发布前应保存备份并停止旧版本 Web/任务进程。

迁移清理废弃业务记录、附件关联和旧任务，不删除磁盘/对象存储中的文件内容；公共存储路由仍关闭。账号与团队删除保留冷静期、独立台账和恢复重放，`data:deletions:export` 仍是台账恢复工具。

真实 SMTP 投递、生产告警、生产备份恢复及 RPO/RTO 不属于本地验证结论。部署说明见 [运行手册](saas-operations.md) 和 [删除恢复手册](saas-data-lifecycle.md)。
