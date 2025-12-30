-- GrisuDebug
--
-- @author  Grisu118 - VertexDezign.net
-- @history	    v1.0    - 2016-10-26 - Initial implementation
-- @history     v1.1    - 2017-09-15 - Add Off Level, add shorthand methods for logging, add support for closures
-- @history     v1.2    - 2024-11-19 - Add function to print table
-- @history     v1.3    - 2024-11-24 - Add support for string.format
-- @history     v1.4    - 2025-12-20 - Colorful output, support xmlWarn / error
-- @Descripion: Providing debug utils
-- @web: http://grisu118.ch or http://vertexdezign.net
-- Copyright (C) Grisu118, All Rights Reserved.

---@class GrisuDebug
GrisuDebug = {}
GrisuDebug.__index = GrisuDebug

GrisuDebug.TRACE = 1
GrisuDebug.DEBUG = 2
GrisuDebug.INFO = 3
GrisuDebug.WARNING = 4
GrisuDebug.ERROR = 5
GrisuDebug.OFF = 6

function GrisuDebug.parseLogLevel(txt)
  local lvl = GrisuDebug[txt]
  if lvl ~= nil and type(lvl) == "number" then
    return lvl
  else
    return GrisuDebug.INFO
  end
end

---@return GrisuDebug
function GrisuDebug:create(name)
  local d = {} -- our new object
  setmetatable(d, GrisuDebug) -- make Account handle lookup
  d.name = name -- initialize our object
  d.lvl = GrisuDebug.DEBUG
  return d
end

function GrisuDebug:setLogLvl(lvl)
  self.lvl = lvl
end

function GrisuDebug:trace(txt, ...)
  self:print(GrisuDebug.TRACE, nil, txt, ...)
end

function GrisuDebug:debug(txt, ...)
  self:print(GrisuDebug.DEBUG, nil, txt, ...)
end

---@param txt string | function the info message. Can contain string-format placeholders
function GrisuDebug:info(txt, ...)
  self:print(GrisuDebug.INFO, nil, txt, ...)
end

---@param txt string | function the warning message. Can contain string-format placeholders
function GrisuDebug:warn(txt, ...)
  self:print(GrisuDebug.WARNING, nil, txt, ...)
end

---@param txt string | function the error message. Can contain string-format placeholders
function GrisuDebug:error(txt, ...)
  self:print(GrisuDebug.ERROR, nil, txt, ...)
end

---Prints a xml warning to console and logfile
---@param xmlFile XMLFile xml file object or xml handle
---@param txt string | function  the warning message. Can contain string-format placeholders
---@param ... any variable number of parameters. Depends on placeholders in warning message
function GrisuDebug:xmlWarn(xmlFile, txt, ...)
  local filename = xmlFile:getFilename()
  self:print(GrisuDebug.WARNING, filename, txt, ...)
end

---Prints a xml error to console and logfile'
---@param xmlFile XMLFile xml file object or xml handle
---@param txt string | function  the error message. Can contain string-format placeholders
---@param ... any variable number of parameters. Depends on placeholders in error message
function GrisuDebug:xmlError(xmlFile, txt, ...)
  local filename = xmlFile:getFilename()
  self:print(GrisuDebug.ERROR, filename, txt, ...)
end

---@param name string The name of the table
---@param tbl table The table to print all members of
---@param recursive boolean
---@return void
function GrisuDebug:tPrint(name, tbl, recursive)
  self:info("Debug Table: '" .. name .. "'")
  print(self:_tprint(tbl, 0, recursive))
end

---@param level number the log level
---@param id string an optional identifier, for example xmlFile for xmlWarning
---@param txt string | function The text to log
function GrisuDebug:print(lvl, id, txt, ...)
  if lvl < self.lvl then
    return
  end
  local level = "TRACE"
  if lvl == GrisuDebug.ERROR then
    level = "ERROR"
  elseif lvl == GrisuDebug.WARNING then
    level = "WARN"
  elseif lvl == GrisuDebug.INFO then
    level = "INFO"
  elseif lvl == GrisuDebug.DEBUG then
    level = "DEBUG"
  end

  local text
  if type(txt) == "function" then
    text = txt()
  else
    text = string.format(tostring(txt), ...)
  end

  local message
  if id == nil then
    message = ("[%s] %s: %s"):format(level, self.name, text)
  else
    message = ("[%s] %s(%s): %s"):format(level, self.name, id, text)
  end

  if lvl == GrisuDebug.WARNING then
    printWarning(message)
  elseif lvl == GrisuDebug.ERROR then
    printError(message)
  else
    print(message)
  end
end

---@param tbl table
---@param indent number
---@param recursive boolean
function GrisuDebug:_tprint (tbl, indent, recursive)
  if not indent then
    indent = 0
  end
  if tbl == nil then
    return string.rep(" ", indent) .. "nil"
  end
  local toprint = string.rep(" ", indent) .. "{\r\n"
  indent = indent + 2
  for k, v in pairs(tbl) do
    toprint = toprint .. string.rep(" ", indent)
    if (type(k) == "number") then
      toprint = toprint .. "[" .. k .. "] = "
    elseif (type(k) == "string") then
      toprint = toprint .. k .. "= "
    end
    if (type(v) == "number") then
      toprint = toprint .. v .. ",\r\n"
    elseif (type(v) == "string") then
      toprint = toprint .. "\"" .. v .. "\",\r\n"
    elseif (type(v) == "table") then
      if recursive and indent < 10 then
        toprint = toprint .. self:_tprint(v, indent + 2, recursive) .. ",\r\n"
      else
        toprint = toprint .. "table, \r\n"
      end
    else
      toprint = toprint .. "\"" .. tostring(v) .. "\",\r\n"
    end
  end
  toprint = toprint .. string.rep(" ", indent - 2) .. "}"
  return toprint
end