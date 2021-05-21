package networking

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/aws-service-catalog/test"

	awsgo "github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/servicediscovery"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestRoute53(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate", "true")
	//os.Setenv("SKIP_cleanup", "true")

	uniqueID := random.UniqueId()
	testFolder := "../../examples/for-learning-and-testing/networking/route53"

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)
	})

	//TODO: Figure out why certain regions don't have default VPCs
	// For the time being, hardcode the region to us-west-1
	test_structure.RunTestStage(t, "setup", func() {
		awsRegion := aws.GetRandomRegion(t, []string{"us-west-1"}, nil)

		test_structure.SaveString(t, testFolder, "region", awsRegion)

		publicZoneName := fmt.Sprintf("%s.gruntwork.in", uniqueID)
		publicZoneName2 := fmt.Sprintf("%s.gruntwork-dev.io", uniqueID)
		privateZoneName := fmt.Sprintf("gruntwork-test-%s.xyz", uniqueID)

		var privateZones = map[string]interface{}{
			privateZoneName: map[string]interface{}{
				"comment": "This is a test comment",
				"vpc_id":  aws.GetDefaultVpc(t, awsRegion).Id,
				"tags": map[string]interface{}{
					"Application": "redis",
					"Env":         "dev",
				},
				"force_destroy": true,
			},
		}

		var publicZones = map[string]interface{}{
			publicZoneName: map[string]interface{}{
				"comment": "This is a test comment",
				"tags": map[string]interface{}{
					"Application": "redis",
					"Env":         "dev",
				},
				"force_destroy": true,
				// This public zone should result in a single ACM cert that covers the apex and *.{uniqueID}.gruntwork.in
				"subject_alternative_names": []string{fmt.Sprintf("*.%s", publicZoneName)},
				"created_outside_terraform": true,
				"base_domain_name_tags":     map[string]interface{}{},
				"hosted_zone_domain_name":   "gruntwork.in",
			},
			publicZoneName2: map[string]interface{}{
				"comment": "This is a test comment",
				"tags": map[string]interface{}{
					"Application": "memcached",
					"Env":         "stage",
				},
				"force_destroy": true,
				// This public zone will not result in a wildcard cert
				"subject_alternative_names": []string{},
				"created_outside_terraform": true,
				"base_domain_name_tags":     map[string]interface{}{},
				"hosted_zone_domain_name":   "gruntwork-dev.io",
			}}

		terraformOptions := test.CreateBaseTerraformOptions(t, testFolder, awsRegion)
		terraformOptions.Vars["private_zones"] = privateZones
		terraformOptions.Vars["public_zones"] = publicZones

		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)

		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)

		privateDomainNames := terraform.OutputRequired(t, terraformOptions, "private_domain_names")
		privateZonesIds := terraform.OutputRequired(t, terraformOptions, "private_zones_ids")
		privateZonesNameServers := terraform.OutputRequired(t, terraformOptions, "private_zones_name_servers")

		publicDomainNames := terraform.OutputRequired(t, terraformOptions, "public_domain_names")
		publicZonesIds := terraform.OutputRequired(t, terraformOptions, "public_hosted_zones_ids")
		publicZonesNameServers := terraform.OutputRequired(t, terraformOptions, "public_hosted_zones_name_servers")

		require.NotNil(t, privateDomainNames)
		require.NotNil(t, privateZonesIds)
		require.NotNil(t, privateZonesNameServers)

		require.NotNil(t, publicDomainNames)
		require.NotNil(t, publicZonesIds)
		require.NotNil(t, publicZonesNameServers)
	})

}

// Verifies that setting provision_wilcard_certificate to true when creating public zones correctly results in a
// wildcard certificate and its required DNS validation records also being planned for creation
func TestRoute53ProvisionWildcardCertPlan(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate", "true")

	uniqueID := random.UniqueId()
	testFolder := test_structure.CopyTerraformFolderToTemp(t, "../../", "examples/for-learning-and-testing/networking/route53")

	test_structure.RunTestStage(t, "setup", func() {
		awsRegion := aws.GetRandomRegion(t, []string{"us-west-1"}, nil)

		test_structure.SaveString(t, testFolder, "region", awsRegion)

		publicZoneName := fmt.Sprintf("gruntwork-test-%s.gruntwork.in", uniqueID)

		var privateZones = make(map[string]interface{})

		var publicZones = map[string]interface{}{
			publicZoneName: map[string]interface{}{
				"name":    publicZoneName,
				"comment": "This is a test comment",
				"tags": map[string]interface{}{
					"Application": "redis",
					"Env":         "dev",
				},
				"force_destroy":             true,
				"subject_alternative_names": []string{fmt.Sprintf("*.%s", publicZoneName)},
				"created_outside_terraform": true,
				"base_domain_name_tags":     map[string]interface{}{"original": "true"},
				"hosted_zone_domain_name":   "gruntwork.in",
				"hosted_zone_id":            "Z2AJ7S3R6G9UYJ",
			},
		}

		terraformOptions := test.CreateBaseTerraformOptions(t, testFolder, awsRegion)
		terraformOptions.Vars["public_zones"] = publicZones
		terraformOptions.Vars["private_zones"] = privateZones

		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)

		output := terraform.InitAndPlan(t, terraformOptions)
		test_structure.SaveString(t, testFolder, "output", output)
	})

	test_structure.RunTestStage(t, "validate", func() {
		output := test_structure.LoadString(t, testFolder, "output")
		resourceCount := terraform.GetResourceCount(t, output)
		assert.Equal(t, resourceCount.Add, 5)
		assert.Equal(t, resourceCount.Change, 0)
		assert.Equal(t, resourceCount.Destroy, 0)
	})
}

func TestRoute53CloudMap(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("SKIP_setup_keypair", "true")
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate", "true")
	//os.Setenv("SKIP_cleanup", "true")

	testFolder := "../../examples/for-learning-and-testing/networking/cloudmap"

	defer test_structure.RunTestStage(t, "cleanup", func() {
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)

		serviceDiscoveryServiceName := terraform.Output(t, terraformOptions, "test_instance_service_discovery_service_name")
		serviceDiscoveryServiceID := terraform.Output(t, terraformOptions, "test_instance_service_discovery_service_id")
		serviceDiscoveryNamespace := terraformOptions.Vars["test_instance_namespace"].(string)
		deregisterAllInstancesFromService(t, awsRegion, serviceDiscoveryNamespace, serviceDiscoveryServiceName, serviceDiscoveryServiceID)

		terraform.Destroy(t, terraformOptions)

		awsKeyPair := test_structure.LoadEc2KeyPair(t, testFolder)
		aws.DeleteEC2KeyPair(t, awsKeyPair)
	})

	test_structure.RunTestStage(t, "setup_keypair", func() {
		awsRegion := aws.GetRandomRegion(t, []string{"us-west-1"}, nil)
		test_structure.SaveString(t, testFolder, "region", awsRegion)

		uniqueID := random.UniqueId()
		test_structure.SaveString(t, testFolder, "uniqueID", uniqueID)

		awsKeyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, uniqueID)
		test_structure.SaveEc2KeyPair(t, testFolder, awsKeyPair)
	})

	test_structure.RunTestStage(t, "setup", func() {
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		uniqueID := test_structure.LoadString(t, testFolder, "uniqueID")
		awsKeyPair := test_structure.LoadEc2KeyPair(t, testFolder)

		defaultVPC := aws.GetDefaultVpc(t, awsRegion)

		privateDomainName := fmt.Sprintf("gruntwork-test-%s.xyz", uniqueID)
		publicDomainName := fmt.Sprintf("gruntwork-test-%s.gruntwork.in", uniqueID)
		privateSDNamespaces := map[string]interface{}{
			privateDomainName: map[string]interface{}{
				"description": "This is an optional test description",
				"vpc_id":      defaultVPC.Id,
			},
		}

		publicSDNamespaces := map[string]interface{}{
			publicDomainName: map[string]interface{}{
				"description":               "This is another optional test comment",
				"subject_alternative_names": []string{fmt.Sprintf("*.%s", publicDomainName)},
				"created_outside_terraform": true,
				"hosted_zone_domain_name":   "gruntwork.in",
				"hosted_zone_id":            "Z2AJ7S3R6G9UYJ",
			},
		}

		terraformOptions := test.CreateBaseTerraformOptions(t, testFolder, awsRegion)
		terraformOptions.Vars["service_discovery_private_namespaces"] = privateSDNamespaces
		terraformOptions.Vars["service_discovery_public_namespaces"] = publicSDNamespaces

		terraformOptions.Vars["test_instance_namespace"] = privateDomainName
		terraformOptions.Vars["test_instance_name"] = fmt.Sprintf("test-cloud-map-%s", uniqueID)
		terraformOptions.Vars["test_instance_vpc_subnet_id"] = defaultVPC.Subnets[0].Id
		terraformOptions.Vars["test_instance_key_pair"] = awsKeyPair.Name

		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		awsKeyPair := test_structure.LoadEc2KeyPair(t, testFolder)

		serviceDiscoveryServiceName := terraform.Output(t, terraformOptions, "test_instance_service_discovery_service_name")
		serviceDiscoveryNamespace := terraformOptions.Vars["test_instance_namespace"].(string)

		// Test if we can query the service discovery service and retrieve a registered EC2 instance.
		clt := serviceDiscoveryClient(t, awsRegion)
		ipv4 := retry.DoWithRetry(
			t,
			"lookup registered instances",
			60,
			10*time.Second,
			func() (string, error) {
				resp, err := clt.DiscoverInstances(&servicediscovery.DiscoverInstancesInput{
					NamespaceName: awsgo.String(serviceDiscoveryNamespace),
					ServiceName:   awsgo.String(serviceDiscoveryServiceName),
				})
				if err != nil {
					return "", err
				}
				if len(resp.Instances) == 0 {
					return "", fmt.Errorf("No instances registered yet")
				}
				instance := resp.Instances[0]
				ipv4, hasIP := instance.Attributes["AWS_INSTANCE_IPV4"]
				if !hasIP {
					return "", fmt.Errorf("Does not have IPv4 address")
				}
				return awsgo.StringValue(ipv4), nil
			},
		)

		// Test if the IP is for the instance we registered by attemping SSH with the keypair we created in this test.
		host := ssh.Host{
			Hostname:    ipv4,
			SshUserName: "ec2-user",
			SshKeyPair:  awsKeyPair.KeyPair,
		}
		assert.Equal(t, ssh.CheckSshCommand(t, host, "echo -n \"Hello, World\""), "Hello, World")
	})
}

func deregisterAllInstancesFromService(
	t *testing.T,
	region string,
	serviceDiscoveryNamespace string,
	serviceDiscoveryServiceName string,
	serviceDiscoveryServiceID string,
) {
	clt := serviceDiscoveryClient(t, region)

	resp, err := clt.DiscoverInstances(&servicediscovery.DiscoverInstancesInput{
		NamespaceName: awsgo.String(serviceDiscoveryNamespace),
		ServiceName:   awsgo.String(serviceDiscoveryServiceName),
	})
	require.NoError(t, err)

	for _, inst := range resp.Instances {
		_, err := clt.DeregisterInstance(&servicediscovery.DeregisterInstanceInput{
			InstanceId: inst.InstanceId,
			ServiceId:  awsgo.String(serviceDiscoveryServiceID),
		})
		require.NoError(t, err)
	}
}

func serviceDiscoveryClient(t *testing.T, region string) *servicediscovery.ServiceDiscovery {
	sess, err := aws.NewAuthenticatedSession(region)
	require.NoError(t, err)
	return servicediscovery.New(sess)
}
