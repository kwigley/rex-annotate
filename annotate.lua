--- rex-annotate: annotate an agent's replies, your documents, and terminal output with
--- plannotator-tui, and send the feedback back to the agent.
---
--- Each action opens plannotator-tui in a split beside the focused pane. When an agent runs
--- in that pane, the review is wired to it: send (`E`, or `S` to send and close) and the
--- numbered feedback becomes its next message.
---
--- ```lua
--- -- ~/.config/rex/init.lua
--- require("annotate").setup{}
--- ```
local M = {}

local defaults = {
  -- plannotator-tui to run. Found in the usual install locations when nil.
  bin = nil,
  -- false leaves feedback in the agent's prompt to edit and submit, instead of sending it.
  submit = true,
  -- How many recent lines a terminal review reads.
  lines = 200,
  -- A key for each action. Set one to false to leave it unbound, or keys = false for none.
  keys = {
    last = "cmd+shift+o",
    newest = "cmd+alt+o",
    open = "cmd+shift+e",
    terminal = "cmd+alt+t",
  },
}

local actions = {
  {
    name = "annotate_last",
    key = "last",
    title = "Annotate: Agent's Recent Replies",
    description = "Pick one of the focused agent's recent replies, annotate it, and send the feedback back.",
    keywords = "plannotator review reply claude codex feedback",
    review = { "last" },
  },
  {
    name = "annotate_newest",
    key = "newest",
    title = "Annotate: Agent's Newest Reply",
    description = "Annotate the focused agent's newest reply without the picker, and send the feedback back.",
    keywords = "plannotator review reply claude codex feedback last",
    review = { "last", "--newest" },
  },
  {
    name = "annotate_open",
    key = "open",
    title = "Annotate: Documents in This Folder",
    description = "Review the Markdown files in the focused pane's folder, and send the feedback to its agent.",
    keywords = "plannotator review markdown plan spec docs folder",
    review = { "open" },
  },
  {
    name = "annotate_terminal",
    key = "terminal",
    title = "Annotate: Terminal Output",
    description = "Annotate the focused pane's recent output, and send the feedback to its agent or the clipboard.",
    keywords = "plannotator review output log scrollback",
    review = { "terminal" },
  },
}

local function readable(path)
  local file = io.open(path, "r")
  if file == nil then
    return false
  end
  file:close()
  return true
end

--- The first plannotator-tui in the places installers put it. Rex runs actions with a bare
--- PATH, so `PATH` alone would miss them. Cargo comes first: it holds the build with Rex
--- support until a release does.
local function find_bin()
  local home = os.getenv("HOME") or ""
  local candidates = {
    home .. "/.cargo/bin/plannotator-tui",
    home .. "/.local/bin/plannotator-tui",
    "/opt/homebrew/bin/plannotator-tui",
    "/usr/local/bin/plannotator-tui",
    "/usr/bin/plannotator-tui",
  }
  for _, path in ipairs(candidates) do
    if readable(path) then
      return path
    end
  end
  return nil
end

local function merge(base, overrides)
  local out = {}
  for k, v in pairs(base) do
    out[k] = v
  end
  for k, v in pairs(overrides or {}) do
    out[k] = v
  end
  return out
end

local function launcher(config, action)
  return function(ctx, args)
    local bin = config.bin or find_bin()
    if bin == nil then
      error("plannotator-tui not found; install it or set bin in require(\"annotate\").setup{}", 0)
    end
    if ctx.block_id == nil then
      error("no focused pane to review", 0)
    end
    local argv = { bin, "rex" }
    for _, word in ipairs(action.review) do
      argv[#argv + 1] = word
    end
    for _, word in ipairs({ "--block", ctx.block_id, "--session", ctx.session_id }) do
      argv[#argv + 1] = word
    end
    if action.key == "terminal" then
      argv[#argv + 1] = "--lines"
      argv[#argv + 1] = tostring(config.lines)
    end
    local paste = args.paste
    if paste == nil then
      paste = not config.submit
    end
    if paste then
      argv[#argv + 1] = "--paste"
    end
    -- The launcher exits as soon as the split is open, so waiting surfaces its errors.
    local result, err = rex.exec(argv, { timeout = 15 })
    if result == nil then
      error("plannotator-tui: " .. tostring(err), 0)
    end
    if not result.ok then
      local message = (result.stderr ~= "" and result.stderr or result.stdout):gsub("%s+$", "")
      error((message:gsub("^Error: ", "")), 0)
    end
    return true
  end
end

--- Define the actions and bind their keys. Every option is optional; see `defaults`.
function M.setup(opts)
  opts = opts or {}
  local config = merge(defaults, opts)
  local keys = opts.keys == false and {} or merge(defaults.keys, opts.keys)
  for _, action in ipairs(actions) do
    rex.action({
      name = action.name,
      title = action.title,
      description = action.description,
      category = "Annotate",
      keywords = action.keywords,
      args = { paste = "boolean?" },
      run = launcher(config, action),
    })
    if keys[action.key] then
      rex.bind(keys[action.key], action.name)
    end
  end
  return M
end

return M
