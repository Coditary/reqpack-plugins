package.path = './?.lua;' .. package.path

reqpack = {
  exec = {
    run = function(command)
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=pkgver hello" then
        return { success = false, stdout = '', stderr = 'not found', exitCode = 1 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=short_desc hello" then
        return { success = false, stdout = '', stderr = 'not found', exitCode = 1 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=homepage hello" then
        return { success = false, stdout = '', stderr = 'not found', exitCode = 1 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=license hello" then
        return { success = false, stdout = '', stderr = 'not found', exitCode = 1 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=repository hello" then
        return { success = false, stdout = '', stderr = 'not found', exitCode = 1 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=architecture hello" then
        return { success = false, stdout = '', stderr = 'not found', exitCode = 1 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache -x hello" then
        return { success = false, stdout = '', stderr = 'not found', exitCode = 1 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=categories hello" then
        return { success = false, stdout = '', stderr = 'not found', exitCode = 1 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=state hello" then
        return { success = false, stdout = '', stderr = 'not found', exitCode = 1 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=automatic-install hello" then
        return { success = false, stdout = '', stderr = 'not found', exitCode = 1 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=hold hello" then
        return { success = false, stdout = '', stderr = 'not found', exitCode = 1 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=repolock hello" then
        return { success = false, stdout = '', stderr = 'not found', exitCode = 1 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --repository=https://repo-default.voidlinux.org/current -M -R --property=pkgver hello" then
        return { success = true, stdout = 'hello-2.12_1\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --repository=https://repo-default.voidlinux.org/current -M -R --property=short_desc hello" then
        return { success = true, stdout = 'GNU Hello\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --repository=https://repo-default.voidlinux.org/current -M -R --property=homepage hello" then
        return { success = true, stdout = 'https://www.gnu.org/software/hello/\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --repository=https://repo-default.voidlinux.org/current -M -R --property=license hello" then
        return { success = true, stdout = 'GPL-3.0-or-later\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --repository=https://repo-default.voidlinux.org/current -M -R --property=repository hello" then
        return { success = true, stdout = 'https://repo-default.voidlinux.org/current\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --repository=https://repo-default.voidlinux.org/current -M -R --property=architecture hello" then
        return { success = true, stdout = 'x86_64\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --repository=https://repo-default.voidlinux.org/current -M -R -x hello" then
        return { success = true, stdout = 'glibc>=0\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --repository=https://repo-default.voidlinux.org/current -M -R --property=categories hello" then
        return { success = true, stdout = 'base-system\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --repository=https://repo-default.voidlinux.org/current -M -R --property=state hello" then
        return { success = false, stdout = '', stderr = '', exitCode = 1 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --repository=https://repo-default.voidlinux.org/current -M -R --property=automatic-install hello" then
        return { success = false, stdout = '', stderr = '', exitCode = 1 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --repository=https://repo-default.voidlinux.org/current -M -R --property=hold hello" then
        return { success = false, stdout = '', stderr = '', exitCode = 1 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --repository=https://repo-default.voidlinux.org/current -M -R --property=repolock hello" then
        return { success = false, stdout = '', stderr = '', exitCode = 1 }
      end
      return { success = false, stdout = '', stderr = 'unexpected: ' .. command, exitCode = 1 }
    end,
  },
}

local plugin = dofile('./run.lua')
local item = plugin.resolvePackage({
  request = {
    flags = {
      'cache-root=/tmp/opencode/xbps-extra',
      'repository=https://repo-default.voidlinux.org/current',
      'memory-sync',
    },
  },
  flags = {
    'cache-root=/tmp/opencode/xbps-extra',
    'repository=https://repo-default.voidlinux.org/current',
    'memory-sync',
  },
}, {
  name = 'hello',
  flags = {
    'cache-root=/tmp/opencode/xbps-extra',
    'repository=https://repo-default.voidlinux.org/current',
    'memory-sync',
  },
})

assert(item ~= nil, 'resolvePackage returned nil')
assert(item.name == 'hello', 'unexpected name')
assert(item.version == '2.12_1', 'unexpected version')
assert(item.homepage == 'https://www.gnu.org/software/hello/', 'unexpected homepage')

print('resolve-package-smoke ok')
