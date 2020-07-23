import requests
# import json

# Fill in your values for these settings...
jamfpro_url = "https://my.jamfcloud.com"
# [!] Credentials should be in .netrc or env vars for production use.
# Putting them here for now to simplify demo setup.
jamfpro_username = "service_api_read_only_account"
jamfpro_password = "very complex password"
jamfpro_report = "Splunk App Usage Report"
app_usage_date_range = "2020-04-16_2020-07-16"
splunk_hec_url = "https://splunk.my.co:8088/services/collector/raw"
splunk_hec_auth_token = "zzzzzzzz-46da-49e2-a9bd-zzzzzzzzzzzz"


def get_jamfpro_computers():
    print("[step] Retrieving computer info from Jamf Pro")
    jamfpro_report_encoded = requests.utils.quote(jamfpro_report)
    api_endpoint = f"{jamfpro_url}/JSSResource/advancedcomputersearches/name/{jamfpro_report_encoded}"
    headers = {'Accept': 'application/json'}
    r = requests.get(api_endpoint, headers=headers, auth=(jamfpro_username, jamfpro_password))
    print("Advanced Search retrieval HTTP Response Code : ", r.status_code)
    computers_json = r.json()['advanced_computer_search']['computers']
    return computers_json


def send_application_usage_to_splunk(computers_json):
    index = 0
    limit = 1000
    for computer_json in computers_json:
        # print(json.dumps(computer_json, sort_keys=False, indent=4, separators=(',', ': ')))
        computer_id = str(computer_json['id'])
        api_endpoint = f"{jamfpro_url}/JSSResource/computerapplicationusage/id/{computer_id}/{app_usage_date_range}"
        headers = {'Accept': 'application/json'}
        r = requests.get(api_endpoint, headers=headers, auth=(jamfpro_username, jamfpro_password))
        print(f"[debug] HTTP GET on computer usage for computer ID \"{computer_id}\" HTTP Status: ", r.status_code)
        usage_json = r.json()
        if not usage_json["computer_application_usage"]:
            print("[debug][skip] No app usage data available for this computer")
        else:
            computer_json["usage"] = usage_json['computer_application_usage']
            # print("[debug] JSON Data:\n", json.dumps(computer_json, sort_keys=False, indent=2, separators=(',', ': ')))
            print(f"splunk_hec_url: {splunk_hec_url}")
            r = requests.post(url=splunk_hec_url, headers=headers, json=computer_json, auth=('', splunk_hec_auth_token))
            print(f"[debug] Splunk Post HTTP Status: ", r.status_code)
            print("Splunk HEC response:\n", r.text)
        index += 1
        if index == limit:
            break


computers_json = get_jamfpro_computers()
send_application_usage_to_splunk(computers_json)
print('[done]')
