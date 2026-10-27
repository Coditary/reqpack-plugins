return {
  name = "guix search parses recutils output",
  request = {
    action = "search",
    system = "guix",
    prompt = "hello",
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
      match = "NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' guix package --search 'hello'",
      exitCode = 0,
      stdout = "name: hello\nversion: 2.12.2\noutputs: out debug\nsystems: x86_64-linux\nlocation: gnu/packages/base.scm:1:1\nhomepage: https://www.gnu.org/software/hello/\nlicense: GPL 3+\nsynopsis: Hello package\ndescription: GNU Hello package\n+ with multiline detail\n\nname: hello-next\nversion: 3.0\noutputs: out\nsystems: x86_64-linux\nlocation: gnu/packages/base.scm:9:9\nhomepage: https://example.test/hello-next\nlicense: GPL 3+\nsynopsis: Next hello\ndescription: Next hello desc\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "hello",
    resultVersion = "2.12.2",
  },
}
