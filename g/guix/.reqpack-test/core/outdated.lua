return {
  name = "guix outdated compares installed against show",
  request = {
    action = "outdated",
    system = "guix",
  },
  fakeExec = {
    {
      match = "command -v 'guix' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' guix package --profile='/home/test/.cache/reqpack/guix/profile' --list-installed",
      exitCode = 0,
      stdout = "hello\t2.12.1\tout\t/gnu/store/abc-hello-2.12.1\ncoreutils\t9.4\tout\t/gnu/store/ghi-coreutils-9.4\n",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' guix package --show='hello'",
      exitCode = 0,
      stdout = "name: hello\nversion: 2.12.2\noutputs: out debug\nsystems: x86_64-linux\nlocation: gnu/packages/base.scm:1:1\nhomepage: https://www.gnu.org/software/hello/\nlicense: GPL 3+\nsynopsis: Hello package\ndescription: GNU Hello package\n+ with multiline detail\n\n",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' guix package --show='coreutils'",
      exitCode = 1,
      stdout = "",
      stderr = "query failed\n",
      success = false,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "hello",
    resultVersion = "2.12.1",
  },
}
