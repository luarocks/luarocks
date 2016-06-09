#LuaRocks testsuite
##Overview
Test suite for LuaRocks project with Busted framework(http://olivinelabs.com/busted/). 

* Contains white-box & black-box tests
* Easy setup for your purpose on command line or from configuration file


## Dependencies
* Lua >= 5.1 
* Busted with dependencies


##Usage
Running of tests is based on basic Busted usage. *Helper* script is always *testing.lua*, mandatory for building environment to test black-box tests. Mandatory argument is version of Lua. Always start tests inside folder.

**Arguments for Busted helper script**

```
lua=<version>, !mandatory! type your full version of Lua (e.g. --lua 5.2.4)
env=<type>,	(default:"minimal") type what kind of environment to use ["minimal", "full"]
clean,	remove existing testing environment
os=<version>,    type your OS ["linux", "os x", "windows"]
```
---------------------------------------------------------------------------------------------
**Tags** of tests are required and are in this format:

*type-of-test*\_*name-of-command*

for example: `blackbox_install` or `whitebox_help`

###Examples
To run white-box tests in LuaRocks directory type :

`busted --exclude-tags="blackbox"`

To run black-box tests just of *install* command (we defined our OS, so OS check is skipped.):

`busted --helper="testing.lua" -Xhelper lua=5.2.4,os=linux -t "blackbox_install"`

To run black-box tests of *install* command, whitebox of *help* command (use *full* type of environment):

`busted --helper="testing.lua" -Xhelper lua=5.2.4,env=full -t "blackbox_install", "whitebox_help"`