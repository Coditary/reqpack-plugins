return {
  name = "logtalk list installed packs",
  request = {
    action = "list",
    system = "logtalk",
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
      match = [=[LOGTALKPACKS='/home/test/.reqpack-data/logtalk/logtalk_packs' 'swilgt' -q -g 'set_logtalk_flag(report,off),logtalk_load(packs(loader)),forall(packs::pack_metadata(R,P,V,metadata(_,D,L,H,S,_,_,_,Dir,Pinned,true,Loaded)),(V=A:B:C,format('\''REQPACK|^|~w|^|~w|^|~d.~d.~d|^|~w|^|~w|^|~w|^|~w|^|~w|^|~w~n'\'',[R,P,A,B,C,D,L,H,S,Dir,Pinned,Loaded])))' -t halt]=],
      exitCode = 0,
      stdout = "REQPACK|^|talkshow|^|lflat|^|2.1.0|^|L-FLAT|^|MIT|^|https://github.com/l-flat/lflat|^|https://github.com/l-flat/lflat/archive/refs/tags/v2.1.0.tar.gz|^|/home/test/.reqpack-data/logtalk/logtalk_packs/packs/lflat|^|false|^|true\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "lflat",
    resultVersion = "2.1.0",
  }
}
