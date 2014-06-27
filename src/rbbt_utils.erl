%%%-------------------------------------------------------------------
%%% @author aku
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. Jun 2014 23:33
%%%-------------------------------------------------------------------
-module(rbbt_utils).
-author("aku").

-include("records.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").
%% API
-export([declare_exc/4, declare_q/2, bind_q_to_exc/4, publish_msg/3, publish_msg/4,
         bind_to_global_exchange/3, subscribe/2, unsubscribe/2,
         connect/3, open_channel/1,manual_recv/2, delete_q/2,delete_exc/2]).



connect(Host, User, Pwd) ->
  {ok, Connection} = amqp_connection:start(#amqp_params_network{username = User, password = Pwd, host=Host}),
  Connection.

open_channel(Con) ->
  {ok, Chn} = amqp_connection:open_channel(Con),
  Chn.

%%
%% Declarations
%% =======================================================================

declare_q(Chn,Name) when is_atom(Name) ->
  declare_q(Chn, atom_to_binary(Name, utf8));
declare_q(Chn, Name) when is_binary(Name)->
  #'queue.declare_ok'{queue = Q}
    = amqp_channel:call(Chn, #'queue.declare'{queue=Name, auto_delete=true}),
  Q.


declare_exc(Chn, Name, Type, Delete) when is_atom(Name)->
  declare_exc(Chn, atom_to_binary(Name, utf8), Type, Delete);
declare_exc(Chn, Name, Type, Delete) when is_binary(Name)->
  EDeclare = #'exchange.declare'{exchange = Name,
      type = Type,
      auto_delete=Delete},

  #'exchange.declare_ok'{} = amqp_channel:call(Chn, EDeclare).



%%
%% Bindings
%% =================================================================

bind_q_to_exc(Queue, Exchange, Rkey, Chn) when is_atom(Exchange), is_atom(Rkey)->
  bind_q_to_exc(Queue, atom_to_binary(Exchange,utf8), atom_to_binary(Rkey, utf8), Chn);
bind_q_to_exc(Queue, Exchange, Rkey, Chn) when is_atom(Exchange), is_binary(Rkey)->
  bind_q_to_exc(Queue, atom_to_binary(Exchange,utf8), Rkey, Chn);
bind_q_to_exc(Queue, Exchange, Rkey, Chn) when is_binary(Exchange), is_atom(Rkey)->
  bind_q_to_exc(Queue, Exchange, atom_to_binary(Rkey, utf8), Chn);
bind_q_to_exc(Queue, Exchange, Rkey, Chn) when is_binary(Exchange), is_binary(Rkey)->
  Binding = #'queue.bind'{queue = Queue,
    exchange    = Exchange,
    routing_key = Rkey},

  #'queue.bind_ok'{} = amqp_channel:call(Chn,
    Binding).





%% bind_to_protocol_exchange/3
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:code_change-3">gen_server:code_change/3</a>
-spec bind_to_global_exchange(Protocol :: term(), Channel :: term(), Role :: term()) -> Result when
  Result :: atom().
%% ====================================================================
bind_to_global_exchange(Protocol,Channel,Queue_name) when is_binary(Protocol), is_atom(Queue_name) ->
  bind_to_global_exchange(Protocol,Channel, atom_to_binary(Queue_name,utf8));
bind_to_global_exchange(Protocol,Channel,Queue_name) when is_atom(Protocol), is_binary(Queue_name) ->
  bind_to_global_exchange(atom_to_binary(Protocol,utf8),Channel, Queue_name);
bind_to_global_exchange(Protocol,Channel,Queue_name) when is_atom(Protocol), is_atom(Queue_name) ->
  bind_to_global_exchange(atom_to_binary(Protocol,utf8),Channel, atom_to_binary(Queue_name,utf8));
bind_to_global_exchange(Protocol,Channel,Queue_name) when is_binary(Protocol), is_binary(Queue_name) ->

  EDeclare = #'exchange.declare'{exchange = Protocol, type = <<"fanout">>},
  #'exchange.declare_ok'{} = amqp_channel:call(Channel, EDeclare),

  #'queue.declare_ok'{queue = Q}
    = amqp_channel:call(Channel, #'queue.declare'{queue=Queue_name,auto_delete=true}),
  Binding = #'queue.bind'{queue       = Q,
    exchange    = Protocol},

  #'queue.bind_ok'{} = amqp_channel:call(Channel, Binding),
  Q.



%%
%% Messgae publishing
%% =================================================================


%% publish_msg/3
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:code_change-3">gen_server:code_change/3</a>
-spec publish_msg(Channel :: term(), Exchange :: term(), Message :: term()) -> Result when
  Result :: term().
%% ====================================================================
publish_msg(Chn,Exc, Msg) ->
  publish_msg(Chn, Exc, '_', Msg).


%% publish_msg/3
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:code_change-3">gen_server:code_change/3</a>
-spec publish_msg(Channel :: term(), Exchange , RoutingKey, Message :: term()) -> Result when
  RoutingKey :: atom() | binary(),
  Exchange  :: atom() | binary(),
  Result :: term().
%% ====================================================================
publish_msg(Chn, Exc, Rkey, Msg) when is_atom(Exc), is_atom(Rkey)->
  publish_msg(Chn, atom_to_binary(Exc,utf8), atom_to_binary(Rkey,utf8), Msg);
publish_msg(Chn, Exc, Rkey, Msg) when is_binary(Exc), is_atom(Rkey)->
  publish_msg(Chn, Exc, atom_to_binary(Rkey, utf8), Msg);
publish_msg(Chn, Exc, Rkey, Msg) when is_atom(Exc), is_binary(Rkey)->
  publish_msg(Chn, atom_to_binary(Exc,utf8), Rkey, Msg);
publish_msg(Chn, Exc, Rkey, Msg) when is_binary(Exc), is_binary(Rkey)->
  Publish = #'basic.publish'{exchange = Exc,
                             routing_key=Rkey},

  amqp_channel:cast(Chn,
                    Publish,
                    #amqp_msg{payload = bert:encode(Msg)}).



manual_recv(Channel, Queue)->
  Get = #'basic.get'{queue = Queue, no_ack = true},
  {#'basic.get_ok'{}, Content} = amqp_channel:call(Channel, Get),
  #amqp_msg{payload = Payload} = Content,
  bert:decode(Payload).



delete_exc(Channel, Exchange) when is_atom(Exchange) ->
  delete_exc(Channel, atom_to_binary(Exchange,utf8));
delete_exc(Channel, Exchange) when is_binary( Exchange) ->
  Delete = #'exchange.delete'{exchange = Exchange},
  #'exchange.delete_ok'{} = amqp_channel:call(Channel, Delete).

delete_q(Channel, Queue) when is_atom(Queue)->
  delete_q(Channel, atom_to_binary(Queue,utf8));
delete_q(Channel, Queue) when is_binary(Queue)->
  Delete = #'queue.delete'{queue = Queue},
  #'queue.delete_ok'{} = amqp_channel:call(Channel, Delete).

%%
%% Subscribing publishing
%% =================================================================

subscribe(Chn, Q) ->
  amqp_channel:subscribe(Chn, #'basic.consume'{queue = Q}, self()).

unsubscribe(Chn,Ct) ->
  amqp_channel:call(Chn,#'basic.cancel'{consumer_tag=Ct}).
