return {
  name = "poetry update selected dependency",
  request = {
    action = "update",
    system = "poetry",
    flags = { "dir=./fixtures/project", "with=docs" },
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
      match = "POETRY_CACHE_DIR='/home/test/.cache/reqpack/poetry/cache' POETRY_CONFIG_DIR='/home/test/.cache/reqpack/poetry/config' POETRY_DATA_DIR='/home/test/.cache/reqpack/poetry/data' poetry -C ./fixtures/project update --no-interaction --with docs requests",
      exitCode = 0,
      stdout = "updated requests\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "POETRY_CACHE_DIR='/home/test/.cache/reqpack/poetry/cache' POETRY_CONFIG_DIR='/home/test/.cache/reqpack/poetry/config' POETRY_DATA_DIR='/home/test/.cache/reqpack/poetry/data' poetry -C ./fixtures/project update --no-interaction --with docs requests"
    },
    events = { "updated", "success" },
  },
}
