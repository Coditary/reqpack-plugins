return {
  name = "poetry remove dependency",
  request = {
    action = "remove",
    system = "poetry",
    flags = { "dir=./fixtures/project" },
    packages = {
      { name = "requests" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'poetry' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "POETRY_CACHE_DIR='/home/test/.cache/reqpack/poetry/cache' POETRY_CONFIG_DIR='/home/test/.cache/reqpack/poetry/config' POETRY_DATA_DIR='/home/test/.cache/reqpack/poetry/data' poetry -C ./fixtures/project remove --no-interaction requests",
      exitCode = 0,
      stdout = "removed requests\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "POETRY_CACHE_DIR='/home/test/.cache/reqpack/poetry/cache' POETRY_CONFIG_DIR='/home/test/.cache/reqpack/poetry/config' POETRY_DATA_DIR='/home/test/.cache/reqpack/poetry/data' poetry -C ./fixtures/project remove --no-interaction requests"
    },
    events = { "deleted", "success" },
  },
}
