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
	?assertEqual(true,is_pid(Rs)).

child_test() ->
  {ok,Rs} = role_sup:start_link(),

  %% -record(role_data,{spec, conn, exc}).
  Spec = data_utils:spec_create(bid_sebay, client, [sebay], undef, self(), [], undef, undef),
  %Conn = data_utils:conn_create(none),
  Args = data_utils:role_data_create(Spec, none, none),

  role_sup:start_child(Rs,Args),

  ?assertEqual(true,is_pid(Rs)).