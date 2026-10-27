return {
  name = "poetry outdated top level dependencies",
  request = {
    action = "outdated",
    system = "poetry",
    flags = { "dir=./fixtures/project" },
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
      match = "POETRY_CACHE_DIR='/home/test/.cache/reqpack/poetry/cache' POETRY_CONFIG_DIR='/home/test/.cache/reqpack/poetry/config' POETRY_DATA_DIR='/home/test/.cache/reqpack/poetry/data' poetry -C ./fixtures/project show --top-level --format json --latest --outdated",
      exitCode = 0,
      stdout = [=[[{"name":"requests","version":"2.31.0","latest_version":"2.32.3","description":"Python HTTP for Humans.","installed_status":"installed"}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "POETRY_CACHE_DIR='/home/test/.cache/reqpack/poetry/cache' POETRY_CONFIG_DIR='/home/test/.cache/reqpack/poetry/config' POETRY_DATA_DIR='/home/test/.cache/reqpack/poetry/data' poetry -C ./fixtures/project config cache-dir",
      exitCode = 0,
      stdout = "/home/test/.cache/pypoetry\n",
      stderr = "",
      success = true,
    },
    {
      match = "POETRY_CACHE_DIR='/home/test/.cache/reqpack/poetry/cache' POETRY_CONFIG_DIR='/home/test/.cache/reqpack/poetry/config' POETRY_DATA_DIR='/home/test/.cache/reqpack/poetry/data' poetry -C ./fixtures/project env info --path",
      exitCode = 0,
      stdout = "/workspace/.venv\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "POETRY_CACHE_DIR='/home/test/.cache/reqpack/poetry/cache' POETRY_CONFIG_DIR='/home/test/.cache/reqpack/poetry/config' POETRY_DATA_DIR='/home/test/.cache/reqpack/poetry/data' poetry -C ./fixtures/project show --top-level --format json --latest --outdated",
      "POETRY_CACHE_DIR='/home/test/.cache/reqpack/poetry/cache' POETRY_CONFIG_DIR='/home/test/.cache/reqpack/poetry/config' POETRY_DATA_DIR='/home/test/.cache/reqpack/poetry/data' poetry -C ./fixtures/project config cache-dir",
      "POETRY_CACHE_DIR='/home/test/.cache/reqpack/poetry/cache' POETRY_CONFIG_DIR='/home/test/.cache/reqpack/poetry/config' POETRY_DATA_DIR='/home/test/.cache/reqpack/poetry/data' poetry -C ./fixtures/project env info --path"
    },
    resultCount = 1,
    resultName = "requests",
    resultVersion = "2.31.0",
    events = { "outdated" },
  },
}
