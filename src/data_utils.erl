%%%-------------------------------------------------------------------
%%% @author fo713
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. Jun 2014 11:29
%%%-------------------------------------------------------------------
-module(data_utils).

-include("records.hrl").

%% API
-export([prot_sup_create/3, prot_sup_update/3, prot_sup_update_mult/2, prot_sup_add_role/2]).
-export([internal_create/3, internal_update/3, internal_add_regp/2, internal_update_mult/2]).
-export([lrole_create/4, lrole_update/3, lrole_update_mult/2, lrole_add_func/2]).
-export([role_data_create/3, role_data_update/3, role_data_update_mult/2]).
-export([spec_create/8, spec_update/3, spec_update_mult/2]).
-export([conn_create/6, conn_update/3, conn_update_mult/2]).
-export([func_create/2, func_update/3]).
-export([exc_create/2, exc_update/3]).
-export([row_create/2, row_update/3]).
%% ====================================================================
%% LROLE
%% -record(lrole,{role, roles, ref, imp_ref, funcs}).
%% ====================================================================

lrole_update_mult(Lrole, List) when is_list(List) ->
  lists:foldl(fun({Attr,Val},Acc)->
                    lrole_update(Attr,Acc, Val)
              end, Lrole, List).

lrole_add_func(Lrole, Func) ->
  lrole_update(addtofuncs, Lrole, Func).

lrole_update(addtofuncs, Lrole, Func)->
  Lrole#lrole{ funcs = [ Func | Lrole#lrole.funcs] };
lrole_update(role, Lrole, Role)->
  Lrole#lrole{ role = Role };
lrole_update(roles, Lrole, Roles) ->
  Lrole#lrole{ roles = Roles };
lrole_update(ref, Lrole, Ref) ->
  Lrole#lrole{ ref = Ref };
lrole_update(imp_ref, Lrole, Pid) ->
  Lrole#lrole{ imp_ref = Pid };
lrole_update(funcs, Lrole, Funcs) ->
  Lrole#lrole{ funcs = Funcs }.

lrole_create(Role, Roles, Pid, Funcs) when is_list(Funcs)->
  #lrole{role = Role,
         roles = Roles,
         imp_ref=Pid,
         funcs=Funcs}.


%% ====================================================================
%% Protocol Supervisor
%% -record(prot_sup,{protocol, ref, roles}).
%% ====================================================================

prot_sup_update_mult(Psup, ValList) when is_list(ValList)  ->
  lists:foldl(fun({Attr, Val}, Acc) ->
                    prot_sup_update(Attr, Acc, Val)
              end, Psup, ValList).

prot_sup_add_role(Psup, Role) ->
  prot_sup_update(addtoroles, Psup, Role).

prot_sup_update(addtoroles, Psup, Role) ->
  Psup#prot_sup{roles = [ Role | Psup#prot_sup.roles]};
prot_sup_update(roles, Psup, Roles) ->
  Psup#prot_sup{ roles = Roles };
prot_sup_update(ref, Psup, Ref) ->
  Psup#prot_sup{ ref = Ref };
prot_sup_update(protocol,Psup, Prot) ->
  Psup#prot_sup{ protocol = Prot}.

prot_sup_create(Prot, Ref, Roles) ->
  #prot_sup{protocol = Prot,
            ref = Ref,
            roles = Roles
            }.


%% ====================================================================
%% Protocol Supervisor
%% -record(func,{message, func}).
%% ====================================================================

func_update(func, Fnc, Val)->
  Fnc#func{ func = Val};
func_update(sign, Fnc, Val)->
  Fnc#func{ sign = Val}.

func_create(Msg, Func) ->
  #func{sign = Msg,
        func = Func}.


%% ====================================================================
%% Role data
%% -record(role_data,{spec, conn, exc}).
%% ====================================================================

role_data_update_mult(Rdata, ValList) when is_list(ValList) ->
  lists:foldl(fun({Attr, Val}, Acc) ->
                role_data_update(Attr, Acc, Val)
            end, Rdata, ValList).


role_data_update(exc, Rdata, Val) ->
  Rdata#role_data{ exc = Val };
role_data_update(conn, Rdata, Val) ->
  Rdata#role_data{ conn = Val };
role_data_update(spec, Rdata, Val) ->
  Rdata#role_data{ spec = Val }.

role_data_create(Spec, Conn, Exc) ->
  #role_data{spec = Spec,
             conn = Conn,
             exc = Exc
  }.

%% ====================================================================
%% Specification of a Role
%% -record(spec,{protocol, role, roles, ref, imp_ref, funcs, projection, lines}).
%% ====================================================================

spec_update_mult(Spec, ValList) when is_list(ValList) ->
  lists:foldl(fun({Attr, Val}, Acc)->
                spec_update(Attr, Acc, Val)
              end, Spec, ValList).


spec_update(lines, Spec, Val) ->
  Spec#spec{ lines = Val };
spec_update(projection, Spec, Val) ->
  Spec#spec{ projection = Val };
spec_update(funcs, Spec, Val) ->
  Spec#spec{ funcs = Val };
spec_update(imp_ref, Spec, Val) ->
  Spec#spec{ imp_ref = Val };
spec_update(ref, Spec, Val) ->
  Spec#spec{ ref = Val };
spec_update(roles, Spec, Val) ->
  Spec#spec{ roles = Val };
spec_update(role, Spec, Val) ->
  Spec#spec{ role = Val };
spec_update(protocol, Spec, Val) ->
  Spec#spec{ protocol = Val }.

spec_create(Prot, Role, Roles, Ref, ImpRef, Funcs, Proj, Lines) when is_list(Funcs)->
  #spec{ protocol = Prot,
         role = Role,
         roles = Roles,
         ref = Ref,
         imp_ref = ImpRef,
         funcs = Funcs,
         projection = Proj,
         lines = Lines
  }.


%% ====================================================================
%% Internal structure of Monscr
%% Regp = List of registered process
%% -record(internal,{main_sup, regp, prot_sup}).
%% ====================================================================

internal_update_mult(Internal, ValList) when is_list(ValList)->
  lists:foldl(fun({Attr, Val}, Acc)->
                  internal_update(Attr, Acc, Val)
              end, Internal ,ValList).

internal_add_regp(Internal, Process) ->
  internal_update(addregp, Internal , Process).

internal_update(addregp, Internal, Val)->
  Internal#internal{ regp = [Val | Internal#internal.regp] };
internal_update(prot_sup, Internal, Val)->
  Internal#internal{ prot_sup = Val };
internal_update(regp, Internal, Val)->
  Internal#internal{ regp = Val };
internal_update(main_sup, Internal, Val) ->
  Internal#internal{ main_sup = Val }.

internal_create( Main_sup, Regp, Prot_sup) when is_list(Regp) ->
  #internal{
    main_sup = Main_sup,
    regp = Regp,
    prot_sup = Prot_sup
  }.



%% ====================================================================
%% Role connection data (With rabbitmq)
%% -record(conn,{connection, active_chn, con_id, active_q, active_exc, active_cns}).
%% ====================================================================

conn_update_mult(Conn, ValList) when is_list(ValList) ->
  lists:foldl(fun({Attr, Val}, Acc) ->
                  conn_update(Attr, Acc, Val)
              end, Conn, ValList).


conn_update(active_cns, Conn, Val)->
  Conn#conn{ active_cns = Val };
conn_update(active_exc, Conn, Val)->
  Conn#conn{ active_exc = Val};
conn_update(active_q, Conn, Val)->
  Conn#conn{ active_q = Val };
conn_update(con_id, Conn, Val)->
  Conn#conn{ con_id = Val };
conn_update(active_chn, Conn, Val)->
  Conn#conn{ active_chn = Val };
conn_update(connection, Conn, Val)->
  Conn#conn{ connection = Val }.

conn_create(Con, ActChn, ConId, ActQ, ActExc, ActCns)->
  #conn{
        connection = Con,
        active_chn = ActChn,
        con_id = ConId,
        active_q = ActQ,
        active_exc = ActExc,
        active_cns = ActCns
  }.

%% ====================================================================
%% Current execution data structure (protocol state)
%%  -record(exc,{state, count}).
%% ====================================================================


exc_update(count, Conn, Val)->
  Conn#exc{ count = Val };
exc_update(state, Conn, Val)->
  Conn#exc{ state = Val }.

exc_create(State, Count) ->
  #exc{
        state = State,
        count = Count
  }.

%% ====================================================================
%% Database row for protocols
%%  -record(row, {num, inst}).
%% ====================================================================

row_update(inst, Row, Inst) ->
  Row#row{ inst = Inst };
row_update(num, Row, Num)->
  Row#row{ num = Num }.

row_create(Num, Inst)->
  #row{
        num = Num,
        inst = Inst
  }.