#!/usr/bin/env python3
import sys
from core.llm import LLMClient
from core.session import SessionManager
from config import load_config

class REPL:
    def __init__(self, session_id=None):
        self.config = load_config()
        self.llm = LLMClient(self.config)
        self.running = False
        self.session_manager = SessionManager()
        if session_id:
            self.session = self.session_manager.load_session(session_id)
            if not self.session:
                self.session = self.session_manager.create_session()
        else:
            self.session = self.session_manager.create_session()

    def get_welcome(self) -> str:
        return "open-cli - AI-assisted programming CLI\nType 'exit' or 'quit' to end session."

    def process_input(self, user_input: str) -> str:
        if user_input.lower() in ("exit", "quit"):
            self.running = False
            return "Goodbye!"

        self.session["messages"].append({"role": "user", "content": user_input})
        response = self.llm.send(self.session["messages"])
        self.session["messages"].append({"role": "assistant", "content": response})
        self.session_manager.save_session(self.session)
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

    repl = REPL(session_id)
    repl.run()
    return 0

if __name__ == "__main__":
    sys.exit(main())