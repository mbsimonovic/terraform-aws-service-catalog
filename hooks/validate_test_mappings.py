#!/usr/bin/env python
"""
pre-commit hook to validate that all files have corresponding tests associated with them, and all tests have either a
module or test file associated with it.
"""
import logging
import sys
import os
import re
import glob
import subprocess

import run_tests


logging.basicConfig(format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger('validate-test-mappings')
logger.setLevel(logging.DEBUG)


# List of file prefixes and suffixes to ignore. Any files in the repo that has these prefixes or suffixes will be
# ignored from this pre-commit check.
IGNORE_PREFIX_LIST = [
    # Ignore repo meta files
    'CODEOWNERS',
    'LICENSE.txt',
    '.gitignore',
    '.pre-commit-config.yaml',
    '.circleci',

    # Ignore documentation assets
    '_docs',

    # Ignore pre-commit hooks
    'hooks',

    # Ignore production examples for now until https://github.com/gruntwork-io/aws-service-catalog/issues/28
    'examples/for-production',

    # Ignore test fixture changes
    'test/fixtures',

    # Ignore legacy packer file
    'modules/services/ecs-cluster/packer/ecs-node.json',
]
IGNORE_SUFFIX_LIST = [
    # Ignore go meta files
    'go.mod',
    'go.sum',

    # Ignore docs files
    'README.md',
    'README.adoc',
    'core-concepts.md',

    # Ignore docker for ECS runner as it is included in the EcsDeployRunner test
    'Dockerfile',
    'known_hosts',

    # Ignore test helpers changes, as that will trigger all tests and thus defeats the purpose of this pre-commit hook.
    'test_helpers.go',

    # Ignore html files
    '.html',
]


def main():
    project_root = run_tests.get_git_root()

    # 1. Find all the files in the repository to inspect and group them into terraform module files or go test files
    files_to_inspect = [f for f in get_all_files() if should_inspect_file(f)]
    terraform_modules, test_files = group_files_to_inspect(files_to_inspect)
    logger.debug('The following files were identified for inspection:')
    logger.debug('Terraform Module Files:')
    for m in terraform_modules:
        logger.debug('\t- {}'.format(m))
    logger.debug('Go Test Files:')
    for t in test_files:
        logger.debug('\t- {}'.format(t))

    # 2. Find all the test functions that are defined in the go test files.
    test_funcs = get_all_test_functions(project_root)
    logger.debug('The following test functions were identified for inspection:')
    for func in test_funcs:
        logger.debug('\t- {}'.format(func))

    # 3. Map files to test functions and find the orphans
    files_without_tests, test_funcs_without_files = get_orphaned_files_or_tests(
        test_funcs,
        terraform_modules,
        test_files,
    )
    if files_without_tests:
        logger.error('Found files without tests:')
        for f in files_without_tests:
            logger.error('\t- {}'.format(f))
    if test_funcs_without_files:
        logger.error('Found test functions without files:')
        for func in test_funcs_without_files:
            logger.error('\t- {}'.format(func))
    if files_without_tests or test_funcs_without_files:
        sys.exit(1)


def get_orphaned_files_or_tests(test_funcs, terraform_modules, test_files):
    """
    Given the list of all test functions, terraform module files and test files in the repo, use the `run_tests.py`
    functions to map the files to tests and see if we can find a corresponding test function. Once the files and tests
    are mapped, return:
    - The list of files (Terraform module file or test file) that did not have a corresponding test.
    - The list of test functions that were not mapped to with any file in the list.
    """
    files_without_tests = []
    test_func_has_file = {func: False for func in test_funcs}

    for module_file in terraform_modules:
        matched_funcs = matched_test_funcs_from_tfmodule_file(test_funcs, module_file)
        if not matched_funcs:
            files_without_tests.append(module_file)
        for func in matched_funcs:
            test_func_has_file[func] = True

    for test_file in test_files:
        matched_funcs = matched_test_funcs_from_test_file(test_funcs, test_file)
        if not matched_funcs:
            files_without_tests.append(test_file)
        for func in matched_funcs:
            test_func_has_file[func] = True

    test_funcs_without_files = [func for func, has_file in test_func_has_file.items() if not has_file]

    return files_without_tests, test_funcs_without_files


def matched_test_funcs_from_tfmodule_file(test_funcs, module_file):
    """
    Given the list of test functions and a terraform module file, use the `run_tests.py` functions to try to map the
    module to the tests, and return the matching test functions.
    """
    tests_to_run = run_tests.get_tests_to_run_from_tfmodule([os.path.dirname(module_file)])
    regex = run_tests.get_tests_to_run_regex(tests_to_run)
    matched_funcs = [func for func in test_funcs if re.match(regex, func)]
    return matched_funcs


def matched_test_funcs_from_test_file(test_funcs, test_file):
    """
    Given the list of test functions and a test file, use the `run_tests.py` functions to try to map the test file to
    the tests, and return the matching test functions.
    """
    tests_to_run = run_tests.get_tests_to_run_from_test_file([test_file])
    regex = run_tests.get_tests_to_run_regex(tests_to_run)
    matched_funcs = [func for func in test_funcs if re.match(regex, func)]
    return matched_funcs


def should_inspect_file(fpath):
    """
    Whether or not the given file should be inspected. Files that have a prefix from the IGNORE_PREFIX_LIST or suffix
    from the IGNORE_SUFFIX_LIST are ignored.
    """
    for prefix in IGNORE_PREFIX_LIST:
        if fpath.startswith(prefix):
            return False
    for suffix in IGNORE_SUFFIX_LIST:
        if fpath.endswith(suffix):
            return False
    return True


def group_files_to_inspect(files_to_inspect):
    """
    Group the files to inspect into two categories:
    - Test files (files in the `test` folder)
    - Terraform module files (everything else)
    """
    test_files = []
    terraform_modules = []
    for f in files_to_inspect:
        if f.startswith('test'):
            test_files.append(f)
        else:
            terraform_modules.append(f)
    return terraform_modules, test_files


def get_all_test_functions(project_root):
    """
    Get all the go test functions in the test package. This uses a regex heuristic to find all the test functions:

    for each file that ends with `_test.go` in the test directory, search for all matches of the regex
    "func (Test.*)\\(".
    """
    test_functions = []
    for test_file in glob.glob(os.path.join(project_root, 'test', '*_test.go')):
        with open(test_file) as f:
            data = f.read()
        test_function_matches = re.finditer(r'func (Test.+)\(', data)
        test_functions.extend([m.group(1) for m in test_function_matches])
    return test_functions


def get_all_files():
    """
    Get all files in the repository using the `git` command. This needs to run two subcommands:
    - ls-tree, which returns all the tracked files.
    - diff, to return all the staged files.
    """
    result = subprocess.run(['git', 'ls-tree', '--name-only', '-r', 'HEAD'], stdout=subprocess.PIPE, check=True)
    if result.stdout is None:
        raise Exception('Did not get any output from git: stderr is "{}"'.format(result.stderr))
    all_files = set([line.decode('utf-8').strip() for line in result.stdout.splitlines()])

    result = subprocess.run(['git', 'diff', '--staged', '--name-only'], stdout=subprocess.PIPE, check=True)
    if result.stdout is None:
        raise Exception('Did not get any output from git: stderr is "{}"'.format(result.stderr))
    staged_files = set([line.decode('utf-8').strip() for line in result.stdout.splitlines()])

    return all_files.union(staged_files)


if __name__ == '__main__':
    main()
