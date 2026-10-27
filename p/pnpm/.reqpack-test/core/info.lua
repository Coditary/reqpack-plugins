return {
  name = "pnpm view package info",
  request = {
    action = "info",
    system = "pnpm",
    prompt = "@types/is-number",
  },
  fakeExec = {
    {
      match = "command -v 'pnpm' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "pnpm view '@types/is-number' --json",
      exitCode = 0,
      stdout = [=[{
  "name": "@types/is-number",
  "version": "7.0.5",
  "description": "TypeScript definitions for is-number",
  "dist-tags": {
    "latest": "7.0.5"
  },
  "time": {
    "modified": "2025-08-03T07:01:31.731Z"
  },
  "homepage": "https://github.com/DefinitelyTyped/DefinitelyTyped/tree/master/types/is-number",
  "repository": {
    "url": "https://github.com/DefinitelyTyped/DefinitelyTyped.git",
    "type": "git",
    "directory": "types/is-number"
  },
  "license": "MIT",
  "dist": {
    "tarball": "https://registry.npmjs.org/@types/is-number/-/is-number-7.0.5.tgz",
    "integrity": "sha512-NGmRpXeZg9qDX+AlmBeq4Xk9ruTMj0KfzspDCxTLAcpbts2EjojAvY6A1eumKHInMwGY4xHM8ILA9CHRHfUUWA==",
    "shasum": "0e5942c2754661c25237f411fe6299523b04c818"
  },
  "keywords": ["types", "typescript", "number"]
}]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "pnpm view '@types/is-number' --json",
    },
    resultCount = 1,
    resultName = "@types/is-number",
    resultVersion = "7.0.5",
    events = { "informed" },
  },
}
