# Readme for Minnet

This should hold some information about the project, what it can do and how to 
make it do so.


# CONTENTS

1. Licence
2. Requirements
  1. Note on irc.lua
3. Installation
4. Usage
  1. Configuration
  2. Connecting
  3. Putting Minnet to use
  4. List of commands


# 1 LICENCE

Minnet is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Minnet is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Minnet. If not, see [www.gnu.org][1].

See COPYING for the full licence.

  [1]: http://www.gnu.org/licenses/


# 2 REQUIREMENTS

Minnet requires Lua 5.1 and the packages lua-irc, luasocket, lsqlite3, luasec 
and crypto. lsqlite3 requires a working sqlite library to be installed, crypto 
and luasec require openssl. Luasec is optional, and only required if you want 
to make ssl-encrypted connections. 

Optional dependencies for the RSS module include luaexpat, lua-feedparser and 
wget or some other downloader (see minnet/rss.lua for using something else). 

Minnet as of currently has only been tested on GNU/Linux, but depending on how 
other systems handle certain things, it could work with little or no changes 
made to the code. Implementing support for BSD and OS X should be a matter of 
adding a few lines of code (provided the libraries required by Minnet work 
properly on the platforms).


## 2.1 NOTE

To use Minnet, you will need to patch your lua irc module with the patch file 
in this repo (`asyncoperations.lua.patch`). This is some strange design flaw 
in the module. It should not be necessary, but I'm lazy, and apparently, so is 
the author of the module.


# 3 INSTALLATION

Minnet is purely written in Lua, and as such does not need compiling. You can 
either place all the files as they are in a folder (like `~/bin/minnet`), and 
run Minnet thence, or you can copy the required files (`./minnet/*lua`), 
including the directory they reside in, to the place where you have your 
global lua libraries (typically `/usr/share/lua/5.1/`).

To get the code, you can clone the git repo, which is located at 
[Github][2]. This repo, even its master branch, is under heavy development, 
and there are no guarantees that the code will at any given time be stable or 
usable. Code in the master branch should generally not contain too many fatal 
bugs or inconsistencies, but it might have some. If you find anything and 
would like it fixed, feel free to notify me, preferably with a patch on your 
hand.

   [2]: git://github.com/staeld/minnet.git

If you want the bleeding edge (and most frequently updated) code, you should 
rather clone the development branch instead of the master branch. This branch 
is called `dev` (or some variation, like `serv-dev`, refer to [Github][2]).

As of currently, Minnet looks for the libraries it needs (including its own 
configuration and function files) through the standard Lua paths library paths 
as queried by require(). This means that if you do not copy the files to some- 
where where Lua looks for them, you will need to run Minnet from its own 
directory (eg. `cd ~/bin/minnet/ && ./minnet.lua --run`).

For installing the required modules, please refer to the documentation of your 
OS. luasocket, luasec, luacrypto, and lsqlite3 should all be available through 
luarocks; lua-irc is not (2011-06-10). In Arch Linux, you may also use the AUR, 
where you will also find lua-irc and lua-feedparser.


# 4 USAGE

## 4.1 CONFIGURATION

Minnet comes with a sample configuration file, located at 
`minnet/config.lua.sample` - this must be edited before using. It should hold 
all relevant information about servers and more. It also allows for tweaking 
and modifying of some aspects of Minnet's behaviour, such as output messages 
and user access levels.

For RSS feeds, the configuration is located at the top of `minnet/rss.lua`, 
with examples ready to be replaced with your own feeds.


## 4.2 CONNECTING

Minnet's syntax is rather simple. For a brief description, see Minnet's help 
message (using the `--help` flag). If you have specified several networks in 
the configuration, you can choose which network to join by using the 
`-n $netname` flag.

Provided you have set the correct eventual port, ssl and other related 
settings, Minnet should connect without any further ado. You should see a 
message indicating this in the console output. If you have not specified any 
channels to join by default, you can open a query and give her commands there, 
eventually giving a `join` command which brings her into the desired channel(s).


## 4.3 PUTTING MINNET TO USE

Minnet is not just an ordinary irc bot. She has been designed to feel more 
natural in both behaviour and handling, so as to remove some of the feeling 
that you are dealing with a hardcoded program and rather feel more intuitive 
and understanding. She has been attempted designed according to human logic, so 
that the syntax and commands should be easy to learn and use.

When connected and joined to a channel, Minnet idles without doing much on her 
own. By default, she will listen for lines beginning with her name, plus some 
more, as defined in `minnet/hooks.lua`.

If you wish to silence Minnet, telling her to be quiet (or just to shut up) 
will disable all command recognition for the channel in which the silencing 
command is given. The only exception to this is the re-enabling command, to 
avoid silencing her without an option to re-enable her.


## 4.4 LIST OF COMMANDS

For a full list of Minnet's commands, as represented by the internal names, 
say 'help commands'. For a description of each command, say 
`help <command_name>`, where the command name is the internal name of the 
command, as found in the command list or in `cmdvocab.lua` and `cmdarray.lua`.

The following is an approximate list, but is not necessarily completely up to
date.

```
----------------|------------------------|-------------------------------------
 Internal name  | Description            | Triggers (incomplete list)
----------------|------------------------|-------------------------------------
 join           | Join a channel         | "join", "go to"
 part           | Part a channel         | "part", "get out (of)"
 quit           | Disconnect             | "shut down", "quit", "disconnect"
 reload         | Reload a part of Minnet| "reload"
 set            | Set logging level      | "set"
 load           | Load a hook            | "load"
 unload         | Unload a hook          | "unload", "remove"
 reseed         | Re-seed math.random    | "reseed", "reset the crypto.* seed"
 say            | Make Minnet talk       | "say"
 version        | Send CTCP VERSION req  | "(ctcp) version"
 identify       | Log into the user db   | "identify", "i am"
 db             | Database operations    | "db", "database"
 belong         | "Own" Minnet (TST)     | "belong.* me", ".* me .* own you"
 ignore         | Ignore input from mask | "ignore", "disregard"
 help           | Get help on commands   | "help"
 owner          | Ownership-related      | "who owns you", "be mine"
 uptime         | Server/bot uptime      | "how long", "(what is your) uptime"
 time           | Current time w/zones   | "(what is the) time"
 timezones      | List known timezones   | "list.* timezones", "what timezones"
 disable        | Disable for channel    | "disable", "shut up", "be quiet"
 enable         | Re-enable Minnet       | "re-enable", "unsilence", "speak"
 be             | CTCP ACTION            | "be"
 twentytwo_seven| How long since #Utøya? | ".* utøya", ".* oslo", "2011-07-22"
----------------|------------------------|-------------------------------------
```
