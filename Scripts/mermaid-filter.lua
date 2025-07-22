local system = require 'pandoc.system'
local path = require 'pandoc.path'
local utils = require 'pandoc.utils'

local opts = {
  format = "png",
  theme = "default",
  scale = "4"
}

local filetype = {
  png = ".png",
  svg = ".svg",
  pdf = ".pdf"
}

local mermaid = {
  png = "mmdc",
  svg = "mmdc",
  pdf = "mmdc"
}

function get_temp_dir()
  local tmp = os.getenv("TMPDIR")
  if tmp == nil then
    tmp = "/tmp"  -- fallback to system temp
  end
  -- Remove trailing slash if present
  return string.gsub(tmp, "/$", "")
end

function render_mermaid(code, format)
  local tmpfile = os.tmpname()
  local mermaidfile = tmpfile .. ".mmd"
  local outfile = tmpfile .. filetype[format]

  local f = io.open(mermaidfile, 'w')
  f:write(code)
  f:close()

  -- Get the directory of this script to find the config file
  local script_dir = os.getenv("SCRIPT_DIR") or "Scripts"
  local config_path = script_dir .. "/mermaid-config.json"

  local command = string.format('%s -i %s -o %s -c %s -s %s',
    mermaid[format],
    mermaidfile,
    outfile,
    config_path,
    opts.scale)

  os.execute(command)
  os.remove(mermaidfile)

  local r = io.open(outfile, 'rb')
  local data = r:read("*all")
  r:close()
  os.remove(outfile)

  return data
end

function CodeBlock(block)
  if block.classes[1] == "mermaid" then
    local img = render_mermaid(block.text, opts.format)
    local filename = utils.sha1(img)
    -- Construct filepath manually instead of using path.join
    local filepath = get_temp_dir() .. "/" .. filename .. filetype[opts.format]
    local f = io.open(filepath, 'wb')
    f:write(img)
    f:close()

    return pandoc.Para({pandoc.Image({}, filepath)})
  end
end

return {
  {CodeBlock = CodeBlock}
}