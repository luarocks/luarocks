#LuaRocks testsuite
##Overview
Test suite for LuaRocks project with Busted unit testing framework(http://olivinelabs.com/busted/). 

* Contains white-box & black-box tests
* Easy setup for your purpose on command line or from configuration file


## Dependencies
* Lua >= 5.1 
* Busted with dependencies


##Usage
Running of tests is based on basic Busted usage. *-Xhelper* flag is mandatory for inserting arguments into testing (primary black-box). Flag *--tags=* or *-t* is mandatory for specifying which tests will run. Start tests inside LuaRocks folder or specify with *-C* flag.

**Arguments for Busted helper script**

```
lua=<version>, !mandatory! type your full version of Lua (e.g. lua=5.2.4)
OR
luajit=<version>, !mandatory! type your full version of LuaJIT (e.g. luajit=5.2.4)

env=<type>,	(default:"minimal") type what kind of environment to use ["minimal", "full"]
noreset,	Don't reset environment after each test
clean,	remove existing testing environment
appveyor,  add just if running on TravisCI
travis,  add just if running on TravisCI
os=<version>,    type your OS ["linux", "os x", "windows"]
```
---------------------------------------------------------------------------------------------
####_**Tags** of tests are required and are in this format:_

**whitebox** - run all whitebox tests

**blackbox** - run all blackbox tests

**ssh** - run all tests which require ssh

**mock** - run all tests which require mock LuaRocks server (upload tests)

**unix** - run all tests which are UNIX based, won't work on Windows systems

**w**\_*name-of-command* - whitebox testing of command

**b**\_*name-of-command* - blackbox testing of command

for example: `b_install`  or `w_help`

###Examples
To run all tests:
`busted`

To run white-box tests in LuaRocks directory type :

`busted -t "whitebox"`

To run black-box tests just of *install* command (we defined our OS, so OS check is skipped.):

`busted -Xhelper lua=5.2.4,os=linux -t "b_install"`

To run black-box tests of *install* command, whitebox of *help* command (using *full* type of environment):

`busted -Xhelper lua=5.2.4,env=full -t "b_install", "w_help"`

To run black-box tests without tests, which use ssh:

`busted -Xhelper lua=5.2.4 -t "blackbox" --exclude-tags=ssh`