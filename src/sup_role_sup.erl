%% @author aku
%% @doc @todo Add description to sup_role_sup.


-module(sup_role_sup).
-behaviour(supervisor).

-include("records.hrl").

-export([init/1]).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start_link/0,start_link/1,start_child/2]).


%% ====================================================================
%% Behavioural functions 
%% ====================================================================
start_link() ->
	?MODULE:start_link(empty).
start_link(State) ->
   supervisor:start_link(?MODULE,State).


%% init/1
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/supervisor.html#Module:init-1">supervisor:init/1</a>
-spec init(Args :: term()) -> Result when
	Result :: {ok, {SupervisionPolicy, [ChildSpec]}} | ignore,
	SupervisionPolicy :: {RestartStrategy, MaxR :: non_neg_integer(), MaxT :: pos_integer()},
	RestartStrategy :: one_for_all
					 | one_for_one
					 | rest_for_one
					 | simple_one_for_one,
	ChildSpec :: {Id :: term(), StartFunc, RestartPolicy, Type :: worker | supervisor, Modules},
	StartFunc :: {M :: module(), F :: atom(), A :: [term()] | undefined},
	RestartPolicy :: permanent
				   | transient
				   | temporary,
	Modules :: [module()] | dynamic.
%% ====================================================================
init(_Args) ->
    AChild = {another_fake,{role_sup,start_link,[]},
	      permanent,infinity,supervisor,[role_sup]},
    {ok,{{simple_one_for_one,5,60}, [AChild]}}.

%% ====================================================================
%% Internal functions
%% ====================================================================
start_child(SRef,Args)->
  supervisor:start_child(SRef, [Args]).
	

