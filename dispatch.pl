
%% Message dispatching module


:- module(dispatch, [send_msg/1, send_msg/2, send_msg/3]).

:- use_module(operator).


%--------------------------------------------------------------------------------%
% Command Routing
%--------------------------------------------------------------------------------%


% XXX NOTE : not all message types are accounted for yet

%% send_msg(+Pong, +Nick, +Origin) is det.
%
% Send pong private message back to a specified origin.

send_msg(pong, Origin) :-
  cmd(pong, Msg),
  dbg(pong, Debug),
  core:get_irc_stream(Stream),
  format(Stream, Msg, [Origin]),
  format(Debug, [Origin]),
  flush_output(Stream).

%% send_msg(+Type, +Str, +Target) is det.
%
% send a private message or notice in the form of a string to a specified target.

send_msg(Type, Str, Target) :-
  cmd(Type, Msg),
  (
     Type = priv_msg
  ;
     Type = notice
  ),
  core:get_irc_stream(Stream),
  format(Stream, Msg, [Target, Str]),
  flush_output(Stream).

%% send_msg(+Type) is semidet.
%
% This is a switchboard for routing message types to the correct message
% templates. Once the message template and respective substitution list is
% unified with the type, the process is consummated by dispatching the
% message through the stream.

send_msg(Type) :-
  cmd(Type, Msg),
  core:get_irc_stream(Stream),
  core:connection(Nick, Pass, Chans, HostName, ServerName, RealName),
  (
     Type = pass,
     format(Stream, Msg, [Pass])
  ;
     Type = user,
     format(Stream, Msg, [Nick, HostName, ServerName, RealName])
  ;
     Type = nick,
     format(Stream, Msg, [Nick])
  ;
     Type = join,
     maplist(format(Stream, Msg), Chans)
  ;
     Type = quit,
     write(Stream, Msg)
  ),
  flush_output(Stream).


