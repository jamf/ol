# DRAFT!!!



# Resources for Jamf Pro API developers

This document is a round-up of offerings that can speed up the learning and development cycle for people wishing to interact with Jamf's APIs. Some are provided by Jamf while others demonstrate the commitment and generousity of the Jamf Nation user community. 

[toc]

## Documentation

Jamf Pro's [API Documentation Landing Page](https://developer.jamf.com/jamf-pro/docs/) is the gateway to the endpoint specification pages and also includes articals general topics related to using the API. 

The site includes coverage of our older but still supported "[Classic](https://developer.jamf.com/jamf-pro/reference/classic-api)" API endpoints and also our newer "[Jamf Pro](https://developer.jamf.com/jamf-pro/docs/jamf-pro-api-overview)" API. These are explained in [Which API Should I Use?](https://developer.jamf.com/jamf-pro/docs/which-api-should-i-use)

**REST Endpoint Reference Documentation**

- [Classic](https://developer.jamf.com/jamf-pro/reference/classic-api) Endpoints
- [Jamf Pro](https://developer.jamf.com/jamf-pro/reference/jamf-pro-api) Endpoints

**Example Topic Pages:**

- Authentication -- [Client Credentials](https://developer.jamf.com/jamf-pro/docs/client-credentials)
- [Session Stickiness for Jamf Cloud](https://developer.jamf.com/jamf-pro/docs/sticky-sessions-for-jamf-cloud) -- Jamf Cloud hosts application server in a multi-server/load-balanced configuration. If you write a new record via the API and immediately attempt to write another record that had the first one as a dependency, your second update might fail if it hits a different server and the initial update hasn't finished syncronizing across all cluster instances. Session stickiness ensures that related updates are all handled by a single server instance, avoiding this problem area. 
- [Filtering with RSQL](https://developer.jamf.com/jamf-pro/docs/filtering-with-rsql) -- Some REST API endpoints allow the use of filters to retrieve data subsets. For example, you could request a list of all the computers assigned to a specific department. This is often more efficient that retrieving all the data and performing queries in your application. 
- [Jamf Pro](https://developer.jamf.com/jamf-pro/docs/privileges-and-deprecations) and [Classic](https://developer.jamf.com/jamf-pro/docs/classic-api-minimum-required-privileges-and-endpoint-mapping) API Privilege Requirements -- The principle of least privilege encourages us to grant minimum-possible permissions to our applications. You can look up required permission settings for each API endpoint in these reference tables. 

- [Scalability](https://developer.jamf.com/jamf-pro/docs/jamf-pro-api-scalability-best-practices) -- Advice on ensuring your API consumption doesn't impact the Jamf Pro application's core device management functions. 
- [Optimistic Locking](https://developer.jamf.com/jamf-pro/docs/optimistic-locking) -- Applications often read a record (e.g. to display some data) then write an update back (e.g. because the user edited the data). Optimistic locking give developers a way to make sure that the record wasn't updated by some other process between the read and write on a particular client. 

**Swagger Sandbox**

The Jamf Pro Application exposes Swagger documentation at https://your-instance.jamfcloud.com/api. Swagger pages show the different variations and http methods for each endpoint. Many include a code example, example responses, and available parameters. You can use the test functions to try the commands on your own data before you start programming.

**Postman Collection**  

The Postman application can be used to explore API functions. A collection for the Jamf Pro API is available [here](https://developer.jamf.com/title-editor/docs/postman-collection). 

**Open API Specification**

The Open API Specification includes a schema language for describing API endpoints and their output. Developer tools can consume the specification to automatically generate API clients and data models. You can obtain a copy of the current schema from your own Jamf Pro instance at http://your-instance.jamfcloud.com/api/schema. A member of the user community has published [a helpful blog post](https://bryson3gps.wordpress.com/2024/08/26/using-the-swift-openapi-generator-for-the-jamf-pro-api/) describing the use of the schema for accelerating Swift application development. 

**Writing call-backs**

Event-driven workflows can be triggered by setting up a [Webhook](https://developer.jamf.com/jamf-pro/docs/webhooks-1) in Jamf Pro. For example, your application could recieve a notification that a new device has been enrolled and use it's inventory data to update an asset management or help desk system in real-time. 

## Learning Resources

**Jamf-provided self-paced online learning courses**

[Bash Scripting Foundations](https://trainingcatalog.jamf.com/path/bash-scripting-foundations)

[Bash Scripting Automation and API](https://trainingcatalog.jamf.com/path/bash-scripting-automation-and-api)

**Instructor-lead Courses**

Jamf offers formal training courses for those wno prefer a more structured learning and certification path. The [Jamf 300 course](https://www.jamf.com/training/online-training/remote-300/) moves beyond the web console to include API and scripting content while the [Jamf 400 curriculum](https://www.jamf.com/training/online-training/remote-400/) requires participants to employ more advanced API scripting concepts in many of it's excercises. 

**Jamf Nation User Conference (JNUC)**

The Jamf User community presents API-related sessions at our annual user conference and other MacAdmin confere. Many are instructional in nature, or they demonstrate typical applications for using APIs with Jamf Products. 

[The Jamf API Ecosystem | JNUC 2022](https://www.jamf.com/resources/videos/the-jamf-api-ecosystem/)

[An introduction to the Classic API | JNUC 2021](https://www.jamf.com/resources/videos/an-introduction-to-the-classic-api/)

[Extracting data from Jamf Pro: Hints, Tips and Tricks | JNUC 2023](https://www.youtube.com/watch?v=LZmtmlBX0bE)

[Jamf API CLI Tool: One Solution for Secure Jamf API Access in Policies and Scripts | JNUC 2024](https://www.youtube.com/watch?v=cbGIBrWxJIw&t=3s)

[Use Swift with the Jamf API | JNUC 2022](https://www.youtube.com/watch?v=bZj1wYtOCQI)

[Jamf Pro API Wrapper | JNUC 2023](https://www.youtube.com/watch?v=pyf7bGgHpP4)

##  Software Development Kits ("SDKs"), Wrapper Functions, and Application Templates

Some developer may prefer to code entirely from scratch because they alreaday have generic libraries they like to use when interfacing with APIs, or because they want to learn by doing, or because they prefer not to introduce external code into their projects. But many developers find that starting with a purpose-built  code library cuts their development time and makes their solutions more consistent and reliable. 

There is no "best" approach. Developers working with Jamf APIs range from highly-sophisocated software engineers through beginners who are just starting with simple shell scripts. Each of the solutions listed below seeks to solve a different set of problems and may go about it in different ways. A few examples of things that an SDK can handle for you include:

- Handling logins -- For example, you could provide an API key and secret and the library will take care of making sure it applied an unexpired access token any time you make an API call. 
- Simplified pagination -- Some API endpoints are capable of returning large quantities of data. *Pagination* is a common API technique where a series of calls is made to an endpoint to retrieve a full result set. A helper function can handle all of that for you. 
- Repsponse formats -- XML, JSON, CSV, etc.  
- Error handling -- Terminating a program or returning meaningful error messages based on context

#### Python

Perhaps owing to it's popularity at the time most early utilities were being written, and because at that time it still came pre-installed on macOS, Python is widely used by systems programmers in the MacAdmins commutity. 

A number of community members have shared their Python projects with our user community. Look through the project readmes and/or take them for a test-drive to see which one best matches your requirements and preferences around style and approach.  

**[ Jamf Pro API Wrapper](https://gitlab.com/cvtc/appleatcvtc/jps-api-wrapper)**

Bryan Weber / Chippewa Valley Technical College's project offers convenience functions, especially around authentication and pagination. It also abstracts some common object types so, for example, you can just ask for things like mobile devices without knowing anything about the underlying REST endpoints being used. 

```python
# Print a list of all mobile devices

from os import environ
from jps_api_wrapper.pro import Pro, paginate

JPS_URL = "https://example.jamfcloud.com"
USERNAME = environ["JPS_USERNAME"]
PASSWORD = environ["JPS_PASSWORD"]

with Pro(JPS_URL, USERNAME, PASSWORD) as pro:
    print(paginate(pro.get_mobile_devices))

```

**[Jamf Pro SDK for Python](https://github.com/macadmins/jamf-pro-sdk-python)**

This package from Bryson Tyrell / Amazon and published by the MacAdmins Foundation has some of the same basic authentication wrappers but adds a few more advanced features such as support for customer authentication providers and additional options for securing secrets at rest. Rather than creating abstractions for Jamf Pro application models, it leaves specifying the actual API endpoint used by a request to you. 

```python
from jamf_pro_sdk import JamfProClient, BasicAuthProvider
from jamf_pro_sdk.clients.pro_api.pagination import FilterField, SortField

client = JamfProClient(
    server="dummy.jamfcloud.com",
    credentials=BasicAuthProvider("demo", "tryitout")
)

response = client.pro_api.get_computer_inventory_v1(
    sections=["GENERAL", "USER_AND_LOCATION", "OPERATING_SYSTEM"],
    page_size=1000,
    sort_expression=SortField("id").asc(),
    filter_expression=FilterField("operatingSystem.version").lt("13.")
)

```



**[python-jamf](https://github.com/univ-of-utah-marriott-library-apple/python-jamf)**

This project from the team at the University of Utah can be used to access Jamf Pro's Classic API. It implments a class with variables and methods that map directly to the Jamf Pro API. It handles URL requests, authentication, and convertion of XML/JSON API responses to Python dictionaries/lists.

```python
import python_jamf

for computer in jamf.Computers(): # Retreive the data from the server
	print(computer.data["general"]["last_contact_time"])

computers = jamf.Computers()      # Use the data retrieved above, don't re-download
computers.refresh()               # Re-download the records from the server
if "1" in computers:
    print(computers.recordWithId(1).data['general']['last_contact_time'])

if "Jimmy's Mac" in computers:
    print(computers.recordWithName("Jimmy's Mac").data['general']['last_contact_time'])
    
for computer in computers.recordsWithRegex("J[ia]m[myes]{2}'s? Mac"): # Matches Jimmy's, James', and James's
	print(computer.data["general"]["last_contact_time"])

computer = computers.recordWithName("James's Mac)
if computer:
	computer.refresh()            # Re-download the record from the server
	computer.data['general']['name'] = "James' Mac"
	computer.save()

# Delete a record
computer = computers.recordWithName("Richard's Mac)
if computer:
	computer.delete()
```



**Golang**

[deploymenttheory](https://github.com/deploymenttheory)/**[go-api-sdk-jamfpro](https://github.com/deploymenttheory/go-api-sdk-jamfpro)**

Highly-flexible SDK with extensive examples for seemingly every available Jamf Pro API operations. 

```go
package main

import (
	"encoding/json"
	"fmt"
	"log"
	"github.com/deploymenttheory/go-api-sdk-jamfpro/sdk/jamfpro"
)

func main() {
	// Define the path to the JSON configuration file
	configFilePath := "/Users/dafyddwatkins/localtesting/jamfpro/clientconfig.json"

	// Initialize the Jamf Pro client with the HTTP client configuration
	client, err := jamfpro.BuildClientWithConfigFile(configFilePath)
	if err != nil {
		log.Fatalf("Failed to initialize Jamf Pro client: %v", err)
	}
	
	// Call the GetComputersInventory function
	inventoryList, err := client.GetComputersInventory("")
	if err != nil {
		log.Fatalf("Error fetching computer inventory: %v", err)
	}
	
	// Pretty print the response
	prettyJSON, err := json.MarshalIndent(inventoryList, "", "    ")
	if err != nil {
		log.Fatalf("Failed to generate pretty JSON: %v", err)
	}
	fmt.Printf("%s\n", prettyJSON)
}
```





## Developing Automation Solutions

Increasingly, organizations prefer to implement IT operations via code or configuration rather than making changes directly in an application GUI. In this approach, a desired state is defined, typically in a YAML file, and the file is comitted to a GIT branch along with a pull request. A review and approval workflow is followed and the change is merged to a branch where an automated action implements the change in Jamf Pro via an API. 

**Deployment Theory Terraform Provider for Jamf Pro**

[terraform-provider-jamfpro](https://github.com/deploymenttheory/terraform-provider-jamfpro)

**Software Distribution Workflows**

The [Jamf Sync](https://github.com/jamf/JamfSync#command-line-parameters) project includes a command line option to assist those wishing to develop CI/CD pipelines for software distribution via the Jamf Cloud Distribution Service.  
