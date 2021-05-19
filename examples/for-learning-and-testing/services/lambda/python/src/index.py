import logging
import requests

logging.basicConfig()
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    """Main entrypoint for the Lambda function. It does the following:

    1. Make an HTTP request to a specified URL
    2. Return the response body and status code as JSON

    Note that this code uses the requests library, so it'll only work if all dependencies were installed correctly.
    """
    logger.info("Received event %s", event)

    url = event.get("url")
    if not url:
        raise Exception("Event object did not specify a 'url' property")

    logger.info("Making HTTP GET request to %s", url)
    response = requests.get(url)

    return {"status": response.status_code, "body": response.text}
