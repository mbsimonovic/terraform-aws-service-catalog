"""
Script to run tests only on the modules that changed. This allows for more efficient test cycles so that we don't have
to wait on tests for modules that we have not touched.

We use python instead of bash for easier maintenance of the test map.
"""
import subprocess
import logging
import os

logging.basicConfig(format='%(asctime)s [%(levelname)s] %(message)s', level=logging.INFO)

# Mapping from module to tests to run. Each key represents a leaf directory containing terraform code in either
# `/modules` or `/examples/for-learning-and-testing`
TEST_MAP = {
    'aurora': set(['TestAuroraServerless', 'TestAurora']),
    'ecr-repos': set(['TestECRRepositories', 'TestECRRepositoryIAMPoliciesLogic']),
    'account-baseline-app': set(['TestAccountBaselines']),
    'account-baseline-root': set(['TestAccountBaselines']),
    'account-baseline-security': set(['TestAccountBaselines']),
    'bastion-host': set(['TestBastionHost']),
    'jenkins': set(['TestJenkins']),
    'alb': set(['TestALB']),
    'route53': set(['TestRoute53']),
    'vpc-app': set(['TestVpcApp']),
}


def get_modules_updated():
    resp = subprocess.run(
        ['git-updated-folders', '--source-ref', 'origin/master', '--terraform'],
        stdout=subprocess.PIPE, check=True,
    )
    module_list = [module.decode('utf-8').strip() for module in resp.stdout.splitlines()]
    return module_list


def get_tests_to_run(module_list):
    tests_to_run = set()
    for module in module_list:
        module_base = os.path.basename(module)
        tests_to_run = tests_to_run.union(TEST_MAP[module_base])
    return tests_to_run


def run_tests(tests_to_run):
    tests_to_run_regex = '^({})$'.format('|'.join(tests_to_run))
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
