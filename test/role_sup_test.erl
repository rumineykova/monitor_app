%% @author aku
%% @doc @todo Add description to role_sup_test.


-module(role_sup_test).
-include_lib("eunit/include/eunit.hrl").

%% ====================================================================
%% API functions
%% ====================================================================

%% ====================================================================
%% Internal functions
%% ====================================================================

start_test() ->
  {ok,Rs} = role_sup:start_link(),
  ?assertEqual(true,is_pid(Rs)),
  cleanup(Rs).

child_test() ->
  NRefOrg = spawn(test_utils, aux_method_org, [self()]),

  {ok,Rs} = role_sup:start_link(),

  Spec = data_utils:spec_create(bid_sebay, client, [sebay], NRefOrg, [], undef, undef),
  Args = data_utils:role_data_create({3,1},Spec, none, none),

  role_sup:start_child(Rs,{"../resources/", Args}),

  ?assertEqual(true,is_pid(Rs)),
  cleanup(Rs),
  NRefOrg ! exit.



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
    end.
