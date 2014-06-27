%%%-------------------------------------------------------------------
%%% @author aku
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 26. Jun 2014 22:54
%%%-------------------------------------------------------------------
-module(recovery_test).
-author("aku").

-include_lib("eunit/include/eunit.hrl").
-export([aux_method_org/1]).
-compile([{parse_transform, lager_transform}]).

simple_recovery_test() ->

  lager:start(),
  db_utils:ets_create(child,  [set, named_table, public, {keypos,1}, {write_concurrency,false}, {read_concurrency,true}]),

  NRefOrg = spawn_link(?MODULE, aux_method_org, [self()]),

  {ok,Rs} = role_sup:start_link(),
  ?assertEqual(true,is_pid(Rs)),

  Spec = data_utils:spec_create(bid_sebay, client, [], NRefOrg, [], undef, undef),
  Args = data_utils:role_data_create(Spec, none, none),

  role_sup:start_child(Rs,{"../resources/", Args}),

  Pid = db_utils:ets_lookup_child_pid({bid_sebay, client}),
  ?assertEqual(true, is_pid(Pid)),

  role:crash(Pid),

  timer:sleep(1000),

  PidR = db_utils:ets_lookup_child_pid({bid_sebay, client}),
  ?assertEqual(true, is_pid(PidR)),
  timer:sleep(1000),

  cleanup(Rs).


complex_recovery_test() ->

  db_utils:ets_create(child,  [set, named_table, public, {keypos,1}, {write_concurrency,false}, {read_concurrency,true}]),

  NRefOrg = spawn_link(?MODULE, aux_method_org, [self()]),
  NRefOrg2 = spawn_link(?MODULE, aux_method_org, [self()]),

  db_utils:install(node(), "db/"),

  {ok,Rs} = role_sup:start_link(),
  ?assertEqual(true,is_pid(Rs)),

  Spec = data_utils:spec_create(bid_cl, sb, [cl], NRefOrg, [], undef, undef),
  Args = data_utils:role_data_create(Spec, none, none),

  Spec2 = data_utils:spec_create(bid_cl, cl, [sb], NRefOrg2, [], undef, undef),
  Args2 = data_utils:role_data_create(Spec2, none, none),

  role_sup:start_child(Rs,{"../resources/", Args}),
  role_sup:start_child(Rs,{"../resources/", Args2}),

  Pid = db_utils:ets_lookup_child_pid({bid_cl, sb}),
  ?assertEqual(true, is_pid(Pid)),

  ok = role:create(Pid,bid_cl),

  timer:sleep(1000),

  %One ready per NRefOrg
  receive
    ready -> ok
  end,
  receive
    ready -> ok
  end,
  role:crash(Pid),

  %wait to restart befor check pid again
  PidR = db_utils:ets_lookup_raw(child, {bid_cl, sb}),
  %?assertEqual(true, is_pid(PidR)),

  timer:sleep(2000),
  NRefOrg ! exit,
  NRefOrg2 ! exit,
  cleanup(Rs).


cleanup(Pid) ->
  %This will kill supervisor and childs
  unlink(Pid),
  exit(Pid, shutdown),
  Ref = monitor(process, Pid),
  receive
    {'DOWN', Ref, process, Pid, _Reason} ->
      ok
  after 1000 ->
    error(exit_timeout)
  end,
  ets:delete(child).



aux_method_org(Args) ->
  receive
    {_,From,_} -> lager:info("[CLIENT]list"), gen_server:reply(From,{ok,[{response_item,2},{lower,2},{accept,2},{send_update,2},{ready,2},{terminated,2},{config_done,2},{cancel,2}]}),
      aux_method_org(Args);
    {'$gen_cast',{timeout}} -> lager:info("[CLIENT]timeout"), Args ! timeout,
      aux_method_org(Args);
    {'$gen_cast',{callback,ready,{ready}}} -> lager:info("[CLIENT]ready"), Args ! ready,
      aux_method_org(Args);
    {'$gen_cast',{callback,cancel,{cancel}}} -> lager:info("[CLIENT]ready"), Args ! cancel,
      aux_method_org(Args);
    {'$gen_cast',{callback, config_done,Reply}} ->lager:info("[CLIENT]config"), Args ! {config_done, Reply},
      aux_method_org(Args);

    {'$gen_cast',{callback,projection_request,{send, FileName, Host, Port}}} ->
      lager:warning("FileName ~p",[FileName]),
      {ok, Socket} = gen_tcp:connect(list_to_atom(Host), Port, [binary, {active, false}]),
      PathFile = "../test/test_resources/" ++ FileName,
      true = filelib:is_regular(PathFile),
      {ok, _} = file:sendfile(PathFile, Socket),
      ok = gen_tcp:close(Socket),
      aux_method_org(Args);
    exit -> lager:info("exit"), ok;
    M -> lager:info("unkown ~p",[M]), Args ! {error,M},
      aux_method_org(Args)

  end.
