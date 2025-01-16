# Resources for Jamf Pro API developers

This document is a round-up of offerings that can speed up the learning and development cycle for people wishing to interact with Jamf's APIs. Some are provided by Jamf while others demonstrate the commitment and generousity of the Jamf Nation user community. 

*Corrections and suggestions for new listings are appreciated. Email concepts at jamf or submit a PR/issue.*


&nbsp;

## Documentation

Jamf Pro's [API Documentation Landing Page](https://developer.jamf.com/jamf-pro/docs/) is the gateway to the endpoint specification pages and also includes articals general topics related to using the API. The site includes coverage of our older but still supported "[Classic](https://developer.jamf.com/jamf-pro/reference/classic-api)" API endpoints and also our newer "[Jamf Pro](https://developer.jamf.com/jamf-pro/docs/jamf-pro-api-overview)" API. These are explained in [Which API Should I Use?](https://developer.jamf.com/jamf-pro/docs/which-api-should-i-use)

&nbsp;

**REST Endpoint Reference Documentation**

- [Classic](https://developer.jamf.com/jamf-pro/reference/classic-api) Endpoints
- [Jamf Pro](https://developer.jamf.com/jamf-pro/reference/jamf-pro-api) Endpoints


&nbsp;

**Commonly-Referenced Topic Pages from the Jamf Developers's WebSite**

- Authentication -- [Client Credentials](https://developer.jamf.com/jamf-pro/docs/client-credentials)
- [Session Stickiness for Jamf Cloud](https://developer.jamf.com/jamf-pro/docs/sticky-sessions-for-jamf-cloud) -- Jamf Cloud hosts application server in a multi-server/load-balanced configuration. If you write a new record via the API and immediately attempt to write another record that had the first one as a dependency, your second update might fail if it hits a different server and the initial update hasn't finished syncronizing across all cluster instances. Session stickiness ensures that related updates are all handled by a single server instance, avoiding this problem area. 
- [Filtering with RSQL](https://developer.jamf.com/jamf-pro/docs/filtering-with-rsql) -- Some REST API endpoints allow the use of filters to retrieve data subsets. For example, you could request a list of all the computers assigned to a specific department. This is often more efficient that retrieving all the data and performing queries in your application. 
- [Jamf Pro](https://developer.jamf.com/jamf-pro/docs/privileges-and-deprecations) and [Classic](https://developer.jamf.com/jamf-pro/docs/classic-api-minimum-required-privileges-and-endpoint-mapping) API Privilege Requirements -- The principle of least privilege encourages us to grant minimum-possible permissions to our applications. You can look up required permission settings for each API endpoint in these reference tables. 
- [Scalability](https://developer.jamf.com/jamf-pro/docs/jamf-pro-api-scalability-best-practices) -- Advice on ensuring your API consumption doesn't impact the Jamf Pro application's core device management functions. 
- [Optimistic Locking](https://developer.jamf.com/jamf-pro/docs/optimistic-locking) -- Applications often read a record (e.g. to display some data) then write an update back (e.g. because the user edited the data). Optimistic locking give developers a way to make sure that the record wasn't updated by some other process between the read and write on a particular client. 


&nbsp;

**Swagger Docs** 

- The Jamf Pro Application exposes Swagger documentation at https://your-instance.jamfcloud.com/api. Swagger pages show the different variations and http methods for each API endpoint. Many include a code example, example responses, and available parameters. You can use the test functions to try the commands on your own data before you start adding them to your code. 


&nbsp;

**Postman Collection**  

- Like the Swagger docs, the Postman application can be used to explore API functions. A collection for the Jamf Pro API is available [here](https://developer.jamf.com/title-editor/docs/postman-collection). 


&nbsp;

**Open API Specification**

- The Open API Specification includes a schema language for describing API endpoints and their output. Developer tools can consume the specification to automatically generate API clients and data models. You can obtain a copy of the current schema from your own Jamf Pro instance at http://your-instance.jamfcloud.com/api/schema. A member of the user community has published [a helpful blog post](https://bryson3gps.wordpress.com/2024/08/26/using-the-swift-openapi-generator-for-the-jamf-pro-api/) describing the use of the schema for accelerating application development. 


&nbsp;
&nbsp;

## Learning Resources


&nbsp;

**Jamf-provided self-paced online learning modules**

- [Bash Scripting Foundations](https://trainingcatalog.jamf.com/path/bash-scripting-foundations)
- [Bash Scripting Automation and API](https://trainingcatalog.jamf.com/path/bash-scripting-automation-and-api)


&nbsp;

**Instructor-lead Courses**

- Jamf offers formal training courses for those wno prefer a more structured learning and certification path. The [Jamf 300 course](https://www.jamf.com/training/online-training/remote-300/) moves beyond the web console to include API and scripting content while the [Jamf 400 curriculum](https://www.jamf.com/training/online-training/remote-400/) requires participants to employ more advanced API scripting concepts in many of it's excercises. 


&nbsp;

**Blog Posts**

A number of community members have published some helpful information in their blogs. This is just a sample of a couple that deal with authentication. Many others can be found with a Google. 

- [Understanding Jamf Pro API Roles and Clients | Graham Pugh](https://www.jamf.com/blog/understanding-jamf-pro-api-roles-and-clients/)
- [How to convert Classic API scripts to use bearer token authentication](https://community.jamf.com/t5/tech-thoughts/how-to-convert-classic-api-scripts-to-use-bearer-token/ba-p/273910)


&nbsp;

**Conference Presentations**

Members of the Jamf User community often present API-related sessions during our annual Jamf Nation User Conference (JNUC) and other MacAdmin conferences. Many are instructional in nature, or they demonstrate clever applications of Jamf's product APIs. 

- [The Jamf API Ecosystem | JNUC 2022](https://www.jamf.com/resources/videos/the-jamf-api-ecosystem/)
- [An introduction to the Classic API | JNUC 2021](https://www.jamf.com/resources/videos/an-introduction-to-the-classic-api/)
- [Extracting data from Jamf Pro: Hints, Tips and Tricks | JNUC 2023](https://www.youtube.com/watch?v=LZmtmlBX0bE)
- [Jamf API CLI Tool: One Solution for Secure Jamf API Access in Policies and Scripts | JNUC 2024](https://www.youtube.com/watch?v=cbGIBrWxJIw&t=3s)
- [Use Swift with the Jamf API | JNUC 2022](https://www.youtube.com/watch?v=bZj1wYtOCQI)
- [Jamf Pro API Wrapper | JNUC 2023](https://www.youtube.com/watch?v=pyf7bGgHpP4)
- [Mastering Serialized Data | JNUC 2024](https://youtu.be/iHNt2Wc750o?si=9OAlMVQGTu_WdAfb)


&nbsp;

**AI**

Sometimes AI can do a shockingly good job of solving an entire scripting problem, or it can get you through a challenging component of a larger project. But beware! Regardless of the source, executing a script you don't fully understand may be a recipie for disaster. 

&nbsp;
&nbsp;

##  Software Development Kits ("SDKs"), Wrapper Functions, and Application Templates

Some developer may prefer to code entirely from scratch because they alreaday have generic libraries they like to use when interfacing with APIs, or because they want to learn by doing, or because they prefer not to introduce external code into their projects. But many developers find that starting with a purpose-built  code library cuts their development time and makes their solutions more consistent and reliable. 

There is no "best" approach. Developers working with Jamf APIs range from highly-sophisocated software engineers through beginners who are just starting with simple shell scripts. Each of the solutions listed below seeks to solve a different set of problems and may go about it in different ways. A few examples of things that an SDK can handle for you include:

- Authentication -- Exchanging an API key and secret for an access token. Most of these libraries will take care of making sure the token is kept current and added to any API calls made by your program. 
- Simplified pagination -- Some API endpoints could use a technique called *Pagination* to break very large blobs of data up into managaable chunks that are delivered to the client one page at a time. Many SDKs will provide a tool to take care of making all the sequential page calls needed to retrieve a full result set. 
- Repsponse formats -- Normalizing XML, JSON, CSV, etc. into a language-specific data structure like an array or dictionary.   
- Error handling -- Throwing a terminating error or returning meaningful error messages back to the calling procedure based on context

&nbsp;

#### Python

Python is widely used by systems programmers in the MacAdmins commutity. 

A number of community members have shared their Python projects. Look through the project readmes and/or take them for a test-drive to see which one best matches your requirements and preferences for style and approach.  

&nbsp;

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

&nbsp;

**[Jamf Pro SDK for Python](https://github.com/macadmins/jamf-pro-sdk-python)**

This package from Bryson Tyrell / Amazon and published by the MacAdmins Foundation has some of the same basic authentication wrappers but adds a few more advanced features such as support for custom authentication providers and additional options for securing secrets at rest. Rather than creating abstractions for Jamf Pro application models, it leaves you free to specify the actual API endpoint when making a request. 

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

&nbsp;

**[python-jamf](https://github.com/univ-of-utah-marriott-library-apple/python-jamf)**

This project from the team at the University of Utah can be used to access Jamf Pro's Classic API. It implments a class with variables and methods that closely mirror the underlying API structures. It handles URL requests, authentication, and convertion of XML/JSON API responses to Python dictionaries/lists.

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

&nbsp;

**Golang**

[deploymenttheory](https://github.com/deploymenttheory)/**[go-api-sdk-jamfpro](https://github.com/deploymenttheory/go-api-sdk-jamfpro)**

Highly-flexible SDK with extensive examples for seemingly every available Jamf Pro API option. 

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

&nbsp;

**Ruby**

[PixarAnimationStudios](https://github.com/PixarAnimationStudios)/**[ruby-jss](https://github.com/PixarAnimationStudios/ruby-jss)**

ruby-jss defines a Ruby module used to access the 'Classic' and 'Jamf Pro' APIs of a Jamf Pro server. The `Jamf` module maintains connections to both APIs simultaneously, and uses whichever is appropriate as needed. Details like authentication tokens, token refreshing, JSON and XML parsing, and even knowing which resources use which API are all handled under-the-hood. The Jamf module abstracts many API resources as Ruby objects, and provides methods for interacting with those resources. It also provides some features that aren't a part of the API itself, but come with other Jamf-related tools, such as uploading {Jamf::Package} files to the primary fileshare distribution point, and the installation of those objects on client machines. 

```ruby
require 'ruby-jss'

# Connect to the API
Jamf.cnx.connect "https://#{jamf_user}:#{jamf_pw}@my.jamf.server.com/"

# get an array of basic data about all Jamf::Package objects in Jamf Pro:
pkgs = Jamf::Package.all

# get an array of names of all Jamf::Package objects in the Jamf Pro:
pkg_names = Jamf::Package.all_names

# Get a static computer group. This creates a new Ruby object
# representing the existing Jamf computer group.
mac_group = Jamf::ComputerGroup.fetch name: "Macs of interest"

# Add a computer to the group
mac_group.add_member "pricklepants"

# save changes back to the server
mac_group.save

# Create a new network segment to store on the server.
# This makes a new Ruby Object that doesn't yet exist in Jamf Pro.
ns = Jamf::NetworkSegment.create(
  name: 'Private Class C',
  starting_address: '192.168.0.0',
  ending_address: '192.168.0.255'
)

# Associate this network segment with a specific building,
# which must exist in Jamf Pro, and be listed in Jamf::Building.all_names
ns.building = "Main Office"

# Associate this network segment with a specific software update server,
# which must exist in Jamf Pro, and be listed in Jamf::SoftwareUpdateServer.all_names
ns.swu_server = "Main SWU Server"

# save the new network segment to the server
ns.save
```

&nbsp;

**Shell Scripts**

The vast majority of Apple device admins come to the field as non-programmers. But inevetably, some of us notice that some frequent tasks is getting repitious and we start dipping our toes into scripting. Given macOS's Unix underpinnings, these first attempts are usually written as shell scripts. The free self-paced learning modules from Jamf's Customer Education team mentioned above are a great place to start your adventure. There are hundreds of example shell scripts easily discoverable via Google and the members of the #scripting channel on Mac Admins Slack are unceasingly helpful. So start small and build as you go, learning all the way. 

An API Helper bash script is available [here](https://github.com/jamf/ol/blob/master/api/jamfpro/jamfProApiHelper/jamfProApiHelper.sh). It's aimed at self-tought scripters who might be looking for more best practices and new approaches for some common shell scripting challenges. The API Helper script demonstrates the following concepts:

- Named function parameters
- Variable scope in bash
- Calling functions and assigning output to a variable
- Returning multiple values from functions (albeit in global vars)
- Options to log to file or stdout
- Use of curl timeouts
- How to handle http session cookies
- Returning http status for API calls
- Getting API credentials from keychain
- Handles Jamf Pro API auth for you, i.e., fetches auth tokens as needed
- Refreshing auth tokens as they near expiration/Clearing them when done.
- Error messages relevant to the Jamf Pro API
- Demonstrate how to parse out data elements
- Convert child object data (e.g. lists of computer IDs) to iterable arrays
- Extract data from json via XPath. (Consider using jq instead.)```

Many find they can solve lots of problems quite nicely with a shell script and will never need anything more. But if you're using many of the techniques from the bash API Helper, it's likely time to bite the bullet and graduate to Python or another more modern language. Note that the API helper script uses functions from the [Get API Credentials](https://github.com/jamf/ol/tree/master/api/jamfpro/getJamfApiCredentials) project to read API authentication secrets from options like environment variables or keychain so you can avoid the strongly-discouraged practice of putting them in your scripts in plaintext. 

&nbsp;

**PowerShell**

Powershell is an extremely popular language for system administrators. We don't know of a published SDK, but a handly function for handling API auth bearer tokens is available [here](https://github.com/jamf/ol/blob/master/api/jamfpro/jamfProApiHelper/jamfProApiHelper.ps1)


&nbsp;
&nbsp;

## Developing Automation Solutions

&nbsp;

**Webhooks**

You can trigger external actions by setting up a [Webhook](https://developer.jamf.com/jamf-pro/docs/webhooks-1) in Jamf Pro. For example, your application could recieve a notification that a new device has been enrolled. In response, it might fetch the device's full inventory data via the Jamf Pro API and use the information to update an asset management or help desk system in real-time. These kinds of arrangements are sometimes called "event-driven workflows" or "callbacks".

&nbsp;

**Jamf Pro Actions for Apple Shortcuts**

Apple's Shortcuts app allows even a non-programmer to link actions and logic to create a workflow. This Action set makes it easy to include API interactions with a Jamf Pro server. Many clever automations are possible, especially when actions or triggers from Apple Configurator are included. For example, a cart of shared devices could be attached to a workstation that allows a student or shift-worker to identify the device with the best battery charge and check out the device. A Jamf Action can run to assign the device to the user and automatically deploy the apps and configurations appropriate to their roll or class. When the device is returned to the charging station, an action can reset the device, staging it for the next user. 

[Actions for Shortcuts Project Page](https://github.com/Jamf-Concepts/actions)



<br />
<br />

## Configuration by Code: Continuous Integration / Continuous Deployment (CI/CD) Pipelines

<br />

**Deployment Theory Terraform Provider for Jamf Pro**

An increasing number of organizations prefer to implement changes via code or configuration definition files rather than letting a human make changes directly in an application's GUI console. In this approach, a desired state is defined, typically in a YAML file or another well-structured format, and the file is comitted to a GIT branch. A pull request is submitted to iniitate a review and approval workflow, followed by a sequence of merges to a branch where an automated action implements the change in Jamf Pro via an API. These techniques can also be used to move a change through test and user acceptance testing before anything happens in production where it will impact an entire fleet. This Terraform Provider project has extensive coverage of the data models exposed by Jamf Pro's APIs. 

[terraform-provider-jamfpro](https://github.com/deploymenttheory/terraform-provider-jamfpro)

&nbsp;

**Software Distribution Workflows**

Another example is the area of software deployment and patch. An automation can move apps and installers from a staging repository into your software distribution servers and update Jamf Pro to make the software available to devices. 

- The [Jamf Sync](https://github.com/jamf/JamfSync#command-line-parameters) project includes a command line option to assist those wishing to develop CI/CD pipelines for software distribution via the Jamf Cloud Distribution Service. A number of other scripts and utilities for syncing files to software distribution points are easily located via Google.  
