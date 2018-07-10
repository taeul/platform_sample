#!/bin/sh
#/
#/ NAME:
#/ delete-empty-repos - For a GitHub Enterprise Instance, lists every empty repository
#/ in format <organization>:<repository> and deletes them if option is passed.
#/
#/ SYNOPSIS:
#/ delete-empty-repos.sh [--org=MyOrganization] [--execute=TRUE]
#/
#/ DESCRIPTION:
#/ For a GitHub Enterprise Instance, lists every empty repository in format
#/ <organization>:<repository> separated by new lines. Deleting them if passed
#/ the option [--execute=true].
#/   - Example Output: List all empty repositories
#/     <organization>:<repository1>
#/     <organization>:<repository2>
#/     <organization>:<repository3>
#/
#/ PRE-REQUISITES:
#/ Before running this script, you must create a Personal Access Token (PAT)
#/ at https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/
#/ with the permissions <repo> and <admin:org> scopes and <delete_repo>. Read more
#/ about scopes here: https://developer.github.com/apps/building-oauth-apps/scopes-for-oauth-apps/
#/
#/ Once created, you must export your PAT as an environment variable
#/ named <GITHUB_TOKEN>.
#/   - Exporting PAT as GITHUB_TOKEN
#/   $ export GITHUB_TOKEN=abcd1234efg567
#/
#/ Additionally you will need to set the $API_ROOT at the top of the script to
#/ your instance of GitHub Enterprise.
#/  - _i.e._: https://MyGitHubEnterprise.com/api/v3
#/
#/ OPTIONS:
#/ --org
#/ -o
#/ When running the tool, this flag sets which organization's repositories you
#/ want to inspect and delete (if they're empty).
#/
#/ --execute
#/ -e
#/ When running the tool, this flag will delete every repo listed.
#/   * _NOTE:_ You should run the script without this option first, verifying
#/      that you want to delete every repository listed.
#/
#/ EXAMPLES:
#/
#/   - Lists all empty repositories for the given organization.
#/   $ bash delete-empty-repos.sh --org=MyOrganization
#/
#/   - Deletes all empty repositories for the given organization.
#/   $ bash delete-empty-repos.sh --org=MyOrganization --execute=TRUE
#/
#/ API DOCUMENTATION:
#/ All documentation can be found at https://developer.github.com/v3/

echo ""
echo "#######################################"
echo "#     ____                            #"
echo "#    |  _ \ ___ _ __   ___            #"
echo "#    | |_) / _ \ '_ \ / _ \           #"
echo "#    |  _ <  __/ |_) | (_) |          #"
echo "#    |_|_\_\___| .__/ \___/           #"
echo "#   |  _ \ ___ |_| _ _ __   ___ _ __  #"
echo "#   | |_) / _ \/ _| | '_ \ / _ \ '__| #"
echo "#   |  _ <  __/ (_| | |_) |  __/ |    #"
echo "#   |_| \_\___|\__,_| .__/ \___|_|    #"
echo "#                   |_|               #"
echo "#######################################"
echo ""

########
# VARS #
########
API_ROOT="https://<your-domain>/api/v3"
EXECUTE="FALSE"
EMPTY_REPO_COUNTER=0

##################################
# Parse options/flags passed in. #
##################################

for param in "$@"
do
  case $param in
    -e=*|--execute=*)
    EXECUTE="${param#*=}"
    shift
    ;;
    -o=*|--org=*)
    ORG_NAME="${param#*=}"
    shift
    ;;
    *)
    # unknown option, do nothing
    ;;
  esac
done

#################
# Verify Inputs #
#################

# If GITHUB_TOKEN wasn't set in Environment
if [[ -z ${GITHUB_TOKEN} ]]; then
  echo "ERROR: GITHUB_TOKEN was not found in your environment. You must export "
  echo "this token prior to running the script."
  echo "  Ex: EXPORT GITHUB_TOKEN=abc123def456"
  echo ""
  echo "Exiting script with no changes."
  echo ""
  exit 1
fi

# If ORG_NAME wasn't passed
if [[ -z ${ORG_NAME} ]]; then
  echo "ERROR: ORG_NAME was not provided."
  echo "  Ex: bash delete-empty-repos.sh --org=MyOrganization --execute=TRUE"
  echo ""
  echo "Exiting script with no changes."
  echo ""
  exit 1
fi

# If EXECUTE exists, it needs to equal TRUE or FALSE
if [[ ${EXECUTE} != "TRUE" ]] && [[ ${EXECUTE} != "FALSE" ]]; then
    echo "ERROR: EXECUTE was not set to a proper value."
    echo "  Ex: bash delete-empty-repos.sh --org=MyOrganization --execute=TRUE"
    echo ""
    echo "Exiting script with no changes."
    echo ""
    exit 1
fi

if [[ ${EXECUTE} = "TRUE" ]]; then
  echo "Searching for empty repositories within the Organization: "${ORG_NAME}
  echo "EXECUTE was set to TRUE!!! Empty repositories will be deleted!!!"
  echo "You have 5 seconds to cancel this script."
  sleep 5
else
  echo "Searching for empty repositories within the Organization: "${ORG_NAME}
  echo "EXECUTE was set to FALSE, no repositories will be deleted."
fi

##################################################
# Grab JSON of all repositories for organization #
##################################################
echo "Getting a list of the repositories within "${ORG_NAME}

REPO_RESPONSE="$(curl --request GET \
--url ${API_ROOT}/orgs/${ORG_NAME}/repos \
-s \
--header "authorization: Bearer ${GITHUB_TOKEN}" \
--header "content-type: application/json")"

##########################################################################
# Loop through every organization's repo to get repository name and size #
##########################################################################
echo "Generating list of empty repositories."
echo ""
echo "-------------------"
echo "| Empty Repo List |"
echo "| Org : Repo Name |"
echo "-------------------"

for repo in $(echo "${REPO_RESPONSE}" | jq -r '.[] | @base64');
do
  #####################################
  # Get the info from the json object #
  #####################################
  get_repo_info()
  {
    echo ${repo} | base64 --decode | jq -r ${1}
  }

  # Get the info from the JSON object
  REPO_NAME=$(get_repo_info '.name')
  REPO_SIZE=$(get_repo_info '.size')

  # If repository has data, size will not be zero, therefore skip.
  if [[ ${REPO_SIZE} -ne 0 ]]; then
    continue;
  fi

  ################################################
  # If we are NOT deleting repository, list them #
  ################################################
  if [[ ${EXECUTE} = "FALSE" ]]; then
    echo "${ORG_NAME}:${REPO_NAME}"

    # Increment counter
    EMPTY_REPO_COUNTER=$((EMPTY_REPO_COUNTER+1))

  #################################################
  # EXECUTE is TRUE, we are deleting repositories #
  #################################################
  elif [[ ${EXECUTE} = "TRUE" ]]; then
      echo "${REPO_NAME} will be deleted from ${ORG_NAME}!"

      ############################
      # Call API to delete repos #
      ############################
      curl --request DELETE \
         -s \
         --url ${API_ROOT}/repos/${ORG_NAME}/${REPO_NAME} \
         --header "authorization: Bearer ${GITHUB_TOKEN}"

      echo "${REPO_NAME} was deleted from ${ORG_NAME} successfully."

      # Increment counter
      EMPTY_REPO_COUNTER=$((EMPTY_REPO_COUNTER+1))
  fi

done

##################
# Exit Messaging #
##################
if [[ ${EXECUTE} = "TRUE" ]]; then
  echo ""
  echo "Successfully deleted ${EMPTY_REPO_COUNTER} empty repos from ${ORG_NAME}."
else
  echo ""
  echo "Successfully discovered ${EMPTY_REPO_COUNTER} empty repos within ${ORG_NAME}."
fi
exit 0
