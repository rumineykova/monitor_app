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

-compile([{parse_transform, lager_transform}]).

-define(PATH, "../resources/").

simple_recovery_test() ->

  db_utils:ets_create(child,  [set, named_table, public, {keypos,1}, {write_concurrency,false}, {read_concurrency,true}]),

  NRefOrg = spawn_link(test_utils, aux_method_org, [self()]),

  {ok,Rs} = role_sup:start_link(),
  ?assertEqual(true,is_pid(Rs)),

  Spec = data_utils:spec_create(bid_sebay, client, [], NRefOrg, [], undef, undef),
  Args = data_utils:role_data_create(Spec, none, none),

  role_sup:start_child(Rs,{?PATH, Args}),

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

  NRefOrg = spawn_link(test_utils, aux_method_org, [self()]),
  NRefOrg2 = spawn_link(test_utils, aux_method_org, [self()]),

  db_utils:install(node(), "db/"),

  {ok,Rs} = role_sup:start_link(),
  ?assertEqual(true,is_pid(Rs)),

  Spec = data_utils:spec_create(bid_cl, sb, [cl], NRefOrg, [], undef, undef),
  Args = data_utils:role_data_create(Spec, none, none),

  Spec2 = data_utils:spec_create(bid_cl, cl, [sb], NRefOrg2, [], undef, undef),
  Args2 = data_utils:role_data_create(Spec2, none, none),

  role_sup:start_child(Rs,{?PATH, Args}),
  role_sup:start_child(Rs,{?PATH, Args2}),

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

  %% wait to restart befor check pid again
  PidR = db_utils:ets_lookup_child_pid({bid_cl, sb}),
  ?assertEqual(true, is_pid(PidR)),

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