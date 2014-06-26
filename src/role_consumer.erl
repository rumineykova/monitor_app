-module(role_consumer).

-behaviour(gen_server).

-include("records.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").


-compile([{parse_transform, lager_transform}]).

-export([init/1, terminate/2, code_change/3, handle_call/3,
  handle_cast/2, handle_info/2]).
-export([start/1, start_link/1]).
-export([stop/1]).
-record(state, {channel,
  handler}).

%%--------------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------------

%% @spec (Connection, Queue, RpcHandler) -> RpcServer
%% where
%% Connection = pid()
%% Queue = binary()
%% RpcHandler = function()
%% RpcServer = pid()
%% @doc Starts a new RPC server instance that receives requests via a
%% specified queue and dispatches them to a specified handler function. This
%% function returns the pid of the RPC server that can be used to stop the
%% server.
start(Args) ->
  {ok, Pid} = gen_server:start(?MODULE, Args, []),
  Pid.

%% @spec (Connection, Queue, RpcHandler) -> RpcServer
%% where
%% Connection = pid()
%% Queue = binary()
%% RpcHandler = function()
%% RpcServer = pid()
%% @doc Starts, and links to, a new RPC server instance that receives
%% requests via a specified queue and dispatches them to a specified
%% handler function. This function returns the pid of the RPC server that
%% can be used to stop the server.
start_link(Args)->
  {ok, Pid} = gen_server:start_link(?MODULE,Args,[]),
  Pid.


%% @spec (RpcServer) -> ok
%% where
%% RpcServer = pid()
%% @doc Stops an exisiting RPC server.
stop(Pid) ->
  gen_server:call(Pid, stop, infinity).

%%--------------------------------------------------------------------------
%% gen_server callbacks
%%--------------------------------------------------------------------------



%% @private
init({Channel,Q,_Master}) ->
  lager:start(),
  %lager:info("[~p] consumer init",[self()]),
  rbbt_utils:subscribe(Channel, Q),
  {ok, {Channel,Q,_Master, none} }.


%% @private
handle_info(#'basic.consume_ok'{consumer_tag=NCt},  {Chn,Q,Master,_Ct}) ->
      lager:info("[~p] Consumer binded OK",[self()]),
      {noreply, {Chn, Q, Master, NCt}};
%% @private
handle_info(#'basic.cancel_ok'{consumer_tag = NCT}, State) ->
      lager:info("[~p] Consumer canceled",[self()]),
      {stop, normal, State};
handle_info({#'basic.deliver'{ consumer_tag=NCt, delivery_tag = Tag}, Content},  {Chn,Q,Master,_Ct}) ->
      #amqp_msg{payload = Payload} = Content,
      Dpld = bert:decode(Payload),

      ok = gen_server:cast(Master,Dpld),
      amqp_channel:cast(Chn, #'basic.ack'{delivery_tag = Tag}),
      {noreply, {Chn, Q, Master, NCt}};
%% @private
handle_info({'DOWN', _MRef, process, _Pid, _Info}, State) ->
  lager:info("[Consumer] Downd"),
  {noreply, State};
handle_info(Mse, State) ->
  lager:info("UNKONWN CONSUMER MESSAGE ~p ",[Mse]),
{noreply, State}.

%% @private
handle_call(stop, _From, State) ->
  lager:info("[Consumer] Shutdown called"),

  {stop, normal, ok, State}.

%%--------------------------------------------------------------------------
%% Rest of the gen_server callbacks
%%--------------------------------------------------------------------------

%% @private
handle_cast(_Message, State) ->
  {noreply, State}.


%% Closes the channel this gen_server instance started
%% @private
terminate(Reason,{Chn,_Q,_Master,none})->
  ok;
terminate(Reason,{Chn,_Q,_Master,Ct})->
  lager:info("[CONSUMER]terminating not none ~p",[Reason]),
  rbbt_utils:unsubscribe(Chn, Ct),
  receive
    #'basic.cancel_ok'{ consumer_tag = N} -> lager:info("[CONSUMER] cancel ok"), ok
  end.


%% @private
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.
