%%%-------------------------------------------------------------------
%%% @author aku
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. Jun 2014 23:33
%%%-------------------------------------------------------------------
-module(db_utils).
-author("aku").


-include("records.hrl").
-compile([{parse_transform, lager_transform}]).

%% API
-export([install/2, get_row/2, update_row/3, add_row/3, get_table/1]).
-export([ets_create/2, ets_lookup/2,ets_lookup_raw/2, ets_insert/2, ets_delete/1,ets_lookup_child_pid/1, ets_lookup_client_pid/1]).
-export([ets_key_pattern_match/1,ets_remove_child_entry/1]).
%Might be removed ->
-export([print_db/2]).



install(Nodes, Path)->

    %Set the directory to store the file for the data base
    %THIS IS IMPORTANT !!!!! NOT remove
    application:set_env(mnesia, dir, Path),

    mnesia:create_schema([Nodes]),

    application:start(mnesia).



get_table(TableName)->
    %lager:error("Creating table: ~p", [TableName]),
    %When create gets emptied
    %lager:info("mnesia get table"),
    mnesia:create_table(TableName, [{attributes, record_info(fields, row)},
            {record_name,row},
            {ram_copies, [node()]}
        ]),

    %lager:info("wait for table"),
    mnesia:wait_for_tables([TableName], infinity), {created, TableName}.
%TODO: recover without filling
%case exist_table(TableName, mnesia:system_info(tables)) of
%  {false} ->    lager:info("[~p][get_table] Mnesia started",[?MODULE]),
%              mnesia:create_table(TableName, [{attributes, record_info(fields, row)},
%                                              {record_name,row},
%                                              {ram_copies, [node()]}
%                                             ]),
%              mnesia:wait_for_tables([TableName], infinity),
%              {created, TableName};
%  {true} -> lager:info("[~p][get_table] [MN] table already exits ~p",[self(), TableName]),
%            {exists, TableName};
%  Reason -> lager:error("[~p][get_table] Unkown success => ~p",[self(), Reason]),
%            {error, Reason}
%end.

%exist_table(_Tbl,[])->
%  {false};
%exist_table(Tbl,[T|R])->
%  case T of
%    T when Tbl =:= T -> {true};
%    _ -> exist_table(Tbl,R)
%   end.



%% add_row/3
%% ====================================================================
%% @doc
-spec add_row(TbName :: atom(), Num :: term(), Instr :: term()) -> Result when
    Result :: term().
%% ====================================================================
add_row(TbName, Num, Instr)->
    F = fun() ->
            mnesia:write(TbName,#row{num = Num,inst = Instr},write)
    end,
    mnesia:activity(ets, F).



get_row(TableName, RowNumber) ->
    [{_,_,Record}] = mnesia:dirty_match_object(TableName, #row{ num = RowNumber , inst = '_'}),
    Record.


update_row(TableName, CodeLine, NewContent)->

    F = fun()-> case mnesia:read(TableName, CodeLine, write) of
                [P] -> ok = mnesia:write(TableName, P#row{inst = NewContent}, write);
                _ -> mnesia:abort("No such person")
            end
    end,

    case mnesia:transaction(F) of
        {aborted, Reason} -> lager:info("aborted: ~p",[Reason]);
        {atomic, _ResultOfFun} -> ok
    end.


print_db(Tname, Ls)->
    lists:foreach(fun(Num) ->
                [{_,_,Record}] = mnesia:dirty_match_object(Tname,#row{num = Num, inst = '_'}),
                lager:warning("~p ~p",[Num, Record])
        end, Ls).


%% ================================================================================
%% Ets Methods
%% ================================================================================

ets_create(Name, Options) ->
    %lager:info("creating ets ~p",[ets:info(Name)]),
    case ets:info(Name) of
        undefined ->    _R = ets:new(Name,Options);
        %lager:info("R ~p ",[R]),R;
        _M -> %lager:info("defined: ~p",[M]),
            Name
    end.



%ets_remove_child_entry(Pid) when is_pid(Pid)->
%    P = #child_entry{id = '_', data = '_', worker ='_', client = Pid},
%    %lager:info("~p",[P]),
%    Ent = ets:match_object(child, P),
%    lager:info("~p",[Ent]),
%    lists:foreach(fun(E) ->  ets:delete(child, E#child_entry.id) end,Ent);
%    %true = ets:delete(child,Ent#child_entry.id);
ets_remove_child_entry(Key) when is_tuple(Key)->
    true = ets:delete(child, Key).


ets_key_pattern_match(Key) ->
    P = #child_entry{id = {Key, '_'}, data = '_', worker ='_', client = '_'},
    %lager:info("~p",[P]),
    ets:match_object(child, P).

ets_lookup(Mer, CName)->
    %lager:info("Trying to lookup ~p",[Mer]),
    [{_,Line}] = ets:lookup(Mer,CName),
    Line.



ets_lookup_client_pid(Key) ->
    List = ets:foldl(fun(E, Acc)-> [E | Acc] end, [], child),
    lager:info("CLIENT ~p~n~n",[List]),
    [P] = ets:lookup(child,Key),
    P#child_entry.client.

ets_lookup_child_pid(Key) ->
    List = ets:foldl(fun(E, Acc)-> [E | Acc] end, [], child),
    %lager:info("CHILD ~p~n~n",[List]),
    [P] = ets:lookup(child,Key),
    P#child_entry.worker.


ets_lookup_raw(Mer, Key)->
    ets:lookup(Mer,Key).

ets_insert(TbName, Content) when is_tuple(Content) ->
    ets:insert(TbName, Content).

ets_delete(TbName) ->
    case ets:info(TbName) of
        undefnied -> ok;
        _ -> ets:delete(TbName)
    end.


