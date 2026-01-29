from datetime import datetime, timedelta
from typing import Optional
import jwt
import bcrypt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
import os

# JWT配置
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-change-this-in-production")  # 应该从环境变量中获取
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# 使 SECRET_KEY 可以被其他模块导入
__all__ = ["authenticate_user", "create_access_token", "get_current_active_user", "User", "Token", "get_user", "has_permission", "Permission", "require_permission", "SECRET_KEY", "ALGORITHM"]

# 模拟用户数据库 - 在实际应用中应使用真正的数据库
users_db = {
    "admin": {
        "username": "admin",
        "hashed_password": bcrypt.hashpw("admin123".encode('utf-8'), bcrypt.gensalt()),
        "disabled": False,
        "role": "admin"
    }
}

security = HTTPBearer()

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None

class User(BaseModel):
    username: str
    disabled: Optional[bool] = None
    role: Optional[str] = None

class UserInDB(User):
    hashed_password: bytes

def verify_password(plain_password: str, hashed_password: bytes) -> bool:
    """验证密码"""
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password)

def get_user(username: str) -> Optional[UserInDB]:
    """从数据库获取用户"""
    if username in users_db:
        user_dict = users_db[username]
        return UserInDB(**user_dict)
    return None

def authenticate_user(username: str, password: str) -> Optional[User]:
    """验证用户凭据"""
    user = get_user(username)
    if not user:
        return None
    if not verify_password(password, user.hashed_password):
        return None
    return user

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """创建访问令牌"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire.timestamp()})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """获取当前用户"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
        token_data = TokenData(username=username)
    except jwt.PyJWTError:
        raise credentials_exception
    user = get_user(username=token_data.username)
    if user is None:
        raise credentials_exception
    if user.disabled:
        raise credentials_exception
    return user

async def get_current_active_user(current_user: User = Depends(get_current_user)):
    """获取当前活跃用户"""
    if current_user.disabled:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user

def get_user_role(user: User) -> str:
    """获取用户角色"""
    return getattr(user, 'role', 'user')


# 权限系统
class Permission:
    """权限枚举"""
    VIEW_SERVERS = "view:servers"
    EDIT_SERVERS = "edit:servers"
    VIEW_ALERTS = "view:alerts"
    EDIT_ALERTS = "edit:alerts"
    VIEW_HISTORY = "view:history"
    MANAGE_USERS = "manage:users"
    VIEW_PLUGINS = "view:plugins"
    MANAGE_PLUGINS = "manage:plugins"


# 角色权限映射
ROLE_PERMISSIONS = {
    "admin": [
        Permission.VIEW_SERVERS,
        Permission.EDIT_SERVERS,
        Permission.VIEW_ALERTS,
        Permission.EDIT_ALERTS,
        Permission.VIEW_HISTORY,
        Permission.MANAGE_USERS,
        Permission.VIEW_PLUGINS,
        Permission.MANAGE_PLUGINS
    ],
    "operator": [
        Permission.VIEW_SERVERS,
        Permission.VIEW_ALERTS,
        Permission.VIEW_HISTORY,
        Permission.VIEW_PLUGINS
    ],
    "viewer": [
        Permission.VIEW_SERVERS,
        Permission.VIEW_PLUGINS
    ]
}


def has_permission(user: User, permission: str) -> bool:
    """检查用户是否具有特定权限"""
    user_role = getattr(user, 'role', 'viewer')
    permissions = ROLE_PERMISSIONS.get(user_role, [])
    return permission in permissions


def require_permission(permission: str):
    """装饰器：要求特定权限"""
    def permission_decorator(func):
        async def wrapper(current_user: User = Depends(get_current_active_user), *args, **kwargs):
            if not has_permission(current_user, permission):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Insufficient permissions"
                )
            return await func(current_user=current_user, *args, **kwargs)
        return wrapper
    return permission_decorator


# 更新用户数据库以支持更多角色
users_db = {
    "admin": {
        "username": "admin",
        "hashed_password": bcrypt.hashpw("admin123".encode('utf-8'), bcrypt.gensalt()),
        "disabled": False,
        "role": "admin"
    },
    "operator": {
        "username": "operator",
        "hashed_password": bcrypt.hashpw("op123".encode('utf-8'), bcrypt.gensalt()),
        "disabled": False,
        "role": "operator"
    },
    "viewer": {
        "username": "viewer",
        "hashed_password": bcrypt.hashpw("view123".encode('utf-8'), bcrypt.gensalt()),
        "disabled": False,
        "role": "viewer"
    }
}