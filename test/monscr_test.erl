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
    lager:start(),
  ifdelete(),

  {ok, Mn} = monscr:start_link([]),
	?assertEqual(true, is_pid(Mn)),
  cleanup(Mn),
  ifdelete().


register_test()->
  ifdelete(),
  {ok, Mn} = monscr:start_link([]),
  ?assertEqual(true, is_pid(Mn) ),
  {registered, Id} = monscr:register(Mn, self()),
  ?assertEqual(3, Id),

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

  {registered, Id} = monscr:register(Mn, NRefOrg),
  ?assertEqual(3, Id),



  Role1 = {{Id, 1}, bid_seaby, client, [sebay], [{response_item,response_item},
                                                 {lower,lower},
                                                 {accept, accept},
                                                 {send_update, send_update}]},
  Roles= [Role1],
  Pr = {NRefOrg, Roles },


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
