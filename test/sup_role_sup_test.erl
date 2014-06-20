%% @author aku
%% @doc @todo Add description to sup_role_sup_test.


-module(sup_role_sup_test).
-include_lib("eunit/include/eunit.hrl").

%% ====================================================================
%% API functions
%% ====================================================================


%% ====================================================================
%% Internal functions
%% ====================================================================


start_test() ->
  {ok,SRS} = sup_role_sup:start_link(),
	?assertEqual(true,is_pid(SRS)).

child_test()->
  {ok,SRS} = sup_role_sup:start_link(),

  sup_role_sup:start_child(SRS,none),

  ?assertEqual(true,is_pid(SRS)).

