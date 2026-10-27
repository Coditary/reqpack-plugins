return {
  name = "logtalk search packs",
  request = {
    action = "search",
    system = "logtalk",
    prompt = "flat",
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
      match = [=[LOGTALKPACKS='/home/test/.reqpack-data/logtalk/logtalk_packs' 'swilgt' -q -g 'set_logtalk_flag(report,off),logtalk_load(packs(loader)),forall((registries::provides(R,P),packs::pack_object(R,P,O),((sub_atom(P,_,_,_,'\''flat'\''));(O::description(D0),sub_atom(D0,_,_,_,'\''flat'\''))),once(O::version(V,Status,_,_,_,_)),(O::description(D)->true;D=none),(O::license(L)->true;L=none),(O::home(H)->true;H=none)),(V=A:B:C,format('\''REQPACK|^|~w|^|~w|^|~d.~d.~d|^|~w|^|~w|^|~w|^|~w~n'\'',[R,P,A,B,C,Status,D,L,H])))' -t halt]=],
      exitCode = 0,
      stdout = "REQPACK|^|talkshow|^|lflat|^|2.1.0|^|stable|^|L-FLAT|^|MIT|^|https://github.com/l-flat/lflat\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "lflat",
    resultVersion = "2.1.0",
  }
}
