return {
  name = "poetry list top level dependencies",
  request = {
    action = "list",
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
      match = "POETRY_CACHE_DIR='/home/test/.cache/reqpack/poetry/cache' POETRY_CONFIG_DIR='/home/test/.cache/reqpack/poetry/config' POETRY_DATA_DIR='/home/test/.cache/reqpack/poetry/data' poetry -C ./fixtures/project show --top-level --format json",
      exitCode = 0,
      stdout = [=[[{"name":"requests","version":"2.32.3","description":"Python HTTP for Humans.","installed_status":"installed"},{"name":"urllib3","version":"2.2.1","description":"HTTP library","installed_status":"installed"}]]=],
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
      "POETRY_CACHE_DIR='/home/test/.cache/reqpack/poetry/cache' POETRY_CONFIG_DIR='/home/test/.cache/reqpack/poetry/config' POETRY_DATA_DIR='/home/test/.cache/reqpack/poetry/data' poetry -C ./fixtures/project show --top-level --format json",
      "POETRY_CACHE_DIR='/home/test/.cache/reqpack/poetry/cache' POETRY_CONFIG_DIR='/home/test/.cache/reqpack/poetry/config' POETRY_DATA_DIR='/home/test/.cache/reqpack/poetry/data' poetry -C ./fixtures/project config cache-dir",
      "POETRY_CACHE_DIR='/home/test/.cache/reqpack/poetry/cache' POETRY_CONFIG_DIR='/home/test/.cache/reqpack/poetry/config' POETRY_DATA_DIR='/home/test/.cache/reqpack/poetry/data' poetry -C ./fixtures/project env info --path"
    },
    resultCount = 2,
    resultName = "requests",
    resultVersion = "2.32.3",
    events = { "listed" },
  },
}
