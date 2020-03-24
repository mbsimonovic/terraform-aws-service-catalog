import unittest

import run_tests


class TestRunTestsHelperFunctions(unittest.TestCase):
    def test_kebab_case_to_camel_case(self):
        test_cases = [
            ('alb', 'Alb'),
            ('vpc-app', 'VpcApp'),
            ('account-baseline-app', 'AccountBaselineApp'),
        ]
        for kebab_case, camel_case in test_cases:
            self.assertEqual(
                run_tests.kebab_case_to_camel_case(kebab_case),
                camel_case,
            )

    def test_snake_case_to_camel_case(self):
        test_cases = [
            ('alb', 'Alb'),
            ('vpc_app', 'VpcApp'),
            ('account_baseline_app', 'AccountBaselineApp'),
        ]
        for snake_case, camel_case in test_cases:
            self.assertEqual(
                run_tests.snake_case_to_camel_case(snake_case),
                camel_case,
            )

    def test_get_tests_to_run_from_tfmodule(self):
        test_cases = [
            (
                ['modules/networking/alb', 'examples/for-learning-and-testing/networking/alb'],
                set(['TestAlb']),
            ),
            (
                [
                    'modules/landingzone/account-baseline-app',
                    'modules/landingzone/account-baseline-root',
                    'modules/landingzone/account-baseline-security',
                ],
                set(['TestAccountBaseline']),
            ),
            (
                ['modules/data-stores/aurora'],
                set(['TestAurora']),
            ),
            (
                ['examples/for-learning-and-testing/data-stores/aurora'],
                set(['TestAurora']),
            ),
            (
                ['modules/data-stores/aurora', 'examples/for-learning-and-testing/data-stores/ecr-repos'],
                set(['TestAurora', 'TestEcrRepos']),
            ),
            ([], set([])),
        ]
        for module_list, expected_tests in test_cases:
            self.assertEqual(run_tests.get_tests_to_run_from_tfmodule(module_list), expected_tests)

    def test_get_tests_to_run_from_test_file(self):
        test_cases = [
            (
                ['test/account_baseline_test.go', 'test/ecr_repos_test.go'],
                set(['TestAccountBaseline', 'TestEcrRepos']),
            ),
            (
                ['test/route53_test.go'],
                set(['TestRoute53']),
            ),
            ([], set([])),
        ]
        for updated_test_files, expected_tests in test_cases:
            self.assertEqual(run_tests.get_tests_to_run_from_test_file(updated_test_files), expected_tests)


if __name__ == '__main__':
    unittest.main()
