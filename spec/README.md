
# LuaRocks testsuite

## Overview

Test suite for LuaRocks project with Busted unit testing framework(http://olivinelabs.com/busted/).

* Contains unit and integration tests
* Easy setup for your purpose on command line or from configuration file

## Dependencies

* Lua >= 5.1
* Busted with dependencies

## Usage

Running of tests is based on basic Busted usage. *-Xhelper* flag is used
for inserting arguments into testing. Flag *--tags=* or *-t* is used
for specifying which tests will run. Start tests inside
LuaRocks folder or specify with *-C* flag.

**Arguments for Busted helper script**

```
env=<type>,       (default:"minimal") type what kind of environment to use ["minimal", "full"]
noreset,          Don't reset environment after each test
clean,            remove existing testing environment
appveyor,         add just if running on Appveyor
ci,               add just if running on Unix CI
os=<version>,     type your OS ["linux", "os x", "windows"]
```
---------------------------------------------------------------------------------------------
## _**Tags** of tests are required and are in this format:_

**unit** - run all unit tests

**integration** - run all integration tests

**ssh** - run all tests which require ssh

**mock** - run all tests which require mock LuaRocks server (upload tests)

**unix** - run all tests which are UNIX based, won't work on Windows systems

## Examples

To run all tests:

`busted`

To run unit tests in LuaRocks directory type :

`busted -t "unit"`

To run integration tests without tests which use ssh:

`busted -t "integration" --exclude-tags=ssh`
