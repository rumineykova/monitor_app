%% @author aku
%% @doc @todo Add description to monscr_test.


-module(monscr_test).
-include_lib("eunit/include/eunit.hrl").
-compile([{parse_transform, lager_transform}]).


%% ====================================================================
%% API functions
%% ====================================================================

%% ====================================================================
%% Internal functions
%% ====================================================================


start_test() ->

  ifdelete(),

  {ok, Mn} = monscr:start_link([]),
	?assertEqual(true, is_pid(Mn)),
  cleanup(Mn),
  ifdelete().


register_test()->
  ifdelete(),
  {ok, Mn} = monscr:start_link([]),
  ?assertEqual(true, is_pid(Mn) ),
  {ok,Res} = monscr:register(self()),
  ?assertEqual(conf_done, Res),

  cleanup(Mn),
  ifdelete().

config_test() ->

  ifdelete(),
  db_utils:install(node(),"db"),

  case file:make_dir("resources/") of
    ok -> ok;
    {error, eexist} -> ok
  end,
  NRefOrg = spawn(test_utils, aux_method_org, [self()]),

  {ok, Mn} = monscr:start_link([]),

  {ok, Res} = monscr:register(Mn, NRefOrg),
  ?assertEqual(conf_done, Res),

  Pr = {NRefOrg,{ [{bid_sebay,client,[sebay]}],
    [{bid_sebay,client,response_item,response_item},
      {bid_sebay,client,lower,lower},
      {bid_sebay,client,accept,accept},
      {bid_sebay,client,send_update,send_update}
    ] }},

  M = monscr:config_protocol(Mn,Pr),
  ?assertEqual(ok, M),

  R = receive
        {config_done, P} -> P
  end,
  lager:info("~p",[R]),

  NRefOrg ! exit,

  cleanup(Mn),
  ifdelete().

cleanup(Pid) ->
  %This will kill supervisor and childs
  unlink(Pid),
  monscr:stop(Pid),
  Ref = monitor(process, Pid),
  receive
    {'DOWN', Ref, process, Pid, _Reason} ->
      ok
  after 1000 ->
    error(exit_timeout)
  end.



ifdelete()->
  case ets:info(child) of
    undefined -> ok;
    _ ->   lager:info("~p",[ets:info(child)])
  end.
