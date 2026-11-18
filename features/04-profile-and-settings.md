# 用户资料与团队设置


- 优先级：P0。

## 当前行为

- 保留 `GET/PATCH/PUT /api/v1/user`，允许 username、first_name、last_name、email、current_password 及 preferences。邮箱变更校验当前密码，并在新邮箱确认前保留旧邮箱。
- User.preferences 仅允许 locale/timezone；支持语言 en、zh-CN，时区必须被 Rails 识别。未知偏好字段和错误类型被拒绝。
- Team 的 name、timezone、locale 是独立列，不使用不存在的 Team.settings JSON 容器；全局 Setting 不承载团队配置，也不向普通用户暴露平台秘密。
- 有效展示偏好按用户显式值 → 团队默认 → en/UTC 解析，时间持久化仍为 UTC。偏好不能改变权限。
- 资料更新锁定并重新检查用户状态，防止认证后延迟请求覆盖已匿名化的删除账号。

## 接口

| 接口 | 行为 |
| --- | --- |
| `GET/PATCH/PUT .../settings` | 查看白名单团队设置；owner/admin 可更新 |
| `GET/PATCH/PUT /api/v1/notification_preferences` | 可选活动通知的站内/邮件偏好；安全通知不关闭 |


## 验证与实现位置



## 后续扩展

团队 Logo/品牌、自定义域名、任意自定义设置 schema 和付费配置未实现。新增字段必须独立定义默认值、修改角色及敏感性，不能直接开放整个 JSON 对象或全局 Setting。
