#!/usr/bin/env bash

# ## Usage examples:
#
# Test current branch against master:
#    test_regression.sh
# Test current branch against another branch:
#    test_regression.sh another-branch
# Test current branch against master passing arguments to busted:
#    test_regression.sh -- --exclude-tags=flaky
# Test current branch against next passing arguments to busted:
#    test_regression.sh next -- --exclude-tags=flaky

if [ $(git status --untracked-files=no --porcelain | wc -l) != "0" ]
then
   echo "=============================="
   echo "Local tree is not clean, please commit or stash before running this."
   echo "=============================="
   exit 1
fi

newbranch=$(git rev-parse --abbrev-ref HEAD)
if [ "$newbranch" = "master" ] || [ "$newbranch" = "next" ]
then
   echo "=============================="
   echo "Please run this from a topic branch, and not from 'next' or 'master'."
   echo "=============================="
   exit 1
fi

basebranch="$1"
if [ "$1" == "" ] || [ "$1" == "--" ]
then
   basebranch=master
else
   basebranch="$1"
   shift
fi
if [ "$1" == "--" ]
then
   shift
fi

git checkout "$newbranch"
rm -rf .spec-new
rm -rf .spec-old
cp -a spec .spec-new
git checkout "$basebranch"

echo "----------------------------------------"
echo "Tests changed between $basebranch and $newbranch:"
echo "----------------------------------------"
specfiles=($(git diff-tree --no-commit-id --name-only -r "..$newbranch" | grep "^spec/"))
echo "${specfiles[@]}"
echo "----------------------------------------"

mv spec .spec-old
mv .spec-new spec
./luarocks test -- "${specfiles[@]}" "$@"
if [ $? = 0 ]
then
   git checkout .
   git checkout $newbranch
   echo "=============================="
   echo "Regression test does not trigger the issue in base branch"
   echo "=============================="
   exit 1
fi
mv spec .spec-new
mv .spec-old spec
git checkout $newbranch
./luarocks test -- "${specfiles[@]}" "$@"
ret=$?
if [ "$ret" != "0" ]
then
   echo "=============================="
   echo "New branch does not fix issue (returned $ret)"
   echo "=============================="
   exit 1
fi

echo "=============================="
echo "All good! New branch fixes regression!"
echo "=============================="
exit 0

