# kroy ⤚  Prolog IRC bot for the MONADIC.US hacker co-op based on Yesbot. 

Big thanks to dmile's for his work on Yesbot.  Really makes a difference when 
hackers share great code.  This project hopes to support Yesbot.

## Description
* Multi-threaded extensible bot with a "pluggable" system.
* Extensions are assumed to be mutually exclusive and will run concurrently.
* Written with the SWI Prolog implementation -- [SWI Prolog Website](http://www.swi-prolog.org/)


## Configuration

### Summary (Detailed Instructions Follow).

1.  Install `irc_client`.
2.  `swipl config.pl`
3.  Change extensions if needed (not necessary to get going).
4.  Change username, passwd, and nick using `set_setting(config:nick, kroy).`
5.  Change channel using `set_setting(config:channel, '#monadicus').`
5.  `save_settings.` will create a settings.db file in working dir to edit if needed.

### Details

Before doing anything, you must first install the `irc_client` pack for SWI-Prolog from the interpreter
```prolog
?- pack_install(irc_client).
```

Aferwards, you must configure the bot using the settings tools in SWI-Prolog.

Examine `config.pl` (using `swipl config.pl`)

If you would like to change which extensions are loaded on bot startup you must use:
```prolog

% replace these plugin names with valid ones
?- set_extensions([plugin1, plugin2]).

```
Any other settings you need to change, you can change by doing:
```prolog

?- set_setting(config:nick, examplebot).

```
You can _check_ your current settings with:
```prolog
?- setting(config:nick, examplebot).

```
When done persist them with:
```prolog

?- save_settings.

```
They'll be saved in a new file, `settings.db`, in your working directory.

This file should not be added to git's managed files.

`settings.db` can be edited manually if you desire.

Do be aware that the default logs the bot onto ##prolog and ##math

Please bot responsibly.


## Running the bot
After chmod 755 run.pl, execute the bot like such:
```prolog

./run.pl

```

## Extending the bot

There are numerous demo plugins that come with Yesbot. A few of which includes a basic chat-logging
extension and a TinyURL powered link shortener. The default setting for these extensions are the
abovementioned. Extensions for Yesbot are very simple. They are basically Prolog predicates with
the same name as their containing modules. All Yesbot extensions are required to have an arity of 1.
Extensions should all take in one argument: a pair containing the Id of the connection and the
current server line. The pair should be of the form `Id-Msg`. The main extension predicate should
have the same name as the Prolog module itself (sans the `.pl` portion). The demo extension source
code is located in the extensions directory. A warning: The majority of the extensions that come
with this bot were designed for ##prolog usage. While they can be catered to work generically, they
may require tinkering to get them to work for your use cases.
