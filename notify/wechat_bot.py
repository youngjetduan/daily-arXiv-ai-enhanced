#!/usr/bin/env python3
"""
企业微信机器人推送模块
用于在arXiv论文更新后自动发送消息到企业微信群
"""

import argparse
import json
import os
import requests
from datetime import datetime
from typing import Dict


class WeChatBot:
    """企业微信机器人推送类"""
    
    def __init__(self, webhook_url: str):
        """
        初始化企业微信机器人
        
        Args:
            webhook_url: 企业微信机器人的webhook地址
        """
        self.webhook_url = webhook_url
    
    def send_markdown_message(self, content: str) -> bool:
        """
        发送markdown格式消息
        
        Args:
            content: markdown格式的内容
            
        Returns:
            bool: 发送是否成功
        """
        payload = {
            "msgtype": "markdown",
            "markdown": {
                "content": content
            }
        }
        
        return self._send_message(payload)
    
    def send_workflow_status_notification(self, 
                                        date: str,
                                        status: str,
                                        new_papers_count: int = 0,
                                        error_message: str = None) -> bool:
        """
        发送工作流状态通知
        
        Args:
            date: 日期字符串
            status: 状态（success/error/no_content）
            new_papers_count: 新论文数量
            error_message: 错误信息（如果有）
            
        Returns:
            bool: 发送是否成功
        """
        
        if status == "success":
            content = f"""# ✅ arXiv论文更新完成

**📅 日期**: {date}
**📊 新论文数量**: {new_papers_count}篇
**⏰ 完成时间**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

🎉 今日arXiv论文已成功更新并完成AI增强处理！

💡 请访问[项目页面](https://youngjetduan.github.io/daily-arXiv-ai-enhanced/)查看详情"""
        
        elif status == "no_content":
            content = f"""# ℹ️ 今日无新论文

**📅 日期**: {date}
**📊 新论文数量**: 0篇
**⏰ 检查时间**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

📝 今日arXiv论文与历史内容重复，无新论文需要处理。

💡 请访问[项目页面](https://youngjetduan.github.io/daily-arXiv-ai-enhanced/)查看历史论文"""
        
        else:  # error
            content = f"""# ❌ arXiv论文更新失败

**📅 日期**: {date}
**⏰ 失败时间**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
**💥 错误信息**: {error_message or '未知错误'}

🚨 今日arXiv论文处理过程中出现错误，请检查工作流日志。

💡 请访问[项目页面](https://youngjetduan.github.io/daily-arXiv-ai-enhanced/)查看详情"""
        
        return self.send_markdown_message(content)
    
    def _send_message(self, payload: Dict) -> bool:
        """
        发送消息到企业微信机器人
        
        Args:
            payload: 消息负载
            
        Returns:
            bool: 发送是否成功
        """
        try:
            headers = {'Content-Type': 'application/json'}
            response = requests.post(
                self.webhook_url, 
                data=json.dumps(payload, ensure_ascii=False).encode('utf-8'),
                headers=headers,
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                if result.get('errcode') == 0:
                    return True
                else:
                    print(f"企业微信机器人返回错误: {result}")
                    return False
            else:
                print(f"HTTP请求失败: {response.status_code}")
                return False
                
        except Exception as e:
            print(f"发送企业微信消息失败: {e}")
            return False


def get_papers_count(file_path: str) -> int:
    """
    获取指定日期的论文数量
    
    Args:
        file_path: 数据文件路径
        
    Returns:
        int: 论文数量
    """    
    if not os.path.exists(file_path):
        return 0
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            count = sum(1 for line in f if line.strip())
        return count
    except Exception as e:
        print(f"❌ 读取论文文件失败: {e}")
        return 0


def main():
    """命令行入口函数"""
    parser = argparse.ArgumentParser(description="企业微信机器人推送工具")
    parser.add_argument("--data", type=str, required=True, help="jsonline data file")
    parser.add_argument("--status", required=True, choices=["success", "no_content", "error"], help="工作流状态")
    parser.add_argument("--count", type=int, default=-1, help="新论文数量（-1表示自动获取）")
    parser.add_argument("--error", default="", help="错误信息")
    parser.add_argument("--webhook", required=True, help="企业微信Webhook URL")
    
    args = parser.parse_args()
    
    bot = WeChatBot(args.webhook)

    today = datetime.now().strftime("%Y-%m-%d")
    today_file = args.data
    
    # 如果count为-1，自动获取论文数量
    if args.count == -1 and args.status == "success":
        args.count = get_papers_count(today_file)
        print(f"📊 自动获取到论文数量: {args.count}篇")
    
    # 根据状态发送相应的通知
    if args.status == "success":
        success = bot.send_workflow_status_notification(
            date=today,
            status="success",
            new_papers_count=args.count
        )
    elif args.status == "no_content":
        success = bot.send_workflow_status_notification(
            date=today,
            status="no_content",
            new_papers_count=0
        )
    else:  # error
        success = bot.send_workflow_status_notification(
            date=today,
            status="error",
            new_papers_count=0,
            error_message=args.error
        )
    
    if success:
        print("✅ 企业微信消息发送成功")
        exit(0)
    else:
        print("❌ 企业微信消息发送失败")
        exit(1)


if __name__ == "__main__":
    main()
