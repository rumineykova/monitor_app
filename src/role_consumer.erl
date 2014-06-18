-module(role_consumer).

-include("records.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

-compile([{parse_transform, lager_transform}]).

-export([start_link/1,init/1]).

start_link(Args)->
	spawn_link(?MODULE,init,[Args]).


init({Channel,Q,Master}) ->
    lager:info("[~p] consumer init",[self()]),
    rbbt_utils:subscribe(Channel, Q),
    main_loop(Channel,Q,Master,none).



main_loop(Chn,Q,Master,Ct) ->
	receive
		#'basic.consume_ok'{consumer_tag=NCt} ->
      lager:info("[~p] Consumer binded OK",[self()]),
      main_loop(Chn,Q,Master,NCt);
		#'basic.cancel_ok'{} ->
      lager:info("[~p] Consumer canceled",[self()]),
      ok;
		{#'basic.deliver'{ consumer_tag=NCt, delivery_tag = Tag}, Content} ->

      #amqp_msg{payload = Payload} = Content,

      Dpld = bert:decode(Payload),

      ok = gen_server:cast(Master,Dpld),
			amqp_channel:cast(Chn, #'basic.ack'{delivery_tag = Tag}),
      main_loop(Chn, Q, Master,NCt);
		
		exit ->
      rbbt_utils:unsubscribe(Chn, Ct),
      lager:error("[~p] Consumer cancel rcvd",[self()]),
      main_loop(Chn,Q,Master,Ct)
	end.
