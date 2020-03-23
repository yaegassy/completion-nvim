local vim = vim
local util = require 'utility'
local lsp = require 'source.lsp'
local snippet = require 'source.snippet'
local ins = require 'source.ins_complete'
local ts = require'source.ts_complete'

local M = {}

local complete_items_map = {
  ['lsp'] = {
    trigger = lsp.triggerFunction,
    callback = lsp.getCallback,
    item = lsp.getCompletionItems
  },
  ['snippet'] = {
    item = snippet.getCompletionItems
  },
  ['ts'] = {
    item = ts.getCompletionItems
  }
}

local chain_complete_list = {
  {
    ins_complete = false,
    complete_items = {'lsp', 'snippet'},
  },
  {
    ins_complete = false,
    complete_items = {'snippet'}
  },
  {
    ins_complete=false,
    complete_items = {'ts'}
  },
  {
    ins_complete = true,
    mode = '<c-p>'
  },
  {
    ins_complete = true,
    mode = '<c-n>'
  },
}

M.chain_complete_index = 1
M.stop_complete = false
M.chain_complete_length = #chain_complete_list

local function checkCallback(callback_array)
  for _,val in ipairs(callback_array) do
    if val == false then return false end
    if type(val) == 'function' then
      if val() == false then return end
    end
  end
  return true
end

local function getCompletionItems(items_array, prefix)
  complete_items = {}
  for _,func in ipairs(items_array) do
    vim.list_extend(complete_items, func(prefix, util.fuzzy_score))
  end
  return complete_items
end

function M.triggerCurrentCompletion(manager, bufnr, prefix, textMatch)
  if manager.insertChar == false then return end
  if vim.api.nvim_get_mode()['mode'] == 'i' or vim.api.nvim_get_mode()['mode'] == 'ic' then
    local complete_source = chain_complete_list[M.chain_complete_index]
    if complete_source.ins_complete then
      ins.triggerCompletion(manager, complete_source.mode)
    else
      callback_array = {}
      items_array = {}
      for _, item in ipairs(complete_source.complete_items) do
        complete_items = complete_items_map[item]
        if complete_items.callback == nil then
          table.insert(callback_array, true)
        else
          table.insert(callback_array, complete_items.callback)
          complete_items.trigger(prefix, textMatch, bufnr, manager)
        end
        table.insert(items_array, complete_items.item)
      end
      local timer = vim.loop.new_timer()
      timer:start(20, 50, vim.schedule_wrap(function()
        if checkCallback(callback_array) == true and timer:is_closing() == false then
          if vim.api.nvim_get_mode()['mode'] == 'i' or vim.api.nvim_get_mode()['mode'] == 'ic' then
            items = getCompletionItems(items_array, prefix)
            util.sort_completion_items(items)
            vim.fn.complete(textMatch+1, items)
            if #items ~= 0 then
              manager.insertChar = false
              manager.changeSource = false
            else
              manager.changeSource = true
            end
          end
          timer:stop()
          timer:close()
        end
      end))
    end
  end
end

function M.nextCompletion()
  if M.chain_complete_index ~= #chain_complete_list then
    M.chain_complete_index = M.chain_complete_index + 1
  else
	M.chain_complete_index = 1
  end
end

function M.prevCompletion()
  if M.chain_complete_index ~= 1 then
    M.chain_complete_index = M.chain_complete_index - 1
  else
	M.chain_complete_index = #chain_complete_list
  end
end


return M
