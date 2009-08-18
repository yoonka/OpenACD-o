%%	The contents of this file are subject to the Common Public Attribution
%%	License Version 1.0 (the “License”); you may not use this file except
%%	in compliance with the License. You may obtain a copy of the License at
%%	http://opensource.org/licenses/cpal_1.0. The License is based on the
%%	Mozilla Public License Version 1.1 but Sections 14 and 15 have been
%%	added to cover use of software over a computer network and provide for
%%	limited attribution for the Original Developer. In addition, Exhibit A
%%	has been modified to be consistent with Exhibit B.
%%
%%	Software distributed under the License is distributed on an “AS IS”
%%	basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%%	License for the specific language governing rights and limitations
%%	under the License.
%%
%%	The Original Code is Spice Telephony.
%%
%%	The Initial Developers of the Original Code is
%%	Andrew Thompson and Micah Warren.
%%
%%	All portions of the code written by the Initial Developers are Copyright
%%	(c) 2008-2009 SpiceCSM.
%%	All Rights Reserved.
%%
%%	Contributor(s):
%%
%%	Andrew Thompson <athompson at spicecsm dot com>
%%	Micah Warren <mwarren at spicecsm dot com>
%%

%% @doc A file output backend for cpxlog.

-module(cpxlog_file).
-behaviour(gen_event).

-include("log.hrl").

-export([
	init/1,
	handle_event/2,
	handle_call/2,
	handle_info/2,
	terminate/2,
	code_change/3
]).

-record(state, {
	%level = info :: loglevels(),
	%debugmodules = [] :: [atom()],
	lasttime = erlang:localtime() :: {{non_neg_integer(), non_neg_integer(), non_neg_integer()}, {non_neg_integer(), non_neg_integer(), non_neg_integer()}},
	filehandles = [] :: [{string(), any(), loglevels()}]
}).

-type(state() :: #state{}).
-define(GEN_EVENT, true).
-include("gen_spec.hrl").

init(undefined) ->
	{'EXIT', "no logfiles defined"};
init([Files]) ->
	open_files(Files, #state{}).

open_files([], State) ->
	{ok, State};
open_files([{Filename, LogLevel} | Tail], State) ->
	case file:open(Filename, [append, raw]) of
		{ok, FileHandle} ->
			open_files(Tail, State#state{filehandles = [{Filename, FileHandle, LogLevel} | State#state.filehandles]});
		{error, _Reason} ->
			io:format("can't open logfile ~p~n", [Filename]),
			{'EXIT', "unable to open logfile " ++ Filename}
	end.

handle_event({Level, Time, Module, Line, Pid, Message, Args}, State) ->
	case (element(3, element(1, Time)) =/= element(3, element(1, State#state.lasttime))) of
		true ->
			lists:foreach(fun({_, FH, _}) ->
						file:write(FH, io_lib:format("Day changed from ~p to ~p~n", [element(1, State#state.lasttime), element(1, Time)]))
			end, State#state.filehandles);
		false ->
			ok
	end,
	lists:foreach(fun({_, FH, LogLevel}) ->
				case ((lists:member(Level, ?LOGLEVELS) andalso (util:list_index(Level, ?LOGLEVELS) >= util:list_index(LogLevel, ?LOGLEVELS)))) of
					true ->
						file:write(FH,
							io_lib:format("~w:~s:~s [~s] ~w@~s:~w ~s~n", [
									element(1, element(2, Time)),
									string:right(integer_to_list(element(2, element(2, Time))), 2, $0),
									string:right(integer_to_list(element(3, element(2, Time))), 2, $0),
									string:to_upper(atom_to_list(Level)),
									Pid, Module, Line,
									io_lib:format(Message, Args)]));
					false ->
						ok
				end
		end, State#state.filehandles),
	{ok, State#state{lasttime = Time}};
handle_event(_Event, State) ->
	{ok, State}.

handle_call(_Request, State) ->
	{ok, ok, State}.

handle_info(_Info, State) ->
	{ok, State}.

terminate(_Args, State) ->
	lists:foreach(fun({_, FH, _}) -> file:close(FH) end, State#state.filehandles),
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.