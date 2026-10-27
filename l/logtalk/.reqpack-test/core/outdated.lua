return {
  name = "logtalk list outdated packs",
  request = {
    action = "outdated",
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
      match = [=[LOGTALKPACKS='/home/test/.reqpack-data/logtalk/logtalk_packs' 'swilgt' -q -g 'set_logtalk_flag(report,off),logtalk_load(packs(loader)),(registries::defined(talkshow,_,_,_)->true;registries::add('\''https://github.com/LogtalkDotOrg/talkshow.git'\''))' -t halt]=],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = [=[LOGTALKPACKS='/home/test/.reqpack-data/logtalk/logtalk_packs' 'swilgt' -q -g 'set_logtalk_flag(report,off),logtalk_load(packs(loader)),forall((packs::outdated(R,P,Old,New,[]),packs::pack_object(R,P,O),(O::description(D)->true;D=none)),(Old=OA:OB:OC,New=NA:NB:NC,format('\''REQPACK|^|~w|^|~w|^|~d.~d.~d|^|~d.~d.~d|^|~w~n'\'',[R,P,OA,OB,OC,NA,NB,NC,D])))' -t halt]=],
      exitCode = 0,
      stdout = "REQPACK|^|talkshow|^|lflat|^|2.1.0|^|2.2.0|^|L-FLAT\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "lflat",
    resultVersion = "2.1.0",
  }
}
