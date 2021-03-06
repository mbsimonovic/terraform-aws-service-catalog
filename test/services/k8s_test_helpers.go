package services

import (
	"fmt"
	"testing"
	"time"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/stretchr/testify/require"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

const (
	K8SServiceWaitTimerRetries = 60
	K8SServiceWaitTimerSleep   = 5 * time.Second
	K8SIngressWaitTimerSleep   = 20 * time.Second
	K8SServiceNumPodsExpected  = 1
)

// verifyPodsCreatedSuccessfully waits until the pods for the given helm release are created.
func verifyPodsCreatedSuccessfully(t *testing.T, kubectlOptions *k8s.KubectlOptions, appName string) {
	// Get the pods and wait until they are all ready
	filters := metav1.ListOptions{
		LabelSelector: fmt.Sprintf("app.kubernetes.io/name=%s,app.kubernetes.io/instance=%s", appName, appName),
	}

	k8s.WaitUntilNumPodsCreated(t, kubectlOptions, filters, K8SServiceNumPodsExpected, K8SServiceWaitTimerRetries, K8SServiceWaitTimerSleep)
	pods := k8s.ListPods(t, kubectlOptions, filters)

	for _, pod := range pods {
		k8s.WaitUntilPodAvailable(t, kubectlOptions, pod.Name, K8SServiceWaitTimerRetries, K8SServiceWaitTimerSleep)
	}
}

// verifyAllPodsAvailable waits until all the pods from the release are up and ready to serve traffic. The
// validationFunction is used to verify a successful response from the Pod.
func verifyAllPodsAvailable(
	t *testing.T,
	kubectlOptions *k8s.KubectlOptions,
	appName string,
	path string,
	validationFunction func(int, string) bool,
) {
	filters := metav1.ListOptions{
		LabelSelector: fmt.Sprintf("app.kubernetes.io/name=%s,app.kubernetes.io/instance=%s", appName, appName),
	}
	pods := k8s.ListPods(t, kubectlOptions, filters)
	for _, pod := range pods {
		verifySinglePodAvailable(t, kubectlOptions, pod, path, validationFunction)
	}
}

// verifySinglePodAvailable waits until the given pod is ready to serve traffic. Does so by pinging port 80 on the Pod
// container. The validationFunction is used to verify a successful response from the Pod.
func verifySinglePodAvailable(
	t *testing.T,
	kubectlOptions *k8s.KubectlOptions,
	pod corev1.Pod,
	path string,
	validationFunction func(int, string) bool,
) {
	// Open a tunnel from any available port locally
	localPort := k8s.GetAvailablePort(t)
	tunnel := k8s.NewTunnel(kubectlOptions, k8s.ResourceTypePod, pod.Name, localPort, 8080)
	defer tunnel.Close()
	tunnel.ForwardPort(t)

	// Try to access the service on the local port, retrying until we get a good response for up to 5 minutes
	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		fmt.Sprintf("http://%s%s", tunnel.Endpoint(), path),
		nil,
		K8SServiceWaitTimerRetries,
		K8SServiceWaitTimerSleep,
		validationFunction,
	)
}

// verifyServiceAvailable waits until the service associated with the helm release is available.
func verifyServiceAvailable(t *testing.T, kubectlOptions *k8s.KubectlOptions, appName string) {
	// Get the service and wait until it is available
	filters := metav1.ListOptions{
		LabelSelector: fmt.Sprintf("app.kubernetes.io/name=%s,app.kubernetes.io/instance=%s", appName, appName),
	}
	services := k8s.ListServices(t, kubectlOptions, filters)
	require.Equal(t, len(services), 1)
	service := services[0]
	k8s.WaitUntilServiceAvailable(t, kubectlOptions, service.Name, K8SServiceWaitTimerRetries, K8SServiceWaitTimerSleep)
}
