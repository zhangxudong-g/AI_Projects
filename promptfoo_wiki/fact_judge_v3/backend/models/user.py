from sqlalchemy import Column, Integer, String, Text, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database.base import Base
import uuid

def generate_uuid():
    return str(uuid.uuid4())

class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=generate_uuid)
    username = Column(String(50), unique=True, nullable=False)
    email = Column(String(100), unique=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    role = Column(String(20), default='user')  # admin, user, viewer
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now(), server_default=func.now())

    # 关系
    cases_created = relationship("Case", back_populates="creator")
    executions = relationship("Execution", back_populates="user")


class Case(Base):
    __tablename__ = "cases"

    id = Column(String, primary_key=True, default=generate_uuid)
    name = Column(String(255), nullable=False)
    description = Column(Text)
    config_yaml = Column(Text, nullable=False)  # 存储YAML配置
    created_by = Column(String, ForeignKey("users.id"))  # 外键引用users.id
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now(), server_default=func.now())
    status = Column(String(20), default='active')  # active, inactive

    # 关系
    creator = relationship("User", back_populates="cases_created")
    executions = relationship("Execution", back_populates="case")
    reports = relationship("Report", back_populates="case")


class Execution(Base):
    __tablename__ = "executions"

    id = Column(String, primary_key=True, default=generate_uuid)
    case_id = Column(String, ForeignKey("cases.id"))
    user_id = Column(String, ForeignKey("users.id"))
    status = Column(String(20), default='queued')  # queued, running, completed, failed, stopped
    progress = Column(Integer, default=0)  # 执行进度百分比
    start_time = Column(DateTime(timezone=True))
    end_time = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # 关系
    case = relationship("Case", back_populates="executions")
    user = relationship("User", back_populates="executions")
    report = relationship("Report", back_populates="execution", uselist=False)


class Report(Base):
    __tablename__ = "reports"

    id = Column(String, primary_key=True, default=generate_uuid)
    execution_id = Column(String, ForeignKey("executions.id"), unique=True)
    case_id = Column(String, ForeignKey("cases.id"))
    final_score = Column(Integer)
    result = Column(String(20))  # PASS, FAIL
    details = Column(Text)  # JSON字符串存储详细的评估结果
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # 关系
    execution = relationship("Execution", back_populates="report")
    case = relationship("Case", back_populates="reports")


class SystemConfig(Base):
    __tablename__ = "system_configs"

    id = Column(String, primary_key=True, default=generate_uuid)
    config_key = Column(String(100), unique=True, nullable=False)
    config_value = Column(Text)
    description = Column(Text)
    updated_by = Column(String, ForeignKey("users.id"))  # 外键引用users.id
    updated_at = Column(DateTime(timezone=True), onupdate=func.now(), server_default=func.now())

    # 关系
    user = relationship("User")