#!/usr/bin/env python3
import sys
from core.llm import LLMClient
from config import load_config

class REPL:
    def __init__(self):
        self.config = load_config()
        self.llm = LLMClient(self.config)
        self.running = False
        self.session_id = None

    def get_welcome(self) -> str:
        return "open-cli - AI-assisted programming CLI\nType 'exit' or 'quit' to end session."

    def process_input(self, user_input: str) -> str:
        if user_input.lower() in ("exit", "quit"):
            self.running = False
            return "Goodbye!"

        messages = [{"role": "user", "content": user_input}]
        response = self.llm.send(messages)
        return response

    def run(self):
        self.running = True
        print(self.get_welcome())
        while self.running:
            try:
                user_input = input("\n> ")
                if not user_input.strip():
                    continue
                response = self.process_input(user_input)
                print(response)
            except KeyboardInterrupt:
                print("\nUse 'exit' to quit.")
            except EOFError:
                break
        print("Session ended.")

def main():
    session_id = None
    args = sys.argv[1:]
    if "--session" in args:
        idx = args.index("--session")
        if idx + 1 < len(args):
            session_id = args[idx + 1]

    repl = REPL()
    repl.session_id = session_id
    repl.run()
    return 0

if __name__ == "__main__":
    sys.exit(main())