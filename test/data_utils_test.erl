%%%-------------------------------------------------------------------
%%% @author aku
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 19. Jun 2014 01:02
%%%-------------------------------------------------------------------
-module(data_utils_test).
-author("aku").

-include_lib("eunit/include/eunit.hrl").
-include("records.hrl").

-compile([{parse_transform, lager_transform}]).

%% -record(spec,{protocol, role, roles, ref, imp_ref, funcs, projection, lines}).
spec_test()->
  Spc = data_utils:spec_create(pt,rl,rls,mprf,[fncs],prj,ln),
  ?assertEqual(#spec{ protocol = pt, role = rl, roles = rls,  imp_ref = mprf, funcs = [fncs], projection = prj, lines = ln},Spc),

  Spc1 = data_utils:spec_update_mult(Spc, [{protocol,pt1},{role,rl1},{roles,rls1},{imp_ref,mprf1},{funcs,[fncs1]},{projection,prj1},{lines,ln1}]),
  ?assertEqual(#spec{ protocol = pt1, role = rl1, roles = rls1, imp_ref = mprf1, funcs = [fncs1], projection = prj1, lines = ln1},Spc1).


%% -record(conn,{connection, active_chn, con_id, active_q, active_exc, active_cns}).
conn_test()->
  Cnn = data_utils:conn_create(cn,chn,id,q,exc,cns),
  ?assertEqual(#conn{connection = cn, active_chn = chn, con_id = id, active_q = q, active_exc = exc, active_cns = cns},Cnn),

  Chn1 = data_utils:conn_update_mult(Cnn,[{connection,cn1},{active_chn,chn1},{con_id,id1},{active_q,q1},{active_exc,exc1},{active_cns,cns1}]),
  ?assertEqual(#conn{connection = cn1, active_chn = chn1, con_id = id1, active_q = q1, active_exc = exc1, active_cns = cns1},Chn1).


%% -record(lrole,{role, roles, ref, imp_ref, funcs}).
lrole_test()->
  Lr = data_utils:lrole_create(rl,rls,impref, [funcs]),
  ?assertEqual(#lrole{ role = rl, roles = rls, imp_ref = impref, funcs = [funcs]}, Lr),

  Lr2 = data_utils:lrole_add_func(Lr,fc1),
  ?assertEqual(#lrole{ role = rl, roles = rls,  imp_ref = impref, funcs = [fc1, funcs]}, Lr2),

  Lr1 = data_utils:lrole_update_mult(Lr, [{role, rl1},{roles, rls1},{imp_ref, mprf1},{funcs, [fc1]}]),
  ?assertEqual(#lrole{role = rl1, roles = rls1, imp_ref = mprf1, funcs = [fc1]}, Lr1).

%% -record(prot_sup,{protocol, ref, roles}).
prot_sup_test()->
  Psup = data_utils:prot_sup_create(prot, ref, [rl]),
  ?assertEqual(#prot_sup{ protocol = prot, ref = ref, roles = [rl]}, Psup),

  Psup2 = data_utils:prot_sup_add_role(Psup, rl1),
  ?assertEqual(#prot_sup{ protocol = prot, ref = ref, roles = [rl1, rl]}, Psup2),

  Psup1 = data_utils:prot_sup_update_mult(Psup, [{protocol, pt1},{ref, rf1},{roles, [rl1]}]),
  ?assertEqual(#prot_sup{ protocol = pt1, ref = rf1, roles = [rl1]}, Psup1).


%% -record(role_data,{spec, conn, exc}).
role_data_test()->
  Rdata = data_utils:role_data_create(spec, conn, exc),
  ?assertEqual(#role_data{ spec = spec, conn = conn, exc = exc}, Rdata),

  Rdata1 = data_utils:role_data_update_mult(Rdata, [{spec, sp1},{conn, cn1},{exc, exc1}]),
  ?assertEqual(#role_data{ spec = sp1, conn = cn1, exc = exc1}, Rdata1).


%%  -record(exc,{state, count}).
exc_test()->
  Exc = data_utils:exc_create(st, ct, sn),
  ?assertEqual(#exc{ state = st, count = ct, secret_number = sn}, Exc),

  Exc1 = data_utils:exc_update(state, Exc, st1),
  ?assertEqual(#exc{ state = st1, count = ct,  secret_number = sn}, Exc1),

  Exc2 = data_utils:exc_update(count, Exc1, ct1),
  ?assertEqual(#exc{ state = st1, count = ct1,  secret_number = sn}, Exc2),

  Exc3 = data_utils:exc_update(secret_number, Exc2, sn1),
  ?assertEqual(#exc{ state = st1, count = ct1, secret_number = sn1}, Exc3).



%%  -record(row, {num, inst}).
row_test()->
  Row = data_utils:row_create(none, none1),
  ?assertEqual(#row{ num = none, inst = none1 },Row),

  Row2 = data_utils:row_update(num, Row, up1),
  ?assertEqual(#row{ num = up1, inst =none1 },Row2),

  Row3 = data_utils:row_update(inst, Row2, up2),
  ?assertEqual(#row{ num = up1, inst = up2}, Row3).



%% -record(func,{message, func}).
func_test()->

  Func = data_utils:func_create(none, none1),
  ?assertEqual(#func{ sign = none, func = none1 },Func),

  Func2 = data_utils:func_update(sign, Func, up1),
  ?assertEqual(#func{ sign = up1, func =none1 },Func2),

  Func3 = data_utils:func_update(func, Func2, up2),
  ?assertEqual(#func{ sign = up1, func =up2 }, Func3).