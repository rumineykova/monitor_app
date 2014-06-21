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

  db_utils:install(node(),"db"),
  case db_utils:get_table(prova) of
    {created, _TbName} -> ok;
    {exists, _TbName} -> ok;
    {error, Reason} -> lager:error("~p",[Reason])
  end,

	lager:info("Mnesia create correctly"),

  lager:info("~p",[Scr]),
  NML  = role:translate_parsed_to_mnesia(prova,Scr),
  lager:info("~p",[NML]),
	?assertMatch({ok,_N}, {ok,4} ).


check_for_signatures_test() ->


  {ok,Data} = file:read_file("../resources/client.scr"),
  {ok,Final,_} = erl_scan:string(binary_to_list(Data),1,[{reserved_word_fun, fun mytokens/1}]),
  {ok,Scr} = scribble:parse(Final),

  db_utils:install(node(),"db"),
  case db_utils:get_table(prova) of
    {created, TbName} ->   role:translate_parsed_to_mnesia(TbName,Scr);
    {exists, TbName} -> role:translate_parsed_to_mnesia(TbName,Scr);
    {error, Reason} -> lager:error("~p",[Reason])
  end,

  Rest = role:check_signatures(prova, [{func, send_newPrice, sebay}]),
  Rest1 = role:check_signatures(prova, [{func, send_newP, sebay}]),

  ?assertEqual({error, signature_not_found }, Rest1),
  ?assertEqual({ok}, Rest).


check_for_methods_1_test() ->
  NRef = spawn_link(fun() ->
            receive
              {_,From,_} -> gen_server:reply(From,{ok,[{test,2},{ready,2},{terminated,2},{config_done,2},{cancel,2}]})
            end
          end),

  M =  role:check_method(NRef, [#func{ func = test }]),
  ?assertEqual({ok}, M).

check_for_methods_2_test() ->
  NRef = spawn_link(fun() ->
    receive
      {_,From,_} -> gen_server:reply(From,{ok,[{tst,2},{ready,2},{terminated,2},{config_done,2},{cancel,2}]})
    end
  end),

  M =  role:check_method(NRef, [#func{ sign = test }]),
  ?assertEqual({error, method_not_found}, M).


check_for_methods_3_test() ->
  NRef = spawn_link(fun() ->
    receive
      {_,From,_} -> gen_server:reply(From,{ok,[{test,2},{redy,2},{terminated,2},{config_done,2},{cancel,2}]})
    end
  end),

  M =  role:check_method(NRef, [#func{ sign = test }]),
  ?assertEqual({error, method_not_found}, M).

check_for_methods_4_test() ->
  NRef = spawn_link(fun() ->
    receive
      {_,From,_} -> gen_server:reply(From,{ok,[{test,2},{ready,2},{terminated,2},{config_done,2},{cancel,2}]})
    end
  end),

  M =  role:check_method(NRef, [#func{ sign = test1 }]),
  ?assertEqual({error, method_not_found}, M).

check_both_test()->

  {ok,Data} = file:read_file("../resources/client.scr"),
  {ok,Final,_} = erl_scan:string(binary_to_list(Data),1,[{reserved_word_fun, fun mytokens/1}]),
  {ok,Scr} = scribble:parse(Final),

  db_utils:install(node(),"db"),
  case db_utils:get_table(prova) of
    {created, TbName} ->   role:translate_parsed_to_mnesia(TbName,Scr);
    {exists, TbName} -> role:translate_parsed_to_mnesia(TbName,Scr);
    {error, Reason} -> lager:error("~p",[Reason])
  end,

  NRef1 = spawn_link(fun aux_method1/0),

  R1 = role:check_signatures_and_methods(NRef1, prova, [#func{ sign = send_newPrice, func = sebay }]),

  ?assertEqual({ok}, R1),

  NRef2 = spawn_link(fun aux_method1/0),

  R2 = role:check_signatures_and_methods(NRef2, prova,[#func{ sign = send_newP, func = sebay }]),

  ?assertEqual({error, signature_not_found }, R2),

  NRef3 = spawn_link(fun aux_method1/0),

  R3 = role:check_signatures_and_methods(NRef3,prova, [#func{ sign = send_newPrice, func = seb }]),

  ?assertEqual({error, method_not_found}, R3),

  NRef4 = spawn_link(fun aux_method2/0),

  R4 = role:check_signatures_and_methods(NRef4, prova,[#func{ sign = send_newPrice, func = sebay }]),

  ?assertEqual({error, method_not_found}, R4).

aux_method1() ->
    receive
      {_,From,_} -> gen_server:reply(From,{ok,[{sebay,2},{ready,2},{terminated,2},{config_done,2},{cancel,2}]})
    end.

aux_method2() ->
  receive
    {_,From,_} -> gen_server:reply(From,{ok,[{sebay,2},{read,2},{terminated,2},{config_done,2},{cancel,2}]})
  end.



















mnesia_data_retrive_test() ->
	lager:start(),
	application:set_env(mnesia, dir, "db"),

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
		

%ping_pong_test()->
%	 lager:start(),
%
%    User = <<"test">>,
%    Pwd = <<"test">>,
%
%	{ok, Connection} = amqp_connection:start(#amqp_params_network{username=User, password=Pwd, host="stock"}),
%	
%	{ok, Chn1} = amqp_connection:open_channel(Connection),	
%	{ok, Chn2} = amqp_connection:open_channel(Connection),
%
%	Q1 = ping_pong_exchange(pex,Chn1,ping),
%	Q2 = ping_pong_exchange(pex,Chn2,pong),
%
%	spawn_link(?MODULE,pong,[Chn2,Q2]),
%    ping(Chn1,Q1),
%
%	amqp_channel:close(Chn2),
%	amqp_channel:close(Chn1),
%
%	%% Close the connection
%	amqp_connection:close(Connection).
%
%
%
%
%
%global_exchange_test()->
%
%  lager:start(),
%
%  User = <<"test">>,
%  Pwd = <<"test">>,
%
%	{ok, Connection} = amqp_connection:start(#amqp_params_network{username=User, password=Pwd, host="stock"}),
%	
%	{ok, Chn1} = amqp_connection:open_channel(Connection),	
%	{ok, Chn2} = amqp_connection:open_channel(Connection),
%
%
%	Q1 = rbbt_utils:bind_to_global_exchange(gex,Chn1,sender),
%	Q2 = rbbt_utils:bind_to_global_exchange(gex,Chn2,receiver),
%
%  amqp_channel:subscribe(Chn2, #'basic.consume'{queue = Q2}, self()),
%  amqp_channel:subscribe(Chn1, #'basic.consume'{queue = Q1}, self()),
%
%	Payload = <<"foobar">>,
%	Exc = <<"gex">>,
%	_Pong = <<"pong">>,
%	
%	Publish = #'basic.publish'{exchange = Exc},
%	amqp_channel:cast(Chn1, Publish, #amqp_msg{payload = Payload}),
%
%  loop(Chn2),
%	
%	amqp_channel:close(Chn1),
%	amqp_channel:close(Chn2),
%	%% Close the connection
%	amqp_connection:close(Connection).
%
%
%  %    #'basic.consume_ok'{} ->
%	%		Get = #'basic.get'{queue = Q2, no_ack = true},
%	%		{#'basic.get_ok'{}, Content} = amqp_channel:call(Chn2, Get),
%    
%	%lager:stop().
%
%
%ping_pong_exchange(Protocol,Channel,Role)->
%
%    
%    Prot = atom_to_binary(Protocol,utf8),
%	R = atom_to_binary(Role,utf8),
%
%    EDeclare = #'exchange.declare'{exchange = Prot, type = <<"direct">>,auto_delete=true}, 
%	#'exchange.declare_ok'{} = amqp_channel:call(Channel, EDeclare),
%
%	
%	
%    Queue = atom_to_binary(Role,utf8),
%
%	%% Declare a queue
%	#'queue.declare_ok'{queue = Q}
%		= amqp_channel:call(Channel, #'queue.declare'{queue=Queue,auto_delete=true}),	
%	
%	Binding = #'queue.bind'{queue       = Q,
%							exchange    = Prot,
%							routing_key = R},
%	
%    #'queue.bind_ok'{} = amqp_channel:call(Channel, Binding),
%	lager:info("[AMQP] ~p binded to the ~p exchange done.~n",[Role,Protocol]),
%	Q.
%
%
%
%loop(Channel) ->
%          receive
%              #'basic.consume_ok'{} ->
%                  loop(Channel);
%
%              #'basic.cancel_ok'{} ->
%                  ok;
%
%              {#'basic.deliver'{delivery_tag = Tag}, Content} ->
%				  #amqp_msg{payload = Payload} = Content,
%				  lager:info("[AMQP] ~p~n",[Payload]),
%
%                  amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag})
%          end.
%	
%
%
%
%ping(Channel,Q) ->
%	amqp_channel:subscribe(Channel, #'basic.consume'{queue = Q}, self()),
%	loop_ping(Channel,Q,0).
%
%loop_ping(_Chnanel,_Q,25)->
%	ok;
%loop_ping(Channel,Q,Count) ->
%	
%	Payload = <<"ping">>,
%	Exc = <<"pex">>,
%
%	R_key = <<"pong">>,
%	
%	Publish = #'basic.publish'{exchange = Exc,routing_key = R_key},
%	amqp_channel:cast(Channel, Publish, #amqp_msg{payload = Payload}),
%
%          receive
%              #'basic.consume_ok'{} ->
%                  loop_ping(Channel,Q,Count+1);
%
%              #'basic.cancel_ok'{} ->
%                  ok;
%
%              {#'basic.deliver'{delivery_tag = Tag}, Content} ->
%				  #amqp_msg{payload = RPayload} = Content,
%				  lager:info("[Ping] ~p~n",[RPayload]),
%
%                  amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}),
%
%                  loop_ping(Channel,Q,Count+1)
%          end.
%	
%
%pong(Channel,Q) ->
%	amqp_channel:subscribe(Channel, #'basic.consume'{queue = Q}, self()),
%	loop_pong(Channel,Q,0).
%
%loop_pong(_Chnanel,_Q,25)->
%	ok;
%loop_pong(Channel,Q,Count) ->
%	
%	Payload = <<"pong">>,
%	Exc = <<"pex">>,
%	R_key = <<"ping">>,
%
%          receive
%              #'basic.consume_ok'{} ->
%                  loop_pong(Channel,Q,Count+1);
%			  
%              #'basic.cancel_ok'{} ->
%                  ok;
%
%
%              {#'basic.deliver'{delivery_tag = Tag}, Content} ->
%				  #amqp_msg{payload = RPayload} = Content,
%				  lager:info("[Pong] ~p~n",[RPayload]),
%
%                  amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}),
%				  Publish = #'basic.publish'{exchange = Exc,routing_key = R_key},
%				  amqp_channel:cast(Channel, Publish, #amqp_msg{payload = Payload}),
%    
%				  loop_pong(Channel,Q,Count+1)
%          end.
%


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
