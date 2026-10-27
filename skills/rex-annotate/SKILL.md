---
name: rex-annotate
description: Open a Markdown plan or document for the human to review and annotate in a Rex pane beside you; their feedback arrives as your next message. Use when you have written a plan, spec, or design document that needs human review before you act on it, or when the human asks to annotate your reply.
---

# rex-annotate: hand a document to the human for review

Use this only inside Rex, when `REX_BLOCK` is set. Otherwise, tell the human where the file
is and ask them to review it.

1. Write the document to a file. Do not also paste it into the chat.
2. Open the file for review from your own shell:

   ```bash
   plannotator-tui rex open docs/plans/auth.md
   ```

   plannotator-tui opens in a split to your right. It sends the feedback back to your pane.
   The command returns when the split is open.
3. **End your turn.** Do not wait, poll, or read the split. The review arrives as the next
   user message, in this form:

   ```
   # Annotations on docs/plans/auth.md

   ## Annotation 1 (line 12)
   Comment on: "Rotate the token on every…"
   > Rotation on every privilege change will log people out…
   ```

   Address every annotation, then continue.

When the human asks to annotate your last reply, run `plannotator-tui rex last --newest`
and end your turn the same way.

If the command fails with `unknown` or prints its usage without `rex pane`, the
`plannotator-tui` on `PATH` has no Rex support. Use `~/.cargo/bin/plannotator-tui`.
