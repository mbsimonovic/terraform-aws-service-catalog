# A simple test harness that can be used to run and test the lambda function locally. It reads a URL to test from
# cmd line args, calls the handler function with it, and prints the response.

import logging
import argparse
from index import handler

logging.basicConfig()
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def run_handler_locally(url):
    event = {"url": url}

    logger.info('Running lambda function locally with event object:', event)
    result = handler(event, None)

    logger.info('Response from lambda function: %s' % result)

parser = argparse.ArgumentParser(description='Run the lambda function locally and write the image it returns to disk')
parser.add_argument('url', help='The URL to test')
args = parser.parse_args()

run_handler_locally(args.url)
