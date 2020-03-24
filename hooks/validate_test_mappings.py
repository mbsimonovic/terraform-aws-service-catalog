#!/usr/bin/env python
"""
pre-commit hook to validate that all files have corresponding tests associated with them.
"""
# TODO: add logging and add documentation
import sys
import os
import re
import glob
import subprocess

import run_tests


IGNORE_PREFIX_LIST = [
    '_docs',
    'examples/for-production',
    '.circleci',
    'hooks',
    'test/fixtures',
    '.gitignore',
    '.pre-commit-config.yaml',
    'CODEOWNERS',
    'LICENSE.txt',
]
IGNORE_SUFFIX_LIST = [
    'go.mod',
    'go.sum',
    'README.md',
    'README.adoc',
    'core-concepts.md',
    'test_helpers.go',
]


def main():
    files_to_inspect = [f for f in get_all_files() if should_inspect_file(f)]
    terraform_modules, test_files = group_files_to_inspect(files_to_inspect)

    project_root = run_tests.get_git_root()
    test_funcs = get_all_test_functions(project_root)

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
    for f in files_without_tests:
        print('WTF')
        print(f)
    for func in test_funcs_without_files:
        print('OMG')
        print(func)


def matched_test_funcs_from_tfmodule_file(test_funcs, module_file):
    tests_to_run = run_tests.get_tests_to_run_from_tfmodule([os.path.dirname(module_file)])
    regex = run_tests.get_tests_to_run_regex(tests_to_run)
    matched_funcs = [func for func in test_funcs if re.match(regex, func)]
    return matched_funcs


def matched_test_funcs_from_test_file(test_funcs, test_file):
    tests_to_run = run_tests.get_tests_to_run_from_test_file([test_file])
    regex = run_tests.get_tests_to_run_regex(tests_to_run)
    matched_funcs = [func for func in test_funcs if re.match(regex, func)]
    return matched_funcs


def should_inspect_file(fpath):
    for prefix in IGNORE_PREFIX_LIST:
        if fpath.startswith(prefix):
            return False
    for suffix in IGNORE_SUFFIX_LIST:
        if fpath.endswith(suffix):
            return False
    return True


def group_files_to_inspect(files_to_inspect):
    test_files = []
    terraform_modules = []
    for f in files_to_inspect:
        if f.startswith('test'):
            test_files.append(f)
        else:
            terraform_modules.append(f)
    return terraform_modules, test_files


def get_all_test_functions(project_root):
    test_functions = []
    for test_file in glob.glob(os.path.join(project_root, 'test', '*_test.go')):
        with open(test_file) as f:
            data = f.read()
        test_function_matches = re.finditer(r'func (Test.+)\(', data)
        test_functions.extend([m.group(1) for m in test_function_matches])
    return test_functions


def get_all_files():
    result = subprocess.run(['git', 'ls-tree', '--name-only', '-r', 'HEAD'], stdout=subprocess.PIPE, check=True)
    if result.stdout is None:
        raise Exception('Did not get any output from git: stderr is "{}"'.format(result.stderr))
    return [line.decode('utf-8').strip() for line in result.stdout.splitlines()]


if __name__ == '__main__':
    main()
