# This is used to determine what to use as the base comparison point for determining what modules to deploy. The logic
# is as follows:
#   - If we are on the main branch, the comparison is only the current commit.
#   - If we are not on main, the comparison is to the current state of the main branch.
if [[ "${GITHUB_REF##*/}" == "main" ]]; then
  echo 'HEAD^'
else
  echo 'origin/main'
fi
