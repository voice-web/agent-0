# Tool use (function calling) with Ollama

LLMs have no built-in access to your filesystem or OS. They only see text in and produce text out. To let a model "list files" or "run git commands," you add **tools**: you define functions (e.g. "list directory", "run git add and commit"), send those definitions to Ollama, and when the model asks to call a tool you **run it yourself** and send the result back. That's **tool use** (or **function calling**).

Ollama supports this via the chat API: you pass a `tools` array and, when the model returns `tool_calls`, you execute the corresponding function and append a `tool` message with the result, then call the API again for the final reply.

---

## 1. How it works

1. You send a request with `messages` and `tools` (list of function names, descriptions, and parameters in JSON Schema form).
2. The model may reply with `tool_calls`: one or more requests to run a tool with specific arguments.
3. You run the tool **on your machine** (e.g. list a directory, run a shell command) and get a result string.
4. You append a message with `role: "tool"`, `tool_name`, and `content` (the result), then send the updated `messages` back to Ollama.
5. The model uses the tool result to produce a final answer.

**Important:** The model never runs code. Your application executes the tools and feeds results back.

---

## 2. API shape (Ollama chat)

**Request:** Include `tools` in the body:

```json
{
  "model": "qwen3",
  "messages": [{"role": "user", "content": "List the files in /tmp"}],
  "stream": false,
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "list_directory",
        "description": "List files and directories in the given path",
        "parameters": {
          "type": "object",
          "required": ["path"],
          "properties": {
            "path": {"type": "string", "description": "Absolute or relative directory path"}
          }
        }
      }
    }
  ]
}
```

**Response:** The model may return `message.tool_calls`:

```json
{
  "message": {
    "role": "assistant",
    "tool_calls": [
      {
        "type": "function",
        "function": {
          "name": "list_directory",
          "arguments": {"path": "/tmp"}
        }
      }
    ]
  }
}
```

You then run your `list_directory("/tmp")`, and send a follow-up request with the assistant message plus a tool result:

```json
{"role": "tool", "tool_name": "list_directory", "content": "file1.txt\nfile2.log\ndir/"}
```

---

## 3. Example: search / list files in a path

Define a tool that lists or searches files; execute it with Python (or subprocess) and return the result as a string.

**Tool definition (for `tools` array):**

```json
{
  "type": "function",
  "function": {
    "name": "list_directory",
    "description": "List all files and subdirectories in the given path. Use for searching or browsing a directory.",
    "parameters": {
      "type": "object",
      "required": ["path"],
      "properties": {
        "path": {"type": "string", "description": "Directory path to list (e.g. /Users/me/project)"}
      }
    }
  }
}
```

**Python: implement and call Ollama**

```python
import os
from ollama import chat

def list_directory(path: str) -> str:
    """List all files and subdirectories in the given path."""
    if not os.path.isdir(path):
        return f"Error: not a directory or does not exist: {path}"
    try:
        entries = os.listdir(path)
        return "\n".join(sorted(entries)) or "(empty)"
    except PermissionError:
        return "Error: permission denied"
    except OSError as e:
        return f"Error: {e}"

tools_schema = [
    {
        "type": "function",
        "function": {
            "name": "list_directory",
            "description": "List all files and subdirectories in the given path.",
            "parameters": {
                "type": "object",
                "required": ["path"],
                "properties": {"path": {"type": "string", "description": "Directory path"}},
            },
        },
    }
]

messages = [{"role": "user", "content": "What files are in /tmp?"}]
response = chat(model="qwen3", messages=messages, tools=tools_schema)

if response.message.tool_calls:
    for call in response.message.tool_calls:
        name = call.function.name
        args = call.function.arguments or {}
        result = list_directory(args.get("path", ""))
        messages.append(response.message)
        messages.append({"role": "tool", "tool_name": name, "content": result})
    response = chat(model="qwen3", messages=messages, tools=tools_schema)

print(response.message.content)
```

You can add a second tool (e.g. `search_files(path, pattern)`) that uses `os.walk` or `subprocess.run(["find", path, "-name", pattern])` and return the result string the same way.

---

## 4. Example: run a set of commands (e.g. git add, commit, push)

Expose a single tool that runs a **fixed** sequence of commands with **parameters** you pass (e.g. path to add, commit message). Run the commands yourself (e.g. `subprocess.run`) and return stdout/stderr so the model can summarize or report errors.

**Tool definition:**

```json
{
  "type": "function",
  "function": {
    "name": "git_add_commit_push",
    "description": "Run git add on a path, then git commit with a message, then git push. Use for committing and pushing changes.",
    "parameters": {
      "type": "object",
      "required": ["add_path", "commit_message"],
      "properties": {
        "add_path": {"type": "string", "description": "Path to add (e.g. . or a file path)"},
        "commit_message": {"type": "string", "description": "Commit message for git commit -m"}
      }
    }
  }
}
```

**Python: implement (run commands, return combined output)**

```python
import subprocess
from ollama import chat

def git_add_commit_push(add_path: str, commit_message: str) -> str:
    """Run git add <path>; git commit -m <msg>; git push. Returns combined stdout/stderr."""
    # Use a list of args to avoid shell injection; run in repo (cwd can be set by caller)
    results = []
    for cmd in [
        ["git", "add", add_path],
        ["git", "commit", "-m", commit_message],
        ["git", "push"],
    ]:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        out = (r.stdout or "").strip() or "(no output)"
        err = (r.stderr or "").strip()
        results.append(f"$ {' '.join(cmd)}\nstdout: {out}" + (f"\nstderr: {err}" if err else ""))
        if r.returncode != 0:
            results.append(f"exit code: {r.returncode}")
            break
    return "\n---\n".join(results)

tools_schema = [
    {
        "type": "function",
        "function": {
            "name": "git_add_commit_push",
            "description": "Run git add, git commit with message, and git push.",
            "parameters": {
                "type": "object",
                "required": ["add_path", "commit_message"],
                "properties": {
                    "add_path": {"type": "string", "description": "Path to add (e.g. . or file)"},
                    "commit_message": {"type": "string", "description": "Commit message"},
                },
            },
        },
    }
]

messages = [{"role": "user", "content": "Add all changes, commit with message 'docs: add tool-use', and push."}]
response = chat(model="qwen3", messages=messages, tools=tools_schema)

if response.message.tool_calls:
    for call in response.message.tool_calls:
        name = call.function.name
        args = call.function.arguments or {}
        result = git_add_commit_push(
            args.get("add_path", "."),
            args.get("commit_message", "update"),
        )
        messages.append(response.message)
        messages.append({"role": "tool", "tool_name": name, "content": result})
    response = chat(model="qwen3", messages=messages, tools=tools_schema)

print(response.message.content)
```

**Security:** Use argument lists (e.g. `["git", "commit", "-m", commit_message]`) and avoid passing user-controlled strings to a shell. Restrict allowed paths or commands if the app is exposed to untrusted users.

---

## 5. Models that support tool calling

Not every model supports tool calls. Ollama’s docs list support for **Llama 3.1+**, **Qwen 2.5/3**, **Command-R+**, **Mistral**, and others. Use a model that supports tools (e.g. `qwen3`, `llama3.1`) when testing.

---

## 6. Summary

| Step | You do |
|------|--------|
| 1 | Define tools (name, description, parameters as JSON Schema). |
| 2 | Send `messages` + `tools` to Ollama chat API. |
| 3 | If the response has `tool_calls`, run each tool **on your machine** with the given arguments. |
| 4 | Append the assistant message and one `role: "tool"` message per call with the result string. |
| 5 | Call the API again with the updated messages; the model uses the tool output to reply. |

The model never executes code; it only requests tool calls. Your application is responsible for running the tools safely and returning their output.
