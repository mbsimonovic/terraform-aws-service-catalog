# Official AWS Docker Image for lambdas configured for a specific programming language
FROM public.ecr.aws/lambda/python:3.8

# Configure our directory structure. All the lambda code and dependencies will end up in BASE_DIR.
ENV BASE_DIR /usr/src/lambda
ENV SRC_DIR ${BASE_DIR}/src
ENV DEPS_DIR ${BASE_DIR}/dependencies

# Install our Python dependencies into DEPS_DIR and configure the PYTHONPATH environment variable so Python knows to
# look for the dependencies there.
RUN mkdir -p ${DEPS_DIR}
COPY requirements.txt ${DEPS_DIR}/requirements.txt
RUN pip install -r ${DEPS_DIR}/requirements.txt --target ${DEPS_DIR}
ENV PYTHONPATH ${DEPS_DIR}:${PYTHONPATH}

# Copy in our source code. Note that we intentionally put the source code in a separate folder from the dependencies so
# you can bind mount source code from your host OS for local, iterative development, without overwriting the
# dependencies.
RUN mkdir -p ${SRC_DIR}
COPY src ${SRC_DIR}/
WORKDIR ${SRC_DIR}

# Run the local test harness by default
ENTRYPOINT ["python", "test_harness.py"]
