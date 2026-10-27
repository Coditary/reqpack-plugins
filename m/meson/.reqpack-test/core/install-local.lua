return {
  name = "meson install local wrap file",
  request = {
    action = "installLocal",
    system = "meson",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
    },
    localPath = "${fixtureRoot}/downloads/libgee.wrap",
  },
  fixtureDirs = {
    "downloads",
  },
  fixtureFiles = {
    {
      path = "downloads/libgee.wrap",
      content = "[wrap-file]\ndirectory = libgee-0.20.6\nsource_url = https://example.test/libgee-0.20.6.tar.xz\nsource_filename = libgee-0.20.6.tar.xz\nsource_hash = deadbeef\n\n[provide]\ndependency_names = gee-0.8\n",
    },
  },
  fakeExec = {
    { match = "test -d '${fixtureRoot}/downloads/libgee.wrap'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -f '${fixtureRoot}/downloads/libgee.wrap'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/downloads/libgee.wrap'", exitCode = 0, stdout = "[wrap-file]\ndirectory = libgee-0.20.6\nsource_url = https://example.test/libgee-0.20.6.tar.xz\nsource_filename = libgee-0.20.6.tar.xz\nsource_hash = deadbeef\n\n[provide]\ndependency_names = gee-0.8\n", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/meson/home' '${fixtureRoot}/.reqpack-data/meson/workspace' '${fixtureRoot}/.reqpack-data/meson/workspace/subprojects' '${fixtureRoot}/.reqpack-data/meson' '${fixtureRoot}/.reqpack-cache/meson/package-cache' '${fixtureRoot}/.reqpack-cache/meson/xdg-cache' '${fixtureRoot}/.reqpack-config/meson/xdg-config' '${fixtureRoot}/.reqpack-data/meson/xdg-data'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = [=[test -f '${fixtureRoot}/.reqpack-data/meson/workspace/meson.build' || printf %s 'project('\''reqpack-meson-workspace'\'')
' > '${fixtureRoot}/.reqpack-data/meson/workspace/meson.build']=], exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cp '${fixtureRoot}/downloads/libgee.wrap' '${fixtureRoot}/.reqpack-data/meson/workspace/subprojects/libgee.wrap'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    result = true,
  },
}
