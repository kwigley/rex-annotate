-- Run from the repository root: lua5.1 tests/argv_test.lua
package.path = "./?.lua;" .. package.path
local annotate = require("annotate")

local function action(key)
  for _, a in ipairs(annotate.actions) do
    if a.key == key then
      return a
    end
  end
  error("no action " .. key)
end

local function same(got, want, name)
  local g, w = table.concat(got, " "), table.concat(want, " ")
  if g ~= w then
    error(name .. ":\n  got  " .. g .. "\n  want " .. w, 0)
  end
end

local ctx = { block_id = "block:b", session_id = "session:s" }
local config = { submit = true, lines = 200 }

same(
  annotate.build_argv("/bin/pt", config, action("newest"), ctx, {}),
  { "/bin/pt", "rex", "last", "--newest", "--block", "block:b", "--session", "session:s" },
  "newest names the block and session and sends"
)
same(
  annotate.build_argv("/bin/pt", config, action("terminal"), ctx, {}),
  { "/bin/pt", "rex", "terminal", "--block", "block:b", "--session", "session:s", "--lines", "200" },
  "terminal reads the configured number of lines"
)
same(
  annotate.build_argv("/bin/pt", config, action("open"), ctx, {}),
  { "/bin/pt", "rex", "open", "--block", "block:b", "--session", "session:s" },
  "open takes no line count"
)
same(
  annotate.build_argv("/bin/pt", { submit = false, lines = 200 }, action("open"), ctx, {}),
  { "/bin/pt", "rex", "open", "--block", "block:b", "--session", "session:s", "--paste" },
  "submit = false pastes"
)
same(
  annotate.build_argv("/bin/pt", { submit = false, lines = 200 }, action("open"), ctx, { paste = false }),
  { "/bin/pt", "rex", "open", "--block", "block:b", "--session", "session:s" },
  "an explicit paste = false beats the config"
)
print("ok")
