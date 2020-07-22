import requests
import json
from datetime import datetime


# Settings...

# Fill in your values for these settings...
# jamfpro_url will be something like "https://my.jamfcloud.com" or "https://jamf.my.org:8443"
# Do not include a trailing "/" in the URL.
jamfpro_url = "https://my.jamfcloud.com"
# [!] Credentials should be in .netrc or env vars for production use.
# Putting them here for now to simplify demo setup.
jamfpro_username = "service_splunk_api_audit_only_user"
jamfpro_password = "my very good password"
jamfpro_report = "Splunk Computer History Report"
# splunk_HTTP Event Collector
# Ref: https://docs.splunk.com/Documentation/Splunk/latest/Data/UsetheHTTPEventCollector
#  "https://splunk.my.org:8088/services/collector/raw" for Enterprise
#  "https://http-inputs-hec.splunkcloud.com:443/services/collector/event" for Splunk Web
splunk_hec_url = "https://splunk.my.org:8088/services/collector/raw"
splunk_hec_auth_token = "zzzzzz-a83f-4eca-ab0b-zzzzzzzzzzzz"


# Code follows...

def get_jamfpro_computers():
    print("[step] Retrieving computer info from Jamf Pro")
    jamfpro_report_encoded = requests.utils.quote(jamfpro_report)
    api_endpoint = f"{jamfpro_url}/JSSResource/advancedcomputersearches/name/{jamfpro_report_encoded}"
    print(f"GET {api_endpoint}")
    headers = {'Accept': 'application/json'}
    r = requests.get(api_endpoint, headers=headers, auth=(jamfpro_username, jamfpro_password))
    # print("Advanced Search retrieval HTTP Response Code : ", r.status_code)
    # print("Advanced Search response text : \n", r.text)
    my_computers_json = r.json()['advanced_computer_search']['computers']
    return my_computers_json


def upload_data_to_splunk(page_json):
    # print("[debug] JSON Data:\n", json.dumps(page_json, sort_keys=False, indent=2, separators=(',', ': ')))
    # print(f"splunk_hec_url: {splunk_hec_url}")
    r = requests.post(url=splunk_hec_url, json=page_json, auth=('', splunk_hec_auth_token))
    # print(f"[debug] Splunk Post HTTP Status: ", r.status_code)
    # print("[debug] Splunk HEC response:\n", r.text)


def split_data_then_upload(computers_json):
    index = 0
    limit = 200
    pages_list = ["computer_usage_logs", "audits", "policy_logs", "casper_remote_logs", "screen_sharing_logs",
                  "casper_imaging_logs", "commands", "mac_app_store_applications"]
    # I removed "user_location" from the list. Lotta data. Doesn't seem too useful.
    for computer_json in computers_json:
        # print("[debug] \n", json.dumps(computer_json, sort_keys=False, indent=4, separators=(',', ': ')))
        computer_id = str(computer_json['id'])
        api_endpoint = f"{jamfpro_url}/JSSResource/computerhistory/id/{computer_id}"
        headers = {'Accept': 'application/json'}
        r = requests.get(api_endpoint, headers=headers, auth=(jamfpro_username, jamfpro_password))
        print(f"[debug] HTTP GET on computer history for computer ID \"{computer_id}\" HTTP Status: ", r.status_code)
        history_json = r.json()
        if not history_json["computer_history"]:
            print("[debug][skip] No history data available for this computer")
        else:
            del history_json["computer_history"]["general"]
            for page in pages_list:
                if not history_json["computer_history"][page]:
                    """Nothing to do"""
                    print(f"[debug][skip] No history data available for \"{page}\"")
                else:
                    page_json = computer_json.copy()
                    page_json["computer_history"] = {}
                    page_json["computer_history"][page] = history_json["computer_history"][page]
                    page_json["computer_history"]["type"] = page
                    if page == "policy_logs":
                        for element in page_json["computer_history"][page][:]:
                            if "policy_name" in element:
                                if element["policy_name"] == "Update Inventory":
                                    # There'll be a ton of them and they're not that interesting.
                                    page_json["computer_history"][page].remove(element)
                                else:
                                    if 'date_completed' in element:
                                        del element['date_completed']
                                    if 'date_completed_epoch' in element:
                                        del element['date_completed_epoch']
                    elif page == "user_location":
                        for element in page_json["computer_history"][page]:
                            if 'date_time' in element:
                                del element['date_time']
                            if 'date_time_epoch' in element:
                                del element['date_time_epoch']
                    elif page == "commands":
                        mdmcommands = []
                        command_status_list = ["completed", "pending", "failed"]
                        for status in command_status_list:
                            for element in page_json["computer_history"][page][status][:]:
                                if "name" in element:
                                    command_skip_list = ["DeviceInformation", "ProfileList", "CertificateList", "InstalledApplicationList", "UserList", "ContentCachingInformation", "SecurityInfo"]
                                    if element["name"] in command_skip_list:
                                        # There'll be a ton of them and they're not that interesting.
                                        page_json["computer_history"][page][status].remove(element)
                                    else:
                                        delete_keys_list = ["completed", "completed_epoch", "issued", "issued_epoch", "last_push", "last_push_epoch"]
                                        for delete_key in delete_keys_list:
                                            if delete_key in element:
                                                del element[delete_key]
                                        element["status"] = status
                                        time_keys_list = ["issued_utc", "last_push_utc", "completed_utc"]
                                        for time_key in time_keys_list:
                                            if time_key in element:
                                                t_val = element[time_key]
                                                utc_date_time_obj = datetime.strptime(t_val[0:18], '%Y-%m-%dT%H:%M:%S')
                                                element[time_key] = utc_date_time_obj.strftime('%Y-%m-%d %H:%M:%S')
                                        # I want to pull the command items down a level
                                        mdmcommands.append(element.copy())
                        page_json["computer_history"]["command_list"] = mdmcommands
                        del page_json["computer_history"]["commands"]

                    elif page == "mac_app_store_applications":
                        if not history_json["computer_history"]["mac_app_store_applications"]["installed"] and not history_json["computer_history"]["mac_app_store_applications"]["pending"] and not history_json["computer_history"]["mac_app_store_applications"]["failed"]:
                            print(f"[debug][skip] No history data available for \"{page}\"")
                            continue

                    print(f"[debug] JSON feed for \"{page}\" :\n", json.dumps(page_json, sort_keys=False, indent=4, separators=(',', ': ')))

                    upload_data_to_splunk(page_json)

        index += 1
        if index == limit:
            break


computers_json = get_jamfpro_computers()
split_data_then_upload(computers_json)
print('[done]')
