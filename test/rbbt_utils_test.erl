%%%-------------------------------------------------------------------
%%%-------------------------------------------------------------------
%%% @author aku
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 20. Jun 2014 00:45
%%%-------------------------------------------------------------------
-module(rbbt_utils_test).
-author("aku").

-include_lib("eunit/include/eunit.hrl").

-define(USER,<<"test">>).
-define(PWD,<<"test">>).
-define(HOST,"94.23.60.219").



general_test() ->

  Conn = rbbt_utils:connect(?HOST, ?USER, ?PWD),

  Chn1 = rbbt_utils:open_channel(Conn),
  Chn2 = rbbt_utils:open_channel(Conn),

  Q1 = rbbt_utils:declare_q(Chn1,<<"t1">>),
  Q2 = rbbt_utils:declare_q(Chn2,t2),

  rbbt_utils:declare_exc(Chn1,test,<<"direct">>,true),

  rbbt_utils:bind_q_to_exc(Q1, <<"test">>, t1, Chn1),
  rbbt_utils:bind_q_to_exc(Q2, test, t2, Chn2),

  rbbt_utils:publish_msg(Chn1, test, t2, sent),

  timer:sleep(500),
  Payload = rbbt_utils:manual_recv(Chn2,Q2),

  rbbt_utils:delete_q(Chn1,Q1),
  rbbt_utils:delete_q(Chn2,Q2),

  amqp_channel:close(Chn1),
  amqp_channel:close(Chn2),
  amqp_connection:close(Conn),

  ?assertEqual(sent, Payload).


consumer_test()->
  Conn = rbbt_utils:connect(?HOST, ?USER, ?PWD),

  Chn = rbbt_utils:open_channel(Conn),

  Q = rbbt_utils:declare_q(Chn,<<"t1">>),
  rbbt_utils:declare_exc(Chn,test,<<"direct">>,true),

  rbbt_utils:bind_q_to_exc(Q, test, <<"t1">>, Chn),

  Pid = role_consumer:start_link({Chn, Q, self()}),

  rbbt_utils:publish_msg(Chn,test,t1,test),

  Return = receive
     {'$gen_cast',test} -> ok;
      _ -> error
  end,

  Pid ! exit,

  ?assertEqual(ok, Return).


coverage_test()->
  Conn = rbbt_utils:connect(?HOST, ?USER, ?PWD),

  Chn = rbbt_utils:open_channel(Conn),

  rbbt_utils:declare_exc(Chn,bid,<<"direct">>,false),

  Q = rbbt_utils:declare_q(Chn,<<"t1">>),

  %rbbt_utils:bind_to_global_exchange(bid,Chn,<<"t1">>),
  rbbt_utils:bind_q_to_exc(Q, bid, <<"t1">>, Chn),

  rbbt_utils:publish_msg(Chn, bid, <<"t1">>, test),

  Return = rbbt_utils:manual_recv(Chn, Q),


  rbbt_utils:delete_q(Chn, t1),
  rbbt_utils:delete_exc(Chn, bid),

  ?assertEqual(test,Return).
