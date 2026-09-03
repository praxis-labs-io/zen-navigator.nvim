-- zen-navigator.nvim — seamless Ctrl-hjkl navigation across nvim splits and ZenTerm panes.
--
-- Detection and hand-off both ride ZenTerm's nav socket (`$ZEN_SOCK`), addressing this pane
-- by its `$ZEN_PANE` token. When neither is set (not running under ZenTerm) every mapping
-- degrades to a plain `wincmd`, so the plugin is inert outside ZenTerm.
--
-- One connection is opened lazily and held, because ZenTerm clears this pane's nvim flag
-- when the channel reaches EOF. That is what covers a crash, a SIGKILL, or a death nested
-- inside a long-running foreground command, where VimLeave never runs. When ZenTerm itself
-- goes away the channel is dropped and the next command reopens it.
--
-- Protocol: docs/nvim-navigator-protocol.md in the zen-term repo.

local M = {}

local sock = vim.env.ZEN_SOCK
local pane = vim.env.ZEN_PANE

-- h/j/k/l → the direction names ZenTerm's socket expects.
local DIRECTIONS = { h = "left", j = "down", k = "up", l = "right" }

-- The held channel, and whether this nvim currently claims the pane's nvim flag (so a
-- reconnect can re-declare it: the old channel's EOF already dropped it on ZenTerm's side).
local channel = nil
local claiming = false

-- Running inside ZenTerm with a reachable nav socket?
local function under_zenterm()
  return sock ~= nil and sock ~= "" and pane ~= nil and pane ~= ""
end

-- `on_data` is the only reliable death signal: a `chansend` to a channel whose peer has gone
-- still reports the bytes written, so failure alone never tells us to reconnect. Neovim calls
-- it with a single empty string on EOF. An *empty* opts table would break here, marshalling
-- to a list that sockconnect rejects with "E475: expected dictionary".
local function connect()
  local ok, chan = pcall(vim.fn.sockconnect, "pipe", sock, {
    on_data = function(id, data)
      if id == channel and data[1] == "" and #data == 1 then
        channel = nil
      end
    end,
  })
  if ok and chan ~= 0 then
    return chan
  end
  return nil
end

-- Write one JSON line on the held channel. False means the channel is gone.
local function write(payload)
  if not channel then
    return false
  end
  local ok, sent = pcall(vim.fn.chansend, channel, vim.fn.json_encode(payload) .. "\n")
  return ok and sent > 0
end

local function claim()
  return { cmd = "setvim", pane = tonumber(pane), vim = true, hold = true }
end

-- Fire-and-forget one command, reconnecting once if the channel died under us. Best-effort:
-- any failure (socket gone, ZenTerm not running) is swallowed so editing never breaks on a
-- bad hand-off.
local function send(payload)
  if not under_zenterm() then
    return
  end
  if write(payload) then
    return
  end

  if channel then
    pcall(vim.fn.chanclose, channel)
    channel = nil
  end
  channel = connect()
  if not channel then
    return
  end
  -- The dead channel's EOF cleared the flag on ZenTerm's side, so re-declare before the
  -- payload rather than leaving this pane unflagged until the next VimResume.
  if claiming and payload.cmd ~= "setvim" then
    write(claim())
  end
  write(payload)
end

-- Move within nvim; if already at the edge in that direction, hand off to ZenTerm so it
-- moves pane focus. The edge test is `vim-tmux-navigator`'s: the window number is unchanged
-- after `wincmd` exactly when there was nowhere to go.
function M.navigate(key)
  local from = vim.fn.winnr()
  vim.cmd("wincmd " .. key)
  if from == vim.fn.winnr() then
    send({ cmd = "focus", dir = DIRECTIONS[key], pane = tonumber(pane) })
  end
end

-- Advertise (or clear) nvim presence so ZenTerm's guard won't steal Ctrl-hjkl from this pane.
-- `hold` ties the flag to this channel; the EOF clear is the backstop when VimLeave can't run.
local function set_vim(on)
  claiming = on
  if on then
    send(claim())
  else
    send({ cmd = "setvim", pane = tonumber(pane), vim = false })
  end
end

-- opts.default_mappings = false to bind Ctrl-hjkl yourself via require("zen-navigator").navigate.
function M.setup(opts)
  opts = opts or {}

  local group = vim.api.nvim_create_augroup("ZenNavigator", { clear = true })
  vim.api.nvim_create_autocmd({ "VimEnter", "VimResume" }, {
    group = group,
    callback = function()
      set_vim(true)
    end,
  })
  vim.api.nvim_create_autocmd({ "VimLeave", "VimSuspend" }, {
    group = group,
    callback = function()
      set_vim(false)
    end,
  })
  -- Lazy-loaded after VimEnter already fired: flag immediately so the guard is armed now.
  if vim.v.vim_did_enter == 1 then
    set_vim(true)
  end

  if opts.default_mappings ~= false then
    for key, dir in pairs(DIRECTIONS) do
      vim.keymap.set("n", "<C-" .. key .. ">", function()
        M.navigate(key)
      end, { silent = true, desc = "ZenNavigator: move " .. dir })
    end
  end
end

return M
