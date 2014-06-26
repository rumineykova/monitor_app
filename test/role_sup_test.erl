%% @author aku
%% @doc @todo Add description to role_sup_test.


-module(role_sup_test).
-include_lib("eunit/include/eunit.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([aux_method_org/1]).

%% ====================================================================
%% Internal functions
%% ====================================================================

start_test() ->
  {ok,Rs} = role_sup:start_link(),
  ?assertEqual(true,is_pid(Rs)),
  cleanup(Rs).

child_test() ->

  NRefOrg = spawn_link(?MODULE, aux_method_org, [self()]),

  {ok,Rs} = role_sup:start_link(),

  Spec = data_utils:spec_create(bid_sebay, client, [sebay], NRefOrg, [], undef, undef),
  Args = data_utils:role_data_create(Spec, none, none),

  role_sup:start_child(Rs,{"../resources/", Args}),

  ?assertEqual(true,is_pid(Rs)),
  cleanup(Rs).


aux_method_org(Args) ->
    receive
      {_,From,_} -> gen_server:reply(From,{ok,[{response_item,2},{lower,2},{accept,2},{send_update,2},{ready,2},{terminated,2},{config_done,2},{cancel,2}]}),
                    aux_method_org(Args);
      {'$gen_cast',{timeout}} -> Args ! ok,
                    aux_method_org(Args);
      {'$gen_cast',{callback,ready,{ready}}} -> Args ! ok,
                    aux_method_org(Args);
      _ -> error
    end.

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
