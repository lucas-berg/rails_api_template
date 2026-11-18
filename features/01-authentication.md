# 账号与认证

当前范围（2026-11-18）：文件、头像和业务导出已移除；使用自建 /admin、Pundit 授权及 Ransack 搜索。实现边界见 [五步计划](../doc/saas-implementation-plan.md)，测试与构建结果见 [验收记录](../doc/saas-validation.md)。

- 优先级：P0。
- 当前状态：五步范围已实现；本地请求/模型测试覆盖主要安全路径，生产渠道配置另行核验。
- 依赖：无团队前置；主动建队/接受邀请见 02、03，事务邮件见 07。

## 当前行为

- Devise confirmable/reconfirmable：注册邮箱必须确认后登录；确认链接 24 小时，重置密码链接 6 小时。存量未确认账号不被自动标为已确认。
- JWT 从签发时起固定有效 **90 天**，访问不续期。AuthSession 保存 jti 摘要、凭证版本、到期/撤销/使用时间及受限 user_agent/IP，不保存原始 JWT。
- 只为实际签发 JWT 的 JSON 登录登记 AuthSession；浏览器 Cookie 登录不创建 API 会话。JSON API 不接受 Cookie 替代 Bearer。
- API 会话校验用户状态、credentials_version 和会话有效性。退出/远程撤销只影响对应会话；改密、重置和封禁撤销全部旧凭证。
- Cookie 同样校验凭证版本，恢复账号不会复活旧 Cookie。已删除账号不能被平台恢复为可登录状态。
- 邮箱修改需要当前密码；新邮箱确认前保留旧邮箱，确认后同步身份字段。确认和重置请求使用防枚举响应。
- 账号删除冷静期仍可登录以便取消，执行删除时撤销全部凭证；最后 owner 保护见 12。

## 接口与实现

| 接口 | 行为 |
| --- | --- |
| `/users`、`/users/sign_in`、`/users/sign_out` | 保留注册、登录、退出；HTML 与 JSON 路径分别处理 |
| `/users/confirmation`、`/users/password` | 确认/重发、找回/重置密码 |
| `GET /api/v1/auth_sessions` | 仅本人有效 API 会话，分页和字段白名单 |
| `DELETE /api/v1/auth_sessions/:id` | 撤销本人会话；不接受他人的会话 ID |
| `GET/PATCH/PUT /api/v1/user` | 保留个人资料接口，邮箱变更遵循重确认 |

实现集中在 [User](../app/models/user.rb)、[UserAuthentication](../app/models/concerns/user_authentication.rb)、[AuthSession](../app/models/auth_session.rb)、[认证控制器](../app/controllers/users) 和 [Devise 配置](../config/initializers/devise.rb)。

## 验证范围

[认证安全请求测试](../spec/requests/api/authentication_security_spec.rb)、[会话测试](../spec/requests/api/v1/auth_sessions_spec.rb)、[认证页面测试](../spec/requests/users/authentication_pages_spec.rb) 覆盖未确认/过期/撤销/封禁、两客户端、改密、邮箱重确认、90 天边界、浏览器兼容和敏感字段。并发注册会话使用用户锁，防止签发过程中凭证已变更仍登记旧会话。

## 后续扩展与上线核验

MFA、SSO、社交登录供应商联调和异常登录风险检测未实现。生产需配置邮件域名、公开链接地址、密钥和 HTTPS，并完成真实注册/找回邮件验证；步骤见 [运行手册](../doc/saas-operations.md)。
