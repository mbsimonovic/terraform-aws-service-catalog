"""
Script to run tests only on the modules that changed. This allows for more efficient test cycles so that we don't have
to wait on tests for modules that we have not touched.

This relies on the following convention:
- Both modules and examples use the same name for the leaf directory. E.g., modules/foo and examples/for-learning-and-testing/foo.
- Tests for the modules are named with the prefix `TestCamelCaseModuleName`. For example, for the module `vpc-app`, the
  corresponding tests should all begin with `TestVpcApp`. Note that there can be multiple tests, as long as they all
  begin with TestVpcApp.
- Test files are prefixed with snake cased versions of the module names. For example, for the module `vpc-app`, the
  corresponding test file should be `vpc_app_test.go`.

We use python instead of bash for easier maintenance of the test map.
"""
import subprocess
import logging
import os
import re

logging.basicConfig(format='%(asctime)s [%(levelname)s] %(message)s', level=logging.INFO)

# Special cases where the test name does not directly correspond to the module name.
UNCONVENTIONAL_NAMES = {
    'account-baseline-app': 'account-baseline',
    'account-baseline-root': 'account-baseline',
    'account-baseline-security': 'account-baseline',
}

DEFAULT_SOURCE_REF = 'origin/master'
DEFAULT_TARGET_REF = 'HEAD'


def kebab_case_to_camel_case(kebab_case_str):
    """ Converts a kebab cased string (e.g., vpc-app) into camel case (e.g., VpcApp). """
    parts = kebab_case_str.split('-')
    parts_titled = [part.title() for part in parts]
    return ''.join(parts_titled)


def snake_case_to_camel_case(snake_case_str):
    """ Converts a snake cased string (e.g., vpc_app) into camel case (e.g., VpcApp). """
    parts = snake_case_str.split('_')
    parts_titled = [part.title() for part in parts]
    return ''.join(parts_titled)


def get_git_root():
    """ Returns the root directory of the git repository, assuming this script is run from within the repository. """
    result = subprocess.run(['git', 'rev-parse', '--show-toplevel'], stdout=subprocess.PIPE, check=True)
    if result.stdout is None:
        # TODO: concrete exception
        raise Exception('Did not get any output from git: stderr is "{}"'.format(result.stderr))
    return result.stdout.decode('utf-8').rstrip('\n')


def get_terraform_modules():
    """
    Returns the list of all terraform modules in this git repo, where terraform module is a folder containing tf files.
    """
    git_root = get_git_root()
    result = subprocess.run(['find', git_root, '-name', '*.tf'], stdout=subprocess.PIPE, check=True)
    if result.stdout is None:
        # TODO: concrete exception
        raise Exception('Did not get any output from find: stderr is "{}"'.format(result.stderr))
    module_list = [os.path.dirname(module.decode('utf-8').strip()) for module in result.stdout.splitlines()]
    return module_list


def get_modules_updated():
    """
    Calls out to the script git-updated-folders to find all the terraform modules that have been updated since master.
    Returns a list of strings representing all the updated modules, with each being the relative path to the module from
    the git project root.

    Since some modules may have subdirectories containing different files such as shell scripts and packer templates,
    this function will look for all terraform modules and normalize the directories so that only the module root is
    returned.
    """
    # First get the raw list of folders contianing updated files
    result = subprocess.run(
        [
            'git-updated-folders',
            '--source-ref', DEFAULT_SOURCE_REF,
            '--target-ref', DEFAULT_TARGET_REF,
            '--terraform',
            '--ext', '.sh',
            '--ext', '.py',
            '--ext', '.json',
        ],
        stdout=subprocess.PIPE,
        check=True,
    )
    if result.stdout is None:
        return []
    updated_folders = [folder.decode('utf-8').strip() for folder in result.stdout.splitlines()]

    # Then normalize the folders to the containing terraform module directory.
    updated_modules = set()
    all_modules = get_terraform_modules()
    for folder in updated_folders:
        module = find_module(all_modules, folder)
        if module is not None:
            updated_modules.add(module)
    return list(updated_modules)


def get_test_files_updated():
    """ Returns a list of test files that were updated. """
    git_root = get_git_root()
    result = subprocess.run(
        ['git', '-C', git_root, 'diff', '--name-only', DEFAULT_SOURCE_REF, DEFAULT_TARGET_REF],
        stdout=subprocess.PIPE,
        check=True,
    )
    if result.stdout is None:
        return []
    updated_files = (f.decode('utf-8').strip() for f in result.stdout.splitlines())
    updated_test_files = [f for f in updated_files if f.startswith('test') and f.endswith('.go')]
    return updated_test_files


def find_module(all_modules, folder):
    """
    Given the list of all modules, and a folder that is potentially a subdirectory of that module, return the module
    that contains that folder.
    """
    for module in all_modules:
        if folder.startswith(module):
            return module
    return None


def get_tests_to_run_from_tfmodule(module_list):
    """
    Given a list of strings representing module paths (as returned by get_modules_updated), return all the tests that
    should be run. Tests to run are determined by convention based on the module base name.

    For example, if the module `vpc-app` was updated, the folder will be `modules/networking/vpc-app`, and the test will
    be TestVpcApp.

    Returns a set of strings where each item is a test prefix to run.
    """
    tests_to_run = set()
    for module in module_list:
        module_base = os.path.basename(module)
        if module_base in UNCONVENTIONAL_NAMES:
            module_base = UNCONVENTIONAL_NAMES[module_base]

        # Convert to camel case
        test_name = kebab_case_to_camel_case(module_base)
        tests_to_run.add('Test{}'.format(test_name))
    return tests_to_run


def get_tests_to_run_from_test_file(updated_test_files):
    """
    Given a list of strings representing go test files (as returned by get_test_files_updated), return all the tests
    that should be run. Tests to run are determined by convention based on the test file name.

    For example, if the test file `vpc_app_test.go` was updated, the tests to run will be `TestVpcApp`. Note that we use
    test names instead of directly passing the file to `go test` so that we can handle cross file dependencies.

    Returns a set of strings where each item is a test prefix to run.
    """
    tests_to_run = set()
    for tfile_path in updated_test_files:
        tfilename = os.path.basename(tfile_path)
        name = re.sub(r'_test.go$', '', tfilename)
        test_name = snake_case_to_camel_case(name)
        tests_to_run.add('Test{}'.format(test_name))
    return tests_to_run


def get_tests_to_run_regex(tests_to_run):
    """
    Given a collection of test prefixes, construct the regex that matches all the tests.
    """
    tests_to_run_regex = '^({})'.format('|'.join(tests_to_run))
    return tests_to_run_regex


def main():
    # 1. Get all the modules that were updated
    logging.info('Generating list of all modules that have been updated')
    module_list = get_modules_updated()
    logging.info('The following modules have been detected to be updated:')
    for module in module_list:
        logging.info('\t- {}'.format(module))

    # 2. Get all the tests that were updated
    logging.info('Generating list of all test files that have been updated')
    updated_test_files = get_test_files_updated()
    logging.info('The following test files have been detected to be updated:')
    for tfile in updated_test_files:
        logging.info('\t- {}'.format(tfile))

    # 3. Find all the tests that need to run based on the updated modules and test files list
    logging.info('Generating list of tests to run based on the list of modules and test files that were updated')
    module_tests_to_run = get_tests_to_run_from_tfmodule(module_list)
    test_file_tests_to_run = get_tests_to_run_from_test_file(updated_test_files)
    tests_to_run = module_tests_to_run.union(test_file_tests_to_run)
    logging.info('The following tests will be run:')
    for test in tests_to_run:
        logging.info('\t- {}'.format(test))

    # 4. Construct the regex and print it to stdout so it can be used in a script
    logging.info('Running all the tests')
    print(get_tests_to_run_regex(tests_to_run))


if __name__ == '__main__':
    main()
