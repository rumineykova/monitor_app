%%%-------------------------------------------------------------------
%%% @author fo713
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 27. Jun 2014 10:12
%%%-------------------------------------------------------------------
-module(test_utils).
-author("fo713").

%% API
-export([aux_method_org/1, mytokens/1]).

-compile([{parse_transform, lager_transform}]).


aux_method_org(Args) ->
  receive
    {_,From,_} -> gen_server:reply(From,{ok,[{response_item,2},{lower,2},{accept,2},{send_update,2},{ready,2},{terminated,2},{config_done,2},{cancel,2}]}),
      aux_method_org(Args);
    {'$gen_cast',{timeout}} -> Args ! timeout,
      aux_method_org(Args);
    {'$gen_cast',{callback,cancel,{timeout}}} -> Args ! timeout,
      aux_method_org(Args);
    {'$gen_cast',{callback,ready,{ready}}} -> Args ! ready,
      aux_method_org(Args);
    {'$gen_cast',{callback,cancel,{cancel}}} -> Args ! cancel,
      aux_method_org(Args);
    {'$gen_cast',{callback, config_done,Reply}} -> Args ! {config_done, Reply},
      aux_method_org(Args);

    {'$gen_cast',{callback,projection_request,{send, FileName, Host, Port}}} ->
      lager:warning("FileName ~p",[FileName]),
      {ok, Socket} = gen_tcp:connect(list_to_atom(Host), Port, [binary, {active, false}]),
      PathFile = "../test/test_resources/" ++ FileName,
      true = filelib:is_regular(PathFile),
      {ok, _} = file:sendfile(PathFile, Socket),
      ok = gen_tcp:close(Socket),
      aux_method_org(Args);
    exit -> lager:info("exit"), ok;
    M -> lager:info("unkown ~p",[M]), Args ! {error,M},
      aux_method_org(Args)

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
