return {
  name = "microdnf install local rpm",
  request = {
    action = "install",
    system = "microdnf",
    localPath = "/tmp/curl.rpm",
  },
  fakeExec = {
    {
      match = "command -v 'microdnf' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/home/test/.cache/reqpack/microdnf'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "microdnf --setopt=cachedir='/home/test/.cache/reqpack/microdnf' makecache",
      exitCode = 0,
      stdout = "Metadata cache created.\n",
      stderr = "",
      success = true,
    },
    {
      match = "microdnf --setopt=cachedir='/home/test/.cache/reqpack/microdnf' -y install '/tmp/curl.rpm'",
      exitCode = 0,
      stdout = "Complete!\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    commands = {
      "mkdir -p '/home/test/.cache/reqpack/microdnf'",
      "microdnf --setopt=cachedir='/home/test/.cache/reqpack/microdnf' makecache",
      "microdnf --setopt=cachedir='/home/test/.cache/reqpack/microdnf' -y install '/tmp/curl.rpm'"
    },
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{localTarget=true, path=/tmp/curl.rpm}",
      success = "ok",
    },
  }
}
