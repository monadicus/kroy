
%% Parsing module


:- module(parser, [parse_line/2]).


/*
Documentation Source: http://www.networksorcery.com/enp/protocol/irc.htm
Message syntax:
  
message =	[ ":" prefix SPACE ] command [ params ] crlf	
prefix =	servername / ( nickname [ [ "!" user ] "@" host ])	
command =	1*letter / 3digit	
params =	*14( SPACE middle ) [ SPACE ":" trailing ]	
=/	14( SPACE middle ) [ SPACE [ ":" ] trailing ]

// Any byte except NUL, CR, LF, " " and ":".
nospcrlfcl =	%x01-09 / %x0B-0C / %x0E-1F / %x21-39 / %x3B-FF
middle =	nospcrlfcl *( ":" / nospcrlfcl )	
trailing =	*( ":" / " " / nospcrlfcl )	
SPACE =	%x20	; Whitespace.
crlf =	%x0D %x0A	; Carriage return/linefeed.
*/  


%% parse_line(+Line, -Msg) is det.
%
% After splitting the line from any potential trailing parameters, format
% the line in a message compound term for proper reading outside of this
% module.

parse_line(Line, Msg) :-
  split_from_trailer(Line, Out),
  once(fmt_line(Out, Msg)).


%% fmt_line(+Line, -Msg) is det.
%
% Split a server message into (potentially) 3 parts. The message can be split
% into a prefix, command, and some command parameters. However, the prefix
% is optional and the parameter list can potentially be empty.
%
% Msg output is of the format:
%
% 1) msg(prefix, command, [parameters...], trailing_parameter).
%
% 2) msg(prefix, command, [parameters...]).
%
% 3) msg(command, [parameters...], trailing_parameter).
%
% 4) msg(command, [parameters...]).

fmt_line([has_prefix, Main, Trailer], msg(Prefix, Cmd, Params, Trailer)) :-
  split_string(Main, " ", "", [Prefix,Cmd|Params]).

fmt_line([has_prefix, Main], msg(Prefix, Cmd, Params)) :-
  split_string(Main, " ", "", [Prefix,Cmd|Params]).

fmt_line([Main, Trailer], msg(Cmd, Params, Trailer)) :-
  split_string(Main, " ", "", [Cmd|Params]).

fmt_line([Main], msg(Cmd, Params)) :-
  split_string(Main, " ", "", [Cmd|Params]).


%% split_from_trailer(+Line, -Out) is det.
%
% Split the main portion of the message from the trailer portion of the message
% if a trailer does exist. These are the possibilities when operating
% under the current IRC protocol:
%
% 1) ["", Main, Trailer]
% 2) ["", Main]
% 3) [Main, Trailer]
% 4) [Main]

split_from_trailer(Line, Out) :-
  split(First, Line, Trailer) ->
    (
       First = [58|Main] ->
         Out = [has_prefix, Main, Trailer]
       ;
         Main = First,
         Out = [Main, Trailer]
    )
  ;
    split_(First, Line, []) ->
      (
         First = [58|Main] ->
           Out = [has_prefix, Main]
         ;
           Main = First,
           Out = [Main]
      ).


split([]) --> ` :`.
split([M|Main]) -->
  [M], split(Main).

split_([]) --> [].
split_([M|Main]) -->
  [M], split_(Main).

