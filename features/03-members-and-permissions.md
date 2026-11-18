# 成员、邀请与Pundit权限

使用标准Pundit Policy/Scope，Devise/JWT继续负责登录。User为全局身份，Member对team_id/user_id唯一；角色只属于团队关系。

| 操作 | owner | admin | member/viewer |
| --- | --- | --- | --- |
| 查看团队与目录 | 允许 | 允许 | 允许 |
| 修改团队设置 | 允许 | 允许 | 拒绝 |
| 邀请/管理member或viewer | 允许 | 允许 | 拒绝 |
| 管理admin与所有权 | 允许 | 拒绝 | 拒绝 |

查询从已授权团队关系加载对象；写服务在Team锁内刷新操作者并执行Pundit，不因控制器已检查而省略服务边界。保留至少一位owner，自我提权和跨团队ID均拒绝。

邀请有效七天，重发轮换令牌，接受要求当前验证邮箱匹配且邀请人仍有权限。接受前不要求已有Member。转移所有权只允许有效成员，原owner降为admin；暂停或历史已删除账号不能接受新邀请或接任所有权。

平台AdminUser使用Admin命名空间Policy，support只读、super_admin执行带原因及审计的写操作。不存在商业席位配额。

验收覆盖四角色、未知资源/动作拒绝、跨团队、邀请重放/失效、直接服务调用和真实多连接并发。
