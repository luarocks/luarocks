SUITE: luarocks doc

================================================================================
TEST: --local

RUN: luarocks install --local --only-server=%{fixtures_dir}/a_repo a_rock

RUN: luarocks doc a_rock --local

STDOUT:
--------------------------------------------------------------------------------
opening http://www.example.com
--------------------------------------------------------------------------------
