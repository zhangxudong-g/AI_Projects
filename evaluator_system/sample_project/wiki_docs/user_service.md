# UserService

用户服务类，提供用户认证和资料更新功能。

## authenticate_user

* 调用auth_service.validate验证用户名密码
* 当验证失败时抛出AuthenticationError异常
* 调用db_service.log_login记录登录日志

## update_user_profile

* 调用auth_service.check_permission检查用户权限
* 当权限不足时抛出PermissionError异常
* 调用db_service.update_user更新数据库中的用户资料