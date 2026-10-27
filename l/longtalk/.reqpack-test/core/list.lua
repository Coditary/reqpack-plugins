return {
  name = "longtalk list installed packs",
  request = {
    action = "list",
    system = "longtalk",
  },
  fakeExec = {
    {
      match = "command -v 'swilgt' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "forall(packs::pack_metadata(Registry,Pack,Version,metadata(Name,Description,License,Home,SourceURL,Checksum,Dependencies,Portability,Directory,Pinned,Installed,Loaded))",
      exitCode = 0,
      stdout = "REQPACK\tMETADATA\ttalkshow\tlflat\t2:1:0\tlflat\tL-FLAT package\tMIT\thttps://example.com/lflat\thttps://example.com/lflat-2.1.0.tar.gz\tsha256-test\t[]\tall\t/home/test/logtalk_packs/packs/talkshow/lflat\tfalse\ttrue\tfalse\nREQPACK\tMETADATA\ttalkshow\tfoo\t1:0:0\tfoo\tFoo package\tApache-2.0\thttps://example.com/foo\thttps://example.com/foo-1.0.0.tar.gz\tsha256-foo\t[bar]\tall\t/home/test/logtalk_packs/packs/talkshow/foo\ttrue\ttrue\ttrue\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "foo",
    resultVersion = "1:0:0",
  },
}
