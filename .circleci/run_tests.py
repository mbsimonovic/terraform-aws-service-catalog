"""
Script to run tests only on the modules that changed. This allows for more efficient test cycles so that we don't have
to wait on tests for modules that we have not touched.

This relies on the following convention:
- Both modules and examples use the same name for the leaf directory. E.g., modules/foo and examples/for-learning-and-testing/foo.
- Tests for the modules are named with the prefix `TestCamelCaseModuleName`. For example, for the module `vpc-app`, the
  corresponding tests should all begin with `TestVpcApp`. Note that there can be multiple tests, as long as they all
  begin with TestVpcApp.

We use python instead of bash for easier maintenance of the test map.
"""
import subprocess
import logging
import os

logging.basicConfig(format='%(asctime)s [%(levelname)s] %(message)s', level=logging.INFO)

# Special cases where the test name does not directly correspond to the module name.
UNCONVENTIONAL_NAMES = {
    'account-baseline-app': 'account-baseline',
    'account-baseline-root': 'account-baseline',
    'account-baseline-security': 'account-baseline',
}


def kebab_case_to_camel_case(kebab_case_str):
    """ Converts a kebab cased string (e.g., vpc-app) into camel case (e.g., VpcApp). """
    parts = kebab_case_str.split('-')
    parts_titled = [part.title() for part in parts]
    return ''.join(parts_titled)


def get_modules_updated():
    """
    Calls out to the script git-updated-folders to find all the terraform modules that have been updated since master.
    Returns a list of strings representing all the updated modules, with each being the relative path to the module from
    the git project root.
    """
    resp = subprocess.run(
        ['git-updated-folders', '--source-ref', 'origin/master', '--terraform'],
        stdout=subprocess.PIPE, check=True,
    )
    module_list = [module.decode('utf-8').strip() for module in resp.stdout.splitlines()]
    return module_list


def get_tests_to_run(module_list):
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


def run_tests(tests_to_run):
    """
    Given a collection of test prefixes, construct the regex that matches all the tests and run using run-go-tests.
    """
    tests_to_run_regex = '^({})'.format('|'.join(tests_to_run))
    subprocess.run(
        [
            'run-go-tests',
            '--path', './test',
            '--packages', '-run "{}"'.format(tests_to_run_regex),
            '--timeout', '1h',
            '--parallelism', '64',
        ],
        check=True,
    )


def main():
    # 1. Get all the folders containing files that changed
    logging.info('Generating list of all modules that have been updated')
    module_list = get_modules_updated()
    logging.info('The following modules have been detected to be updated:')
    for module in module_list:
        logging.info('\t- {}'.format(module))

    # 2. For each module, find all the tests to run
    logging.info('Generating list of tests to run based on the list of modules that were updated')
    tests_to_run = get_tests_to_run(module_list)
    logging.info('The following tests will be run:')
    for test in tests_to_run:
        logging.info('\t- {}'.format(test))

    # 3. Construct the regex and run the tests
    logging.info('Running all the tests')
    run_tests(tests_to_run)


if __name__ == '__main__':
    main()
