# 附件上传与文件管理

- 优先级：P1；涉及文件的产品为 P0。
- 当前状态：私有 Active Storage 文件、受控上传、内容类型验证、授权下载/图片预览、头像和可恢复清理已实现。
- 依赖：02、03、10、14；无商业存储配额前置。

## 数据与授权

`Document(team_id, uploader_id, status, original_filename, byte_size, verified_content_type, ...)` 是业务授权载体，关联私有 Active Storage file。状态为 uploading/processing/ready/rejected/deleting/deleted/purge_failed。

- 有效团队成员可读；viewer 不可上传/修改。member 可上传、完成自己的上传并删除自己的文件；owner/admin 可删除团队文件。
- 上传为服务端接收 multipart，不接受任意 blob signed_id，不提供浏览器直传。默认 Active Storage blob 路由禁用，不能绕过业务授权。
- 仅接受 PNG、JPEG、PDF，默认最大 10 MiB（MAX_UPLOAD_BYTES 可配置，代码上限 100 MiB）。这是运行保护，不是商业用量或配额。
- 完成上传后异步检查实际大小与内容类型，未 ready 的文件不能下载。当前没有防病毒引擎，类型验证不能称为病毒扫描。
- 下载每次检查成员与资源权限，使用私有、不缓存的业务响应。仅验证通过的图片支持 inline 预览，PDF 以附件下载；提供 nosniff 和受限内容安全策略。

## 实际接口

| 接口 | 行为 |
| --- | --- |
| `POST .../uploads` | multipart file，返回 Document，201 |
| `POST .../uploads/:id/complete` | 申请内容验证，通常 202；已 ready 则返回当前状态 |
| `GET .../files`、`GET .../files/:id` | 分页文件目录和状态 |
| `GET .../files/:id/download` | 授权后读取私有文件 |
| `GET .../files/:id/preview` | 仅 ready 图片可预览 |
| `DELETE .../files/:id` | 标记删除并异步清理，204 |
| `GET/PATCH/PUT/DELETE .../avatar` | 管理本人头像引用，只能绑定本人在该团队上传的 ready 图片 |

`...` 为 `/api/v1/teams/:team_id`。返回字段是业务元数据，不暴露 blob key 或可匿名使用的下载链接。

## 清理与失败恢复

- 上传 1 小时未完成会回收；超过 10 分钟的验证/清理任务可被扫描恢复。
- 删除首先撤销可访问状态和头像引用，再删除远端实际字节，成功后才移除 blob 元数据；存储失败保留 key 以便重试。
- 清理达到重试预算后进入 purge_failed，超级管理员提供原因后可重新启动。团队/账号删除必须确认文件实际清理成功，不能只认为 Job 已返回就完成。
- 账号/团队生命周期最终会清理 Document 元数据；常规文件删除可保留删除状态用于查询和审计。

## 验证与扩展

[文件请求测试](../spec/requests/api/v1/files_spec.rb)、[文件策略](../spec/policies/document_policy_spec.rb)、[验证任务](../spec/jobs/verify_document_job_spec.rb) 和 [清理任务](../spec/jobs/purge_document_job_spec.rb) 覆盖跨团队、signed_id、默认 blob 地址、伪造类型、非 ready 下载、存储失败和重复清理；并发清理有独立连接测试。

防病毒供应商、图片变换、分片/直传、公共资源分发和存储商业配额是后续扩展。生产存储服务和访问控制需按 [运行手册](../doc/saas-operations.md) 独立验证。
