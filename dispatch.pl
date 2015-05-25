
%% Message dispatching module
%
% This is a switchboard for routing message types to the correct message
% templates. Once the message template and respective substitution list is
% unified with the type, the process is consummated by dispatching the
% message through the stream.

:- module(dispatch,
     [ send_msg/1,
       send_msg/2,
       send_msg/3 ]).

:- use_module(operator).


%--------------------------------------------------------------------------------%
% Command Routing
%--------------------------------------------------------------------------------%


% FIXME: Not all message types from operator are implemented yet.

%% return_server(-Server:string) is det.
%
% If the server is known get the value from the core. If not, then the server is
% 'unknown'.

return_server(Server) :-
  (  core:known(irc_server)
  -> core:get_irc_server(Server)
  ;  Server = unknown
  ).


:- discontiguous dispatch:send_msg/3.

%% send_msg(+Type:atom, +Target:string) is semidet.
%
% Send message of Type with respect to a specified Target.

send_msg(Type, Target) :-
  cmd(Type, Msg),
  (
     Type = ping
  ;
     Type = pong,
     dbg(pong, Debug),
     format(Debug, [Target])
  ;
     Type = names
  ), !,
  core:get_irc_stream(Stream),
  format(Stream, Msg, [Target]),
  flush_output(Stream),
  thread_send_message(tq, true).


%% send_msg(+Type:atom, +Str:text, +Target:string) is semidet.
%
% send a Str of Type to a specified Target.

send_msg(Type, Str, Target) :-
  sub_string(Str, Before, _, _, "\n"),
  sub_string(Str, 0, Before, _, FirstLine),
  EndStartsAt is Before + 1,
  sub_string(Str, EndStartsAt, _, 0, Rest),
  send_msg_(Type, FirstLine, Target),
  send_msg(Type, Rest, Target),
  !.
send_msg(Type, Str, Target) :-
  \+ sub_string(Str, _, _, _, "\n"),
  send_msg_(Type, Str, Target).

%% send_msg(+Type:atom, +Chan:text, +Target:string) is semidet.
%
% Send a message of Type to Target in Chan.

send_msg(Type, Chan, Target) :-
  cmd(Type, Msg),
  core:get_irc_stream(Stream),
  (
     Type = kick,
     format(Stream, Msg, [Chan, Target])
  ;
     Type = invite,
     format(Stream, Msg, [Target, Chan])
  ), !,
  flush_output(Stream),
  thread_send_message(tq, true).


send_msg_(Type, Str, Target) :-
  cmd(Type, Msg),
  (  Type = priv_msg
  ;  Type = notice
  ), !,
  core:get_irc_stream(Stream),
  format(Stream, Msg, [Target, Str]),
  flush_output(Stream),
  thread_send_message(tq, true).


%% send_msg(+Type:atom) is semidet.
%
% Send a message of Type.

% This clause will deal with deal with message types that are possibly timer-independent
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
  ), !,
  flush_output(Stream),
  (  core:known(tq)
  -> thread_send_message(tq, true)
  ;  true
  ).

send_msg(Type) :-
  cmd(Type, Msg),
  core:get_irc_stream(Stream),
  return_server(Server),
  core:connection(_Nick, _Pass, _Chans, _HostName, _ServerName, _RealName),
  (
     Type = quit,
     write(Stream, Msg)
  ;
     Type = time,
     format(Stream, Msg, [Server])
  ),
  flush_output(Stream),
  thread_send_message(tq, true).


