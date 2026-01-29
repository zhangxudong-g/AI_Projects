"""
用户服务类 - 示例源码
包含用户认证和信息更新功能
"""

class UserService:
    """用户服务类"""
    
    def __init__(self, auth_service, db_service):
        self.auth_service = auth_service
        self.db_service = db_service

    def authenticate_user(self, username, password):
        """
        认证用户
        
        Args:
            username: 用户名
            password: 密码
            
        Returns:
            认证结果
        """
        # 检查用户名密码
        if not self.auth_service.validate(username, password):
            raise AuthenticationError("认证失败")
        
        # 记录登录日志
        self.db_service.log_login(username)
        
        return True

    def update_user_profile(self, user_id, profile_data):
        """
        更新用户资料
        
        Args:
            user_id: 用户ID
            profile_data: 资料数据
            
        Returns:
            更新结果
        """
        # 检查权限
        if not self.auth_service.check_permission(user_id):
            raise PermissionError("权限不足")
        
        # 更新数据库中的用户资料
        result = self.db_service.update_user(user_id, profile_data)
        
        return result