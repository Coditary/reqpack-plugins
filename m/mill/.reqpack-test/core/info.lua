return {
  name = "mill info installed version",
  request = {
    action = "info",
    system = "mill",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
    },
    prompt = "mill@1.0.4",
  },
  fixtureDirs = {
    "${fixtureRoot}/.reqpack-data/mill/records",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/.reqpack-data/mill/records/mill_1_0_4.tsv",
      content = "id\tmill@1.0.4\nname\tmill\nversion\t1.0.4\nlauncherPath\t${fixtureRoot}/.reqpack-data/mill/bin/mill-1.0.4\ndownloadPath\t${fixtureRoot}/.reqpack-cache/mill/downloads/mill-1.0.4.sh\nhomepage\thttps://mill-build.org/\nupdatedAt\t0\n",
    },
    {
      path = "${fixtureRoot}/.reqpack-cache/mill/maven-metadata.xml",
      content = "<metadata><versioning><latest>1.0.4</latest><release>1.0.4</release><versions><version>0.12.11</version><version>1.0.4</version></versions></versioning></metadata>",
    },
  },
  fakeExec = {
    {
      match = "mkdir -p '${fixtureRoot}/.reqpack-data/mill/bin'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/.reqpack-data/mill/records'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/.reqpack-cache/mill/downloads'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/.reqpack-cache/mill/user-cache'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/.reqpack-cache/mill/coursier'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/.reqpack-cache/mill/coursier-jvm'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/.reqpack-data/mill/home'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/.reqpack-cache/mill/xdg-cache'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/.reqpack-config/mill/xdg-config'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/.reqpack-data/mill/xdg-data'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://repo1.maven.org/maven2/com/lihaoyi/mill-dist/maven-metadata.xml' -o '${fixtureRoot}/.reqpack-cache/mill/maven-metadata.xml'",
      exitCode = 0,
      stdout = "<metadata><versioning><latest>1.0.4</latest><release>1.0.4</release><versions><version>0.12.11</version><version>1.0.4</version></versions></versioning></metadata>",
      stderr = "",
      success = true,
    },
    {
      match = "ls -1A '${fixtureRoot}/.reqpack-data/mill/records'",
      exitCode = 0,
      stdout = "mill_1_0_4.tsv\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultName = "mill",
    resultVersion = "1.0.4",
  }
}
