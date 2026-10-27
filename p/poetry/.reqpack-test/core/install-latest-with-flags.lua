return {
  name = "poetry install latest with add selectors",
  request = {
    action = "install",
    system = "poetry",
    flags = { "dir=./fixtures/project" },
    packages = {
      {
        name = "requests[socks]",
        version = "latest",
        flags = {
          "latest",
          "group=docs",
          "extras=socks",
          "allow-prereleases",
        },
      }
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
      match = "POETRY_CACHE_DIR='/home/test/.cache/reqpack/poetry/cache' POETRY_CONFIG_DIR='/home/test/.cache/reqpack/poetry/config' POETRY_DATA_DIR='/home/test/.cache/reqpack/poetry/data' poetry -C ./fixtures/project add --no-interaction --allow-prereleases --extras socks --group docs requests@latest",
      exitCode = 0,
      stdout = "installed latest requests\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "POETRY_CACHE_DIR='/home/test/.cache/reqpack/poetry/cache' POETRY_CONFIG_DIR='/home/test/.cache/reqpack/poetry/config' POETRY_DATA_DIR='/home/test/.cache/reqpack/poetry/data' poetry -C ./fixtures/project add --no-interaction --allow-prereleases --extras socks --group docs requests@latest"
    },
    events = { "installed", "success" },
  },
}
