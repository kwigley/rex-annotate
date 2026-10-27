# rex-annotate

Annotate your coding agent's replies, your Markdown documents, and terminal output in
[Rex](https://www.superlogical.com/rex), then send the feedback straight back to the agent.

Press a key in a pane that runs Claude Code. A review opens in a split beside it. Select
text, mark it 👍 looks good, 💬 comment, or ✗ delete, and press `E`. The agent gets your
notes as its next message, numbered and quoted:

```
# Annotations on claude · last message

## Annotation 1
Comment on: "Rotate the token on every request"
> Only on privilege changes. Rotating every request logs people out.
```

The review app is [plannotator-tui](https://github.com/plannotator/plannotator-tui). This
repository is its Rex integration: one Lua module, an installer, and an agent skill. It is the
Rex counterpart of [herdr-annotate](https://github.com/plannotator/herdr-annotate).

## Requirements

- Rex, with the `rex` command on `PATH`
- Rust and Cargo, to build plannotator-tui
- An agent whose transcripts plannotator-tui reads: Claude Code, Codex, pi, OpenCode, and
  [others](https://github.com/plannotator/plannotator-tui#use)

## Install

From a Rex terminal:

```sh
git clone https://github.com/kwigley/rex-annotate
cd rex-annotate
./install.sh
```

The installer does these steps:

1. It builds plannotator-tui with Rex support into `~/.cargo/bin`.
2. It copies `annotate.lua` beside your `init.lua`.
3. It adds `require("annotate").setup{}` to `init.lua`, if the line is not there. It backs up
   the file first.
4. It checks the configuration and reloads Rex.

Run it again to upgrade. Add `--with-skill` to also install the agent skill (see
[Let the agent ask for a review](#let-the-agent-ask-for-a-review)).

> Rex support is in review for plannotator-tui. Until a release includes it, the installer
> builds from [kwigley/plannotator-tui](https://github.com/kwigley/plannotator-tui), branch
> `feat/rex-integration`. Set `PLANNOTATOR_TUI_GIT` and `PLANNOTATOR_TUI_REF` to build from
> another source.

## Use

Focus a pane, then press a key:

| Key | Opens |
| --- | --- |
| <kbd>Cmd</kbd>+<kbd>Shift</kbd>+<kbd>O</kbd> | The agent's recent replies. Pick one to annotate. |
| <kbd>Cmd</kbd>+<kbd>Option</kbd>+<kbd>O</kbd> | The agent's newest reply, without the picker. |
| <kbd>Cmd</kbd>+<kbd>Shift</kbd>+<kbd>E</kbd> | The Markdown files in the pane's folder. |
| <kbd>Cmd</kbd>+<kbd>Option</kbd>+<kbd>T</kbd> | The pane's last 200 lines of output. |

The actions are also in the command palette, under **Annotate**.

In the review:

| Key | Does |
| --- | --- |
| drag, or `v` then move and `Enter` | Select text |
| `a` `c` `d` | Mark the selection looks good, comment on it, or mark it for deletion |
| `c` | Comment on the block under the cursor |
| `E` | Send the feedback |
| `S` | Send and close (reply reviews) |
| `?` | Show every key |
| `q` | Close |

When an agent runs in the pane, the header names it: `Send 2 ▸ claude in a1d6db (E)`.
Without an agent, the review copies the feedback to the clipboard.

The review refuses to send while the agent waits at a permission prompt or a question. Answer
the prompt, then press `E` again.

### Edit before you send

To put the feedback in the agent's prompt without pressing Enter, set `submit = false`.
The agent's pane takes focus, so you can edit the text, and then you press Enter to send it:

```lua
require("annotate").setup{ submit = false }
```

To keep both behaviors, bind a second key to an action with `paste = true`:

```lua
require("annotate").setup{}
rex.bind("cmd+shift+p", "annotate_newest", { paste = true })
```

## Configure

Every option is optional:

```lua
require("annotate").setup{
  -- plannotator-tui to run. Found in ~/.cargo/bin, ~/.local/bin, and Homebrew when nil.
  bin = nil,
  -- false leaves the feedback in the agent's prompt instead of sending it.
  submit = true,
  -- How many recent lines a terminal review reads.
  lines = 200,
  -- A key for each action. false leaves one unbound; keys = false binds none.
  keys = {
    last = "cmd+shift+o",
    newest = "cmd+alt+o",
    open = "cmd+shift+e",
    terminal = "cmd+alt+t",
  },
}
```

The actions are `annotate_last`, `annotate_newest`, `annotate_open`, and `annotate_terminal`.
Each accepts `paste`. Bind them with `rex.bind` as you would any action.

plannotator-tui reads its own settings from `~/.config/plannotator-tui/config.toml`. Run
`plannotator-tui config` to see them.

### Light themes

Rex does not tell programs the colors of its theme, so plannotator-tui assumes a dark
background. With a light Rex theme, set this:

```toml
# ~/.config/plannotator-tui/config.toml
[ui]
theme = "light"
```

## Let the agent ask for a review

With the skill installed (`./install.sh --with-skill`), Claude Code can open a document for
your review itself. It writes the plan to a file and runs this command:

```sh
plannotator-tui rex open docs/plans/auth.md
```

The review opens beside the agent. The agent ends its turn and waits for your feedback.

Any agent can do the same. In a Rex terminal, the launcher reviews the pane it runs in, so
no setup is necessary. The skill only tells the agent when to do it.

## How it works

Each action runs `plannotator-tui rex <review> --block <pane>`. The launcher does these steps:

1. It asks Rex which program runs in the pane. The process ID finds the agent's transcript.
2. It opens a split to the right of the pane, with plannotator-tui in it.
3. It exits.

When you send, plannotator-tui asks Rex whether the agent waits at a prompt. It then pastes
the feedback into the agent's pane as one bracketed paste, and presses Enter.

The commands work without the Lua module too:

```sh
plannotator-tui rex last [--newest] [--paste] [--block ID]
plannotator-tui rex open [PATH] [--paste] [--block ID]
plannotator-tui rex terminal [--lines N] [--paste] [--print] [--block ID]
```

## Troubleshooting

**A key does nothing.** Run the action from the command palette, or from a Rex terminal
with `rex do annotate_newest`. Rex shows the error. Then run `rex keymap` to see which
action the key runs.

**`… has no Rex support`.** Another plannotator-tui comes first, for example one from
Homebrew. Run `./install.sh`, or set `bin` to the build with Rex support.

**`no supported agent runs in this block`.** The focused pane does not run an agent that
plannotator-tui can read. Focus the agent's pane, or use the folder or terminal review.

## Uninstall

```sh
./install.sh --uninstall
cargo uninstall plannotator-tui
```

## Development

`scripts/smoke.sh` tests an installed copy from end to end. It works in a throwaway Rex
session, and removes the session when it is done. The script runs each action the same way
a key press does, against a stand-in agent that shows every byte it receives.

```sh
./install.sh --no-build && scripts/smoke.sh
```

## Credits

- [plannotator-tui](https://github.com/plannotator/plannotator-tui) and
  [herdr-annotate](https://github.com/plannotator/herdr-annotate), by Michael Ramos, do the
  review. This repository connects them to Rex.
- [ah](https://github.com/david-crespo/ah), by David Crespo, showed how much a terminal
  can do with Rex and an agent together.

## License

[MIT](LICENSE)
