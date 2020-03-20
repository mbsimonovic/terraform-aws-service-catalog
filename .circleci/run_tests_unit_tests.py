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

    def test_get_tests_to_run(self):
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
        ]
        for module_list, expected_tests in test_cases:
            self.assertEqual(run_tests.get_tests_to_run(module_list), expected_tests)


if __name__ == '__main__':
    unittest.main()
