%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                                %
%                                                                                %
% Author: Ebrahim Azarisooreh                                                    %
% E-mail: ebrahim.azarisooreh@gmail.com                                          %
% IRC Nick: eazar001                                                             %
% Title: Yes-Bot                                                                 %
% Descripton: IRC Bot                                                            %
%                                                                                %
%                                                                                %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

:- module(core, []).

:- use_module(config).
:- use_module(parser).
:- use_module(dispatch).
:- use_module(extensions/chat_log).
:- use_module(extensions/link_shortener).
:- use_module(library(socket)).

%--------------------------------------------------------------------------------%
% Connection Details
%--------------------------------------------------------------------------------%


%% connect is nondet.
%
% Open socket on host, port, nick, user, hostname, and servername that will all
% be specified in the bot_config module. The socket stream that is established
% will be asserted at the top level for access from anywhere in the program.

connect :-
  debug,
  host(Host),
  port(Port),
  nick(Nick),
  pass(Pass),
  chan(Chan),
  setup_call_cleanup(
    (
       init_extensions,
       init_structs(Nick, Pass, Chan),
       tcp_socket(Socket),
       tcp_connect(Socket, Host:Port, Stream),
       asserta(get_irc_stream(Stream)),
       register_and_join
    ),
    read_server_loop(_Reply),
    disconnect).


%--------------------------------------------------------------------------------%


%% register_and_join is det.
%
% Present credentials and register user on the irc server.

register_and_join :-
  send_msg(pass),
  send_msg(user),
  send_msg(nick),
  send_msg(join).


%--------------------------------------------------------------------------------%


%% init_structs(+Nick, +Pass, +Chan) is det.
%
% Assert the 'connection' structure at the top level so that access to important
% user information is available at the top level throughout the program. All of
% this information should be specified in the bot_config module.

init_structs(Nick, Pass, Chan) :-
  bot_hostname(HostName),
  bot_servername(ServerName),
  bot_realname(RealName),
  Connect = connection(
    Nick
   ,Pass
   ,Chan
   ,HostName
   ,ServerName
   ,RealName),
  asserta(Connect).


%--------------------------------------------------------------------------------%


% TODO : Implement dynamic extension backbone here

init_extensions :-
  directory_files(extensions, Ms0),
  exclude(call(core:non_file), Ms0, Ms1),
  include(core:is_extension, Ms1, Modules),
  maplist(core:make_goal, Modules, Extensions),
  length(Extensions, N),
  asserta(extensions(Extensions, N)).

non_file('.').
non_file('..').

is_extension(X) :-
  atom_codes(X, Codes),
  is_extension(Codes, []).

is_extension --> `.pl`.
is_extension --> [_], is_extension.
  

make_goal(File, Goal) :-
  once(sub_atom(File, _, _, 3, F)),
  Goal =.. [F].


%--------------------------------------------------------------------------------%
% Server Routing
%--------------------------------------------------------------------------------%


%% read_server_loop(-Reply) is nondet.
%
% Read the server output one line at a time. Each line will be sent directly
% to a predicate that is responsible for handling the output that it receives.
% The program will terminate successfully if EOF is reached.

read_server_loop(Reply) :-
  get_irc_stream(Stream),
  init_queue(_MQ),
  repeat,
  read_server(Reply, Stream),
  Reply = end_of_file, !.


%% read_server(-Reply, +Stream) is semidet.
%
% Translate server line to codes. If the codes are equivalent to EOF then succeed
% and go back to the main loop for termination. If not then then display the
% contents of the server message and process the reply.

read_server(Reply, Stream) :-
  read_line_to_codes(Stream, Reply),
  (
     Reply = end_of_file ->
       true
     ;
       thread_send_message(mq, read_server_handle(Reply))
  ).


%% read_server_handle(+Reply) is semidet.
%
% Concurrently process server lines via loaded extensions and output the server
% line to stdout for debugging.

read_server_handle(Reply) :-
  concurrent(2,
    [ run_det(process_server(Reply))
     ,run_det(format('~s~n', [Reply])) ], []).


%--------------------------------------------------------------------------------%


%% init_queue(+Id) is det.
%
% Initialize a message queue to store server lines to be processed in the future.
% Server lines will be processed sequentially.

init_queue(Id) :-
  message_queue_create(Id, [alias(mq)]),
  thread_create(start_job(Id), _, [alias(msg_handler)]).


%% start_job(+Id) is nondet.
%
% Wait for any messages directed to the Id of the message queue. Fetch the
% message from the thread and call Goal. Catch any errors and print the messages.
% Keep thread alive to watch for new jobs to execute.

start_job(Id) :-
  repeat,
  thread_get_message(Id, Goal),
  (
     catch(Goal, E, print_message(error, E)) ->
       true
     ;
       print_message(error, goal_failed(Goal, worker(Id)))
  ),
  fail.


%--------------------------------------------------------------------------------%


%% process_server(+Reply) is nondet.
%
% All processing of server message will be handled here. Pings will be handled by
% responding with a pong to keep the connection alive. Anything else will be
% processed as an incoming message. Further server processing extensions should
% be implemented dynamically in this section.

process_server(Reply) :-
  parse_line(Reply, Msg),
  (
     Msg = msg("PING", [], Origin) ->
       send_msg(pong, Origin)
     ;
       process_msg(Msg)
  ).


%--------------------------------------------------------------------------------%
% Handle Incoming Server Messages
%--------------------------------------------------------------------------------%


%% process_msg(+Msg) is nondet.
%
% All extensions that deal specifically with handling messages should be
% implemented dynamically in this section. The extensions will be plugged into
% an execution list that follows a successful parse of a private message.

process_msg(Msg) :-
  extensions(E0, N),
  maplist(run_det(Msg), E0, Extensions),
  concurrent(N, Extensions, []).


%% run_det(+Msg, +Extension, -E) is det.
%
% Concurrently call a list of extension predicates on the current message.

run_det(Msg, Extension, E) :-
  E = findall(_, call(core:Extension, Msg), _).


%% run_det(+Goal) is det.
%
% Find all the solutions to an extensionized goal in order to precipitate the
% result as an unevaluated deterministic result. Used here for making extension
% work concurrent.

run_det(Goal) :-
  findall(_, Goal, _).

%--------------------------------------------------------------------------------%
% Cleanup/Termination
%--------------------------------------------------------------------------------%


%% disconnect is det.
%
% Clean up top level information access structures, issue a disconnect command
% to the irc server, and close the socket stream pair.

disconnect :-
  nodebug,
  get_irc_stream(Stream),
  send_msg(quit),
  retractall(get_irc_stream(_)),
  retractall(connection(_,_,_,_,_,_)),
  retractall(extensions(_, _)),
  thread_signal(msg_handler, throw(thread_quit)),
  message_queue_destroy(mq),
  close(Stream).


