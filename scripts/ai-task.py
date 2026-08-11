#!/usr/bin/env python3
"""
ai-task.py — run an AI-driven browser task with browser-use Agent,
attached to OUR CDP Chrome (the one started by start.sh with the
synced Google profile). This guarantees the AI drives the real
Chrome with the login, not a throwaway browser.

Env:
  BU_TASK            (required) the task description for the agent
  BU_CDP_URL         CDP endpoint (default http://127.0.0.1:9222)
  OPENCODE_BASE_URL  OpenAI-compatible base URL (default opencode.ai/zen/v1)
  OPENCODE_MODEL     model name (default big-pickle)
  OPENCODE_API_KEY   API key (required)

Usage:
  BU_TASK="..." OPENCODE_API_KEY="..." /opt/browser-env/bin/python scripts/ai-task.py
"""
import os
import sys

TASK = os.environ.get("BU_TASK", "").strip()
if not TASK:
    print("❌ BU_TASK env not set")
    sys.exit(1)

API_KEY = os.environ.get("OPENCODE_API_KEY", "").strip()
if not API_KEY:
    print("❌ OPENCODE_API_KEY env not set")
    sys.exit(1)

from browser_use import Agent, Browser, BrowserConfig  # noqa: E402
from langchain_openai import ChatOpenAI  # noqa: E402

llm = ChatOpenAI(
    base_url=os.environ.get("OPENCODE_BASE_URL", "https://opencode.ai/zen/v1"),
    api_key=API_KEY,
    model=os.environ.get("OPENCODE_MODEL", "big-pickle"),
)

browser = Browser(
    config=BrowserConfig(
        cdp_url=os.environ.get("BU_CDP_URL", "http://127.0.0.1:9222"),
    )
)

print(f"🤖 Agent task: {TASK[:120]}…")
try:
    agent = Agent(task=TASK, llm=llm, browser=browser)
    result = agent.run()
    print("RESULT:", result)
    # Exit non-zero if the agent reports failure so the workflow notices.
    text = str(result)
    if text and any(m in text.lower() for m in ("failed", "error", "could not")):
        print("⚠️  Agent finished with an error-ish result.")
        sys.exit(2)
finally:
    try:
        browser.close()
    except Exception:
        pass
