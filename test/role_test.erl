%% @author aku
%% @doc @todo Add description to role_test.


-module(role_test).
-include("../include/records.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").
%% ====================================================================
%% API functions
%% ====================================================================
-export([]).
-compile(export_all).

-compile([{parse_transform, lager_transform}]).
%% ====================================================================
%% Internal functions
%% ====================================================================



%start_test()->
%	lager:start(),
%	
%	application:set_env(mnesia, dir, "../db/"),
%
%	    mnesia:create_schema([node()]),
%			lager:info("Schmea"),
%
%	application:start(mnesia),
%		lager:info("Mnesia [Started]"),
%	
%    Mesae = mnesia:create_table(prova, [
%                       {record_name,row}, 
%                        {attributes, record_info(fields, row)},
%                        {ram_copies, [node()]}]),
%			lager:info("table ~p",[Mesae]),
%
%    mnesia:wait_for_tables([prova], infinity),
%			lager:info("wait for atabl"),
%
%	lager:info("Mnesia create correctly"),
%
%
%	State = #role_data{ spec = #spec{protocol = test_protocol, role = seller, imp_ref = self(),funcs = []}},
%	_Role = role:start_link(State),
%	ok.
%
prot_iterator_test() ->
	lager:start(),
	
    %% OMG Massive error if the directdory does not exists or can't be reache, BAD_TYPE can't update!!!!!!
   %application:set_env(mnesia, dir, "../db/"),

	{ok,Data} = file:read_file("../resources/client.scr"),
	{ok,Final,_} = erl_scan:string(binary_to_list(Data),1,[{reserved_word_fun, fun mytokens/1}]),
	{ok,Scr} = scribble:parse(Final),

  db_utils:install(node()),
  case db_utils:get_table(prova) of
    {created, TbName} -> ok;
    {exists, TbName} -> ok;
    {error, Reason} -> lager:error("~p",[Reason])
  end,

	lager:info("Mnesia create correctly"),

  lager:info("~p",[Scr]),
  NML  = role:translate_parsed_to_mnesia(prova,Scr),
  lager:info("~p",[NML]),
	?assertMatch({ok,_N}, {ok,4} ).


mnesia_test()->
	mnesia:start(),
	List = mnesia:system_info(tables),
	
	?assertMatch({false},role:exist_table(test, List)).


mnesia_data_retrive_test() ->
	lager:start(),
	application:set_env(mnesia, dir, "../db/"),

	{ok,Data} = file:read_file("../resources/client.scr"),
	{ok,Final,_} = erl_scan:string(binary_to_list(Data),1,[{reserved_word_fun, fun role:mytokens/1}]),
	{ok,_Scr} = scribble:parse(Final),
	
    mnesia:create_schema([node()]),
			lager:info("Schmea"),

	application:start(mnesia),
		lager:info("Mnesia [Started]"),
	
    Mesae = mnesia:create_table(prova, [
                        {record_name,row},
                        {attributes, record_info(fields, row)},
                        {ram_copies, [node()]}]),
			lager:info("table ~p",[Mesae]),

    mnesia:wait_for_tables([prova], infinity),
			lager:info("wait for atabl"),

	lager:info("Mnesia create correctly"),
   
    M = mnesia:async_dirty(fun()-> qlc:e(mnesia:table(prova)) end),
    [Record] = mnesia:dirty_match_object(prova, #row{ num =0 , inst = '_'}),

    lager:info("[~p] Recovered record ~p", [self(),Record]),
    lager:info("[~p] Recovered record ~p", [self(),M]).
		

ping_pong_test()->
	 lager:start(),

    User = <<"test">>,
    Pwd = <<"test">>,

	{ok, Connection} = amqp_connection:start(#amqp_params_network{username=User, password=Pwd, host="stock"}),
	
	{ok, Chn1} = amqp_connection:open_channel(Connection),	
	{ok, Chn2} = amqp_connection:open_channel(Connection),

	Q1 = ping_pong_exchange(pex,Chn1,ping),
	Q2 = ping_pong_exchange(pex,Chn2,pong),

	spawn_link(?MODULE,pong,[Chn2,Q2]),
    ping(Chn1,Q1),

	amqp_channel:close(Chn2),
	amqp_channel:close(Chn1),

	%% Close the connection
	amqp_connection:close(Connection).





global_exchange_test()->

  lager:start(),

  User = <<"test">>,
  Pwd = <<"test">>,

	{ok, Connection} = amqp_connection:start(#amqp_params_network{username=User, password=Pwd, host="stock"}),
	
	{ok, Chn1} = amqp_connection:open_channel(Connection),	
	{ok, Chn2} = amqp_connection:open_channel(Connection),


	Q1 = rbbt_utils:bind_to_global_exchange(gex,Chn1,sender),
	Q2 = rbbt_utils:bind_to_global_exchange(gex,Chn2,receiver),

  amqp_channel:subscribe(Chn2, #'basic.consume'{queue = Q2}, self()),
  amqp_channel:subscribe(Chn1, #'basic.consume'{queue = Q1}, self()),

	Payload = <<"foobar">>,
	Exc = <<"gex">>,
	_Pong = <<"pong">>,
	
	Publish = #'basic.publish'{exchange = Exc},
	amqp_channel:cast(Chn1, Publish, #amqp_msg{payload = Payload}),

  loop(Chn2),
	
	amqp_channel:close(Chn1),
	amqp_channel:close(Chn2),
	%% Close the connection
	amqp_connection:close(Connection).


  %    #'basic.consume_ok'{} ->
	%		Get = #'basic.get'{queue = Q2, no_ack = true},
	%		{#'basic.get_ok'{}, Content} = amqp_channel:call(Chn2, Get),
    
	%lager:stop().


ping_pong_exchange(Protocol,Channel,Role)->

    
    Prot = atom_to_binary(Protocol,utf8),
	R = atom_to_binary(Role,utf8),

    EDeclare = #'exchange.declare'{exchange = Prot, type = <<"direct">>,auto_delete=true}, 
	#'exchange.declare_ok'{} = amqp_channel:call(Channel, EDeclare),

	
	
    Queue = atom_to_binary(Role,utf8),

	%% Declare a queue
	#'queue.declare_ok'{queue = Q}
		= amqp_channel:call(Channel, #'queue.declare'{queue=Queue,auto_delete=true}),	
	
	Binding = #'queue.bind'{queue       = Q,
							exchange    = Prot,
							routing_key = R},
	
    #'queue.bind_ok'{} = amqp_channel:call(Channel, Binding),
	lager:info("[AMQP] ~p binded to the ~p exchange done.~n",[Role,Protocol]),
	Q.



loop(Channel) ->
          receive
              #'basic.consume_ok'{} ->
                  loop(Channel);

              #'basic.cancel_ok'{} ->
                  ok;

              {#'basic.deliver'{delivery_tag = Tag}, Content} ->
				  #amqp_msg{payload = Payload} = Content,
				  lager:info("[AMQP] ~p~n",[Payload]),

                  amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag})
          end.
	



ping(Channel,Q) ->
	amqp_channel:subscribe(Channel, #'basic.consume'{queue = Q}, self()),
	loop_ping(Channel,Q,0).

loop_ping(_Chnanel,_Q,25)->
	ok;
loop_ping(Channel,Q,Count) ->
	
	Payload = <<"ping">>,
	Exc = <<"pex">>,

	R_key = <<"pong">>,
	
	Publish = #'basic.publish'{exchange = Exc,routing_key = R_key},
	amqp_channel:cast(Channel, Publish, #amqp_msg{payload = Payload}),

          receive
              #'basic.consume_ok'{} ->
                  loop_ping(Channel,Q,Count+1);

              #'basic.cancel_ok'{} ->
                  ok;

              {#'basic.deliver'{delivery_tag = Tag}, Content} ->
				  #amqp_msg{payload = RPayload} = Content,
				  lager:info("[Ping] ~p~n",[RPayload]),

                  amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}),

                  loop_ping(Channel,Q,Count+1)
          end.
	

pong(Channel,Q) ->
	amqp_channel:subscribe(Channel, #'basic.consume'{queue = Q}, self()),
	loop_pong(Channel,Q,0).

loop_pong(_Chnanel,_Q,25)->
	ok;
loop_pong(Channel,Q,Count) ->
	
	Payload = <<"pong">>,
	Exc = <<"pex">>,
	R_key = <<"ping">>,

          receive
              #'basic.consume_ok'{} ->
                  loop_pong(Channel,Q,Count+1);
			  
              #'basic.cancel_ok'{} ->
                  ok;


              {#'basic.deliver'{delivery_tag = Tag}, Content} ->
				  #amqp_msg{payload = RPayload} = Content,
				  lager:info("[Pong] ~p~n",[RPayload]),

                  amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}),
				  Publish = #'basic.publish'{exchange = Exc,routing_key = R_key},
				  amqp_channel:cast(Channel, Publish, #amqp_msg{payload = Payload}),
    
				  loop_pong(Channel,Q,Count+1)
          end.



mytokens(Word) ->
  case Word of
    'and' -> true;
    as -> true;
    at -> true;
    by -> true;
    'catch' -> true;
    choice -> true;
    continue -> true;
    econtinue -> true;
    create -> true;
    do -> true;
    enter -> true;
    from -> true;
    global -> true;
    import -> true;
    instantiates -> true;
    interruptible -> true;
    local -> true;
    'or' -> true;
    par -> true;
    protocol -> true;
    rec -> true;
    erec -> true;
    role -> true;
    spawns -> true;
    throw -> true;
    to -> true;
    with -> true;
    _ -> false
  end.
