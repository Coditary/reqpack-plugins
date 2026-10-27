return {
  name = "uv install local tool",
  request = {
    action = "install",
    system = "uv",
    localPath = "/tmp/pkg",
    flags = { "editable" },
  },
  fakeExec = {
    {
      match = "command -v 'uv' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "UV_CACHE_DIR='/home/test/.cache/reqpack/uv/cache' UV_TOOL_DIR='/home/test/.cache/reqpack/uv/tools' UV_TOOL_BIN_DIR='/home/test/.cache/reqpack/uv/bin' UV_NO_PROGRESS='1' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' uv tool install --editable /tmp/pkg",
      exitCode = 0,
      stdout = "Installed 1 executable: pkg\n",
      stderr = "",
      success = true,
    },
    {
      match = "ls -1A '/home/test/.cache/reqpack/uv/tools'",
      exitCode = 1,
      stdout = "",
      stderr = "missing\n",
      success = false,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'uv' >/dev/null 2>&1",
      "UV_CACHE_DIR='/home/test/.cache/reqpack/uv/cache' UV_TOOL_DIR='/home/test/.cache/reqpack/uv/tools' UV_TOOL_BIN_DIR='/home/test/.cache/reqpack/uv/bin' UV_NO_PROGRESS='1' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' uv tool install --editable /tmp/pkg",
      "ls -1A '/home/test/.cache/reqpack/uv/tools'"
    },
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{localTarget=true, path=/tmp/pkg}",
      success = "ok",
    },
  }
}
