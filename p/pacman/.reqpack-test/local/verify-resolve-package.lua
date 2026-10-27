local seen = {}

reqpack = {
  exec = {
    run = function(command)
      if command == "command -v pacman >/dev/null 2>&1" then
        return { success = true, exitCode = 0, stdout = "", stderr = "" }
      end
      return {
        success = false,
        exitCode = 127,
        stdout = "",
        stderr = "unexpected global exec: " .. tostring(command),
      }
    end,
  },
}

package.loaded["run"] = nil
dofile("run.lua")

local responses = {
  ["LC_ALL=C pacman -Si curl"] = {
    success = true,
    exitCode = 0,
    stdout = table.concat({
      "Repository      : extra",
      "Name            : curl",
      "Version         : 8.8.0-1",
      "Description     : command line tool and library for transferring data with URLs",
      "Architecture    : x86_64",
      "URL             : https://curl.se",
      "Licenses        : curl",
      "Depends On      : brotli  zlib  openssl",
      "Optional Deps   : bash-completion: command completion",
      "",
    }, "\n"),
    stderr = "",
  },
  ["LC_ALL=C pacman -Si missing-curl"] = {
    success = false,
    exitCode = 1,
    stdout = "",
    stderr = "error: package 'missing-curl' was not found\n",
  },
  ["LC_ALL=C pacman -Qi missing-curl"] = {
    success = false,
    exitCode = 1,
    stdout = "",
    stderr = "error: package 'missing-curl' was not found\n",
  },
}

local context = {
  exec = {
    run = function(command)
      table.insert(seen, command)
      local result = responses[command]
      if result then
        return result
      end
      return {
        success = false,
        exitCode = 127,
        stdout = "",
        stderr = "unexpected command: " .. tostring(command),
      }
    end,
  },
  log = {
    error = function(message)
      error("unexpected log error: " .. tostring(message))
    end,
  },
}

local resolved = plugin.resolvePackage(context, {
  name = "curl",
})

if type(resolved) ~= "table" then
  error("resolvePackage did not return table")
end

if resolved.name ~= "curl" then
  error("unexpected resolved name: " .. tostring(resolved.name))
end

if resolved.version ~= "8.8.0-1" then
  error("unexpected resolved version: " .. tostring(resolved.version))
end

if resolved.repository ~= "extra" then
  error("unexpected resolved repository: " .. tostring(resolved.repository))
end

if resolved.architecture ~= "x86_64" then
  error("unexpected resolved architecture: " .. tostring(resolved.architecture))
end

local missing = plugin.resolvePackage(context, {
  name = "missing-curl",
})

if missing ~= nil then
  error("missing package should resolve to nil")
end

if seen[1] ~= "LC_ALL=C pacman -Si curl" then
  error("unexpected first command: " .. tostring(seen[1]))
end

print("resolvePackage verified")
