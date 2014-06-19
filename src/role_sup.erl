%% @author aku
%% @doc @todo Add description to role_sup.


-module(role_sup).
-behaviour(supervisor).

-include("records.hrl").

-export([init/1]).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start_child/2,start_link/0,start_link/1]).



%% ====================================================================
%% Behavioural functions 
%% ====================================================================
start_link()->
	start_link(empty).
start_link(Args)->
   supervisor:start_link(?MODULE,Args).
	

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
init(_Argss) ->
    AChild = {fake_id,{role,start_link,[]},
      transient,infinity,worker,[role]},
    {ok,{{simple_one_for_one,5,60}, [AChild]}}.

%% ====================================================================
%% Internal functions
%% ====================================================================
start_child(SRef, Args)->
  supervisor:start_child(SRef, [Args]).





