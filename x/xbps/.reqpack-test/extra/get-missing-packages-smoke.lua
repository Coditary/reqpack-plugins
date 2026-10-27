package.path = './?.lua;' .. package.path

reqpack = {
  exec = {
    run = function(command)
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=pkgver hello" then
        return { success = true, stdout = 'hello-2.12_1\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=short_desc hello" then
        return { success = true, stdout = 'GNU Hello\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=homepage hello" then
        return { success = true, stdout = 'https://www.gnu.org/software/hello/\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=license hello" then
        return { success = true, stdout = 'GPL-3.0-or-later\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=repository hello" then
        return { success = true, stdout = 'https://repo-default.voidlinux.org/current\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=architecture hello" then
        return { success = true, stdout = 'x86_64\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache -x hello" then
        return { success = true, stdout = 'glibc>=0\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=categories hello" then
        return { success = true, stdout = 'base-system\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=state hello" then
        return { success = true, stdout = 'installed\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=automatic-install hello" then
        return { success = true, stdout = 'no\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=hold hello" then
        return { success = true, stdout = 'no\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=repolock hello" then
        return { success = true, stdout = 'no\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache -R --property=pkgver hello" then
        return { success = true, stdout = 'hello-2.13_1\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache -R --property=short_desc hello" then
        return { success = true, stdout = 'GNU Hello\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache -R --property=homepage hello" then
        return { success = true, stdout = 'https://www.gnu.org/software/hello/\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache -R --property=license hello" then
        return { success = true, stdout = 'GPL-3.0-or-later\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache -R --property=repository hello" then
        return { success = true, stdout = 'https://repo-default.voidlinux.org/current\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache -R --property=architecture hello" then
        return { success = true, stdout = 'x86_64\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache -R -x hello" then
        return { success = true, stdout = 'glibc>=0\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache -R --property=categories hello" then
        return { success = true, stdout = 'base-system\n', stderr = '', exitCode = 0 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache -R --property=state hello" then
        return { success = false, stdout = '', stderr = '', exitCode = 1 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache -R --property=automatic-install hello" then
        return { success = false, stdout = '', stderr = '', exitCode = 1 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache -R --property=hold hello" then
        return { success = false, stdout = '', stderr = '', exitCode = 1 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache -R --property=repolock hello" then
        return { success = false, stdout = '', stderr = '', exitCode = 1 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=pkgver world" then
        return { success = false, stdout = '', stderr = 'not found', exitCode = 1 }
      end
      if command == "xbps-query -c /tmp/opencode/xbps-extra/cache --property=pkgver world" then
        return { success = false, stdout = '', stderr = 'not found', exitCode = 1 }
      end
      return { success = false, stdout = '', stderr = 'unexpected: ' .. command, exitCode = 1 }
    end,
  },
}

local plugin = dofile('./run.lua')
local missing = plugin.getMissingPackages({
  { name = 'hello', action = 'install', flags = { 'cache-root=/tmp/opencode/xbps-extra' } },
  { name = 'world', action = 'install', flags = { 'cache-root=/tmp/opencode/xbps-extra' } },
  { name = 'hello', action = 'update', flags = { 'cache-root=/tmp/opencode/xbps-extra' } },
  { name = 'hello', action = 'remove', flags = { 'cache-root=/tmp/opencode/xbps-extra' } },
})

assert(#missing == 3, 'unexpected missing count')
assert(missing[1].name == 'world', 'expected world missing for install')
assert(missing[2].name == 'hello' and missing[2].action == 'update', 'expected hello missing for update')
assert(missing[3].name == 'hello' and missing[3].action == 'remove', 'expected hello missing for remove')

print('get-missing-packages-smoke ok')
