#!/usr/bin/env bash
# Find all the tests to run and add a comment to the PR.

test_regex=""
if [[ "$CIRCLE_BRANCH" == "master" ]]; then
  # On master, the last commit is the merge commit which contains all the changes
  test_regex="$(python ./.circleci/run_tests.py --source-ref 'HEAD^' 2> debug.log)"
else
  test_regex="$(python ./.circleci/run_tests.py 2> debug.log)"
fi
cat debug.log

# Store the tests to run in a folder which we will write to the CircleCi cache
mkdir -p /home/circleci/.terraform-aws-service-catalog
echo "$test_regex" >> /home/circleci/.terraform-aws-service-catalog/test-regex.txt

# Comment the debug log on GitHub if there is a PR number
CIRCLE_PR_NUMBER="${CIRCLE_PR_NUMBER:-${CIRCLE_PULL_REQUEST##*/}}"
if [[ -n "$CIRCLE_PR_NUMBER" ]]; then
  echo -e "Tests run for build [$CIRCLE_BUILD_NUM]($CIRCLE_BUILD_URL)\n\`\`\`\n$(cat debug.log)\n\`\`\`" \
    | hub api repos/{owner}/{repo}/issues/"$CIRCLE_PR_NUMBER"/comments --field body=@-
fi