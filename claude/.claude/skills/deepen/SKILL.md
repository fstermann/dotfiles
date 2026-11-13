---
name: deepen
description: Rewrite a task prompt into a deeper version, framed by how a top professional in the field would approach it. Invoke via /deepen <task or prompt>.
disable-model-invocation: true
---

The task is in the arguments. I want a deeper version of this task, not a bigger one. Before rewriting it:

1. Say what a top professional in this field would do here that I'm not asking for.
2. Name the rawest material they would start from instead of what has already been digested for me.
3. Name the specific methods and tools they would use.
4. Say what, other than you or me, would show the result is right.

Then rewrite my prompt to ask for exactly that.

Finally, ask with `AskUserQuestion` whether to run the rewritten prompt now.
