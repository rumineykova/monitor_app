%% @author aku
%% @doc @todo Add description to sup_role_sup_test.


-module(sup_role_sup_test).
-include_lib("eunit/include/eunit.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([]).
-compile(export_all).


%% ====================================================================
%% Internal functions
%% ====================================================================



start_test() ->
	SRS = sup_role_sup:start_link(),
	ok.
