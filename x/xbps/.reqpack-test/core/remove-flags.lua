return {
  name = "xbps remove with explicit recursive flags",
  request = {
    action = "remove",
    system = "xbps",
    flags = {
      "cache-root=/tmp/xbps-cache",
      "rootdir=/tmp/rootfs",
      "config=/etc/xbps.d",
      "recursive",
      "force-remove",
      "force-revdeps",
    },
    packages = {
      { name = "hello" }
    },
  },
  fakeExec = {
    { match = "command -v xbps-install >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "command -v xbps-remove >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "command -v xbps-query >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "command -v xbps-rindex >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "xbps-remove -y -c /tmp/xbps-cache/cache -r /tmp/rootfs -C /etc/xbps.d -f -F -R hello", exitCode = 0, stdout = "Removed `hello'\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  }
}
