#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Git Auto Commit and Push Agent
这是一个增强版的Git自动提交和推送代理
它会在检测到工作完成信号时自动执行git commit和git push操作
"""

import os
import subprocess
import sys
from typing import Tuple


def run_git_command(command: str) -> Tuple[bool, str]:
    """
    执行Git命令并返回结果

    Args:
        command: 要执行的Git命令

    Returns:
        tuple: (是否成功, 输出信息)
    """
    try:
        result = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            encoding='utf-8',
            cwd=os.getcwd()
        )

        if result.returncode == 0:
            # 处理可能的None值
            stdout = result.stdout if result.stdout is not None else ""
            return True, stdout.strip()
        else:
            # 处理可能的None值
            stderr = result.stderr if result.stderr is not None else ""
            return False, stderr.strip()
    except Exception as e:
        return False, str(e)


def has_changes_to_commit() -> bool:
    """
    检查是否有待提交的更改
    
    Returns:
        bool: 是否有待提交的更改
    """
    success, output = run_git_command("git status --porcelain")
    if success:
        return len(output.strip()) > 0
    return False


def get_current_branch() -> str:
    """
    获取当前Git分支名称
    
    Returns:
        str: 当前分支名称
    """
    success, output = run_git_command("git branch --show-current")
    if success:
        return output.strip()
    return "main"


def auto_commit_and_push(commit_message: str = "Auto-commit on work completion") -> bool:
    """
    自动执行Git提交和推送操作

    Args:
        commit_message: 提交消息

    Returns:
        bool: 操作是否成功
    """
    print(f"开始执行自动提交和推送...")

    # 检查是否在Git仓库中
    success, _ = run_git_command("git rev-parse --git-dir")
    if not success:
        print("错误：当前目录不是一个Git仓库")
        return False

    # 拉取最新更改以避免冲突
    print("正在拉取最新更改...")
    current_branch = get_current_branch()
    pull_success, pull_output = run_git_command(f"git pull origin {current_branch} --no-rebase")
    if not pull_success:
        print(f"拉取最新更改时出现问题: {pull_output}")
        # 即使拉取有问题也继续，因为可能是因为本地分支比远程新

    # 检查是否有更改需要提交
    if not has_changes_to_commit():
        print("没有检测到更改，无需提交")
        return True

    # 添加所有更改
    print("正在添加所有更改...")
    success, output = run_git_command("git add .")
    if not success:
        print(f"添加更改失败: {output}")
        return False

    # 执行提交
    print(f"正在执行提交: {commit_message}")
    success, output = run_git_command(f'git commit -m "{commit_message}"')
    if not success:
        print(f"提交失败: {output}")
        return False

    # 获取当前分支
    current_branch = get_current_branch()
    print(f"当前分支: {current_branch}")

    # 推送到远程仓库
    print(f"正在推送更改到远程仓库...")
    success, output = run_git_command(f"git push origin {current_branch}")
    if not success:
        print(f"推送失败: {output}")
        # 尝试使用--set-upstream选项（如果远程分支不存在）
        print("尝试设置上游分支并推送...")
        set_upstream_success, set_upstream_output = run_git_command(
            f"git push --set-upstream origin {current_branch}"
        )
        if not set_upstream_success:
            print(f"设置上游分支并推送也失败了: {set_upstream_output}")
            return False

    print("自动提交和推送操作成功完成！")
    return True


def main():
    """主函数"""
    if len(sys.argv) > 1:
        commit_message = " ".join(sys.argv[1:])
    else:
        commit_message = "Auto-commit: Changes pushed to remote"
    
    success = auto_commit_and_push(commit_message)
    if success:
        print("操作完成")
    else:
        print("操作失败")
        sys.exit(1)


if __name__ == "__main__":
    main()