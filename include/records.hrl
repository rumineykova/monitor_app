
-record(internal,{main_sup,
		regp = [],
		prot_sup = []}
).

-record(prot_sup,{protocol,
  ref,
  roles}
).

-record(lrole,{role,
		roles,
		ref,
		imp_ref,
		funcs}
).

-record(func,{msg,
		func}
).

-record(role_data,{spec,
		conn,
		exc}
).

-record(spec,{protocol, 
		role,
		roles,
		ref, 
		imp_ref,
		funcs,
		projection,
    lines}
).

-record(conn,{connection,
		active_chn,
		con_id,
		active_q,
		active_exc,
		active_cns}).

-record(exc,{state,
		count}
).

-record(row, {num, 
		inst}
).


