#!/bin/sh

set -u
##################################################################
urlencode() (
    i=1
    max_i=${#1}
    while test $i -le $max_i; do
        c="$(expr substr $1 $i 1)"
        case $c in
            [a-zA-Z0-9.~_-])
		printf "$c" ;;
            *)
		printf '%%%02X' "'$c" ;;
        esac
        i=$(( i + 1 ))
    done
)

##################################################################

##################################################################
#Approved commit sha
approvedcommitsha() (
    approved=1
    GITHUB_USERNAME=$1
    BRANCH=$2
    
    
    #API returns latest commit first
    icommit=-1
    while [[ "${approved}" != "0" && "${icommit}" -lt 100 ]]
    do
       icommit=$(($icommit+1))
       commitauthor=$(curl -H "Authorization: token ${SOURCE_PAT}" --silent -H "Accept: application/vnd.github.antiope-preview+json" "https://api.github.com/repos/${SOURCE_REPO}/commits?sha=${BRANCH}&per_page=100" | jq ".[$icommit] | {commitauthor: .author.login}" | jq ".commitauthor")
       if [[ $commitauthor == $GITHUB_USERNAME ]]; then approved=0; fi
       sha=$(curl -H "Authorization: token ${SOURCE_PAT}" --silent -H "Accept: application/vnd.github.antiope-preview+json" "https://api.github.com/repos/${SOURCE_REPO}/commits?sha=${BRANCH}&per_page=100" | jq ".[$icommit] | {sha: .sha}" | jq ".sha" | sed "s/\\\"/\\,/g" | sed s/\[,\]//g)
       ncomments=$(curl -H "Authorization: token ${SOURCE_PAT}" --silent -H "Accept: application/vnd.github.antiope-preview+json" https://api.github.com/repos/${SOURCE_REPO}/commits/$sha/comments | jq length)
       icomment=${ncomments}
       while [[ "${approved}" != "0" && "${icomment}" -gt 0  && ! -z $APPROVAL_STRING ]]
       do
          icomment=$(($icomment - 1))
          commentauthor=$(curl -H "Authorization: token ${SOURCE_PAT}" --silent -H "Accept: application/vnd.github.antiope-preview+json" https://api.github.com/repos/${SOURCE_REPO}/commits/$sha/comments | jq ".[$icomment] | {commentauthor: .user.login}" | jq ".commentauthor")
          approval_comment=1
          curl -H "Authorization: token ${SOURCE_PAT}" --silent -H "Accept: application/vnd.github.antiope-preview+json" https://api.github.com/repos/${SOURCE_REPO}/commits/$sha/comments | jq ".[$icomment] | {body: .body}"  | grep $APPROVAL_STRING -q
	  approval_comment=$?
	  if [[ $commentauthor == $GITHUB_USERNAME && $approval_comment == "0" ]]; then approved=0; fi
       done
    done
    
    if [[ ${approved} == "0" ]]; then printf "$sha"; else printf "nil"; fi
)
##################################################################

##################################################################
branchexists() (
    BRANCH=$1
    #Check if branch for which push/pr testing is requested, exists
    nbranches=$(curl -H "Authorization: token ${SOURCE_PAT}" --silent -H "Accept: application/vnd.github.antiope-preview+json" "https://api.github.com/repos/${SOURCE_REPO}/branches" | jq length)
    branch_exists=1
    ibranch=-1
    while [[ "${branch_exists}" != "0" && "${ibranch}" -lt "${nbranches}" ]]
    do
       ibranch=$(($ibranch+1))
       temp_branch=$(curl -H "Authorization: token ${SOURCE_PAT}" --silent -H "Accept: application/vnd.github.antiope-preview+json" "https://api.github.com/repos/${SOURCE_REPO}/branches" | jq ".[$ibranch] | {branch: .name}" | jq .branch | sed "s/\\\"/\\,/g" | sed s/\[,\]//g)
       if [[ "${temp_branch}" == "${BRANCH}" ]]; then branch_exists=0; fi
    done
    printf "${branch_exists}"
    if [[ "${branch_exists}" != 0 ]]
    then
       #This error needs to go to MIRROR_REPO and not SOURCE_REPO
       echo "Target branch not found, CI job will exit"
       curl -d '{"state":"failure", "context": "'${TARGET_HOSTNAME}'"}' -H "Authorization: token ${SOURCE_PAT}"  -H "Accept: application/vnd.github.antiope-preview+json" -X POST --silent "https://api.github.com/repos/${SOURCE_REPO}/statuses/${sha}"
       exit 1
    fi
)
##################################################################

##################################################################
prapproval() (
    PR_NUMBER=$1
    GITHUB_USERNAME=$2

    approved=1
    
    #Decide whether PR needs to be checked based on REPO_EVENT_TYPE
    base_repo=$(curl --silent -H "Accept: application/vnd.github.antiope-preview+json" https://api.github.com/repos/${SOURCE_REPO}/pulls/${PR_NUMBER} | jq .base.repo.url)
    head_repo=$(curl --silent -H "Accept: application/vnd.github.antiope-preview+json" https://api.github.com/repos/${SOURCE_REPO}/pulls/${PR_NUMBER} | jq .head.repo.url)
    if [[ $REPO_EVENT_TYPE == "internal_pr" ]]
    then
       if [[ $base_repo != $head_repo ]]; then return 1; fi
    else
       if [[ $base_repo == $head_repo ]]; then return 1; fi
    fi
    
    #Find the latest commit date and author
    ncommits=$(curl -H "Authorization: token ${SOURCE_PAT}" --silent -H "Accept: application/vnd.github.antiope-preview+json" https://api.github.com/repos/${SOURCE_REPO}/pulls/${PR_NUMBER}/commits | jq length)
    ncommits=$(($ncommits - 1))
    commitdate=$(curl -H "Authorization: token ${SOURCE_PAT}" --silent -H "Accept: application/vnd.github.antiope-preview+json" https://api.github.com/repos/${SOURCE_REPO}/pulls/${PR_NUMBER}/commits | jq ".[${ncommits}] | {created_at: .commit.author.date}" | jq ".created_at")
    commitauthor=$(curl --silent -H "Accept: application/vnd.github.antiope-preview+json" https://api.github.com/repos/${SOURCE_REPO}/pulls/${PR_NUMBER}/commits | jq ".[${ncommits}] | {commit_author: .author.login}" | jq .commit_author)

    if [[ $commitauthor == $GITHUB_USERNAME ]]; then approved=0; printf "${commitdate}"; fi
    
    #If commit author is not approved, check comments
    #echo "line 105: ${APPROVAL_STRING}"
    echo "line 106: ${REPO_EVENT_TYPE}"
    if [[ ${approved} != "0"  && ! -z $APPROVAL_STRING ]]
    then
       ncomments=$(curl -H "Authorization: token ${SOURCE_PAT}" --silent -H "Accept: application/vnd.github.antiope-preview+json" https://api.github.com/repos/${SOURCE_REPO}/issues/${PR_NUMBER}/comments | jq length)
       approval_comment=1
       icomment=${ncomments}
       while [[ "${approval_comment}" != "0" && "${icomment}" -gt 0 ]]
       do
          icomment=$(($icomment - 1))
          #check comment for string
          curl -H "Authorization: token ${SOURCE_PAT}" --silent -H "Accept: application/vnd.github.antiope-preview+json" https://api.github.com/repos/${SOURCE_REPO}/issues/${PR_NUMBER}/comments | jq ".[$icomment] | {body: .body}" | grep $APPROVAL_STRING -q
          approval_comment=$?
	  commentdate=$(curl -H "Authorization: token ${SOURCE_PAT}" --silent -H "Accept: application/vnd.github.antiope-preview+json" https://api.github.com/repos/${SOURCE_REPO}/issues/${PR_NUMBER}/comments | jq ".[${icomment}] | {created_at: .created_at}" | jq ".created_at")
	  echo "line 116: $approval_comment, $commentdate, $commitdate"
          #if string matches check if commenter belongs to the pre-approved list and the comment is newer than the latest commit
          if [[ "${approval_comment}" = "0" && ${commentdate} > ${commitdate} ]]
          then
             commentauthor=$(curl -H "Authorization: token ${SOURCE_PAT}" --silent -H "Accept: application/vnd.github.antiope-preview+json" https://api.github.com/repos/${SOURCE_REPO}/issues/${PR_NUMBER}/comments | jq ".[$icomment] | {commenter: .user.login}" | jq ".commenter")
	     if [[ $commentauthor == $GITHUB_USERNAME ]]; then approved=0; printf "${commentdate}"; fi
             approval_comment=$approved
          fi
       done
    fi

)
##################################################################

#TODO: If below preapproved is set to 0, all the checks should be short-circuited.
preapproved=1
approved=$preapproved

DEFAULT_POLL_TIMEOUT=10
POLL_TIMEOUT=${POLL_TIMEOUT:-$DEFAULT_POLL_TIMEOUT}

echo "CI job triggered by event- $REPO_EVENT_TYPE"
#Check if REPO_EVENT_TYPE specified above is supported. 
#At present the only difference in internal_pr and fork_pr is how the branch is named on the GITLAB side.
# This is because we dont want 'main' from fork to overwrite 'main' from the upstream repo on the Gitlab side
if [[ ${REPO_EVENT_TYPE} != "push" && ${REPO_EVENT_TYPE} != "internal_pr" && ${REPO_EVENT_TYPE} != "fork_pr"  ]]
then
   echo "Only PR and Push testing are currently supported. CI will exit"
   exit 1
fi

#Retrieve TARGET_HOSTNAME from TARGET_REPO
export TARGET_HOSTNAME=$(echo $TARGET_REPO | awk -F/ '{print $3}')

#Retrieve Github username of SOURCE_PAT
#This author is used for approval
GITHUB_USERNAME=$(curl -H "Authorization: token ${SOURCE_PAT}" -H "Accept: application/vnd.github.v3+json" --silent https://api.github.com/user | jq .login) 
#Target username
GITLAB_USERNAME=$(curl --header "PRIVATE-TOKEN: ${TARGET_PAT}" --silent "https://${TARGET_HOSTNAME}/api/v4/user" | jq .username | sed "s/\\\"/\\,/g" | sed s/\[,\]//g)

#Determine TARGET_PROJECT_ID from TARGET_REPO
TARGET_PROJECT_NAME=$(echo $TARGET_REPO | awk -F/ '{print $NF}' | sed -e "s/\.git//g")
TARGET_PROJECT_ID=$(curl --header "PRIVATE-TOKEN: ${TARGET_PAT}" -X GET --silent "https://${TARGET_HOSTNAME}/api/v4/projects?search=${TARGET_PROJECT_NAME}" | jq ".[0] | {id: .id}" | jq .id)
echo "retrieved TARGET_PROJECT_NAME: ${TARGET_PROJECT_NAME}"
echo "retrieved TARGET_PROJECT_ID: ${TARGET_PROJECT_ID}"

#TODO: Add a list of required variables for each type of event. The job will fail if any are empty
if [[ $(printenv BRANCH | wc -c) != "0" ]]
then
   branchfound="$(branchexists ${BRANCH})"
   #Maybe move the below branch check along with the overall variable values check (after that is implemented)
   if [[ ${branchfound} != "0" ]]
   then
      echo "Branch ${BRANCH} not found in the repo, CI job will exit"
      exit 1
   fi
fi


#Maybe move the below pr check along with the overall variable values check (after that is implemented)
if [[ "${REPO_EVENT_TYPE}" = "internal_pr" || "${REPO_EVENT_TYPE}" = "fork_pr" ]]
then
   #number of open pr's
   npr=$(curl --silent -H "Accept: application/vnd.github.antiope-preview+json" https://api.github.com/repos/${SOURCE_REPO}/pulls | jq length)
   if [[ ${npr} == "0" ]]
   then
      echo "No open PRs, CI will exit."
      exit 1
   fi
fi

#If PR Number is specified use that or else find the latest acceptable PR
#An acceptable PR is one that has the latest commit from the user $GITHUB_USERNAME or an approval comment by said user.
if [[ "${REPO_EVENT_TYPE}" = "internal_pr" || "${REPO_EVENT_TYPE}" = "fork_pr" ]]
then
   if [[ $(printenv PR_NUMBER | wc -c) == "0" ]]
   then
      # Cycle through all PRs 
      ipr=-1
      while [[ "$ipr" -lt "$(($npr-1))" ]]
      do
         ipr=$(($ipr+1))
         echo "line 174: $ipr"
         target_PR_NUMBER=$(curl --silent -H "Authorization: token ${SOURCE_PAT}" -H "Accept: application/vnd.github.antiope-preview+json" https://api.github.com/repos/${SOURCE_REPO}/pulls | jq ".[${ipr}] | {PR_NUMBER : .number}" | jq .PR_NUMBER)
         echo "${target_PR_NUMBER}"
         #Approvaltime is used to find the latest approved action, that PR will be targeted by CI.
         #This function only returns PRs where the latest commit is approved. 
         export temp_approvaltime="$(prapproval ${target_PR_NUMBER} ${GITHUB_USERNAME})"
         if [[ ! -z ${temp_approvaltime} ]] 
         then
            if [[ $(printenv approvedtime | wc -c) = 0 ]]
            then
               export approvedtime=${temp_approvaltime}
	       PR_NUMBER=${target_PR_NUMBER}         
            elif [[ ${temp_approvaltime} > ${approvedtime} ]] 
            then 
               export approvedtime=${temp_approvaltime}
	       PR_NUMBER=${target_PR_NUMBER}
            fi
         fi  
      done
   else
      # only check the specified PR.
      export approvedtime="$(prapproval ${PR_NUMBER} ${GITHUB_USERNAME})"
   fi
fi

if [[ "${REPO_EVENT_TYPE}" = "internal_pr" || "${REPO_EVENT_TYPE}" = "fork_pr" ]]
then
   if [[ $(printenv approvedtime | wc -c) == "0" ]]
   then
      echo "No approval associated with the target PR(s). CI job will exit"
      exit 1
   fi
fi


#PR already has a valid source at this point (or has exit). Push testing is essentially different in that it is part of the upstream repo.
#Checkout the branches in the VM so that they can pushed to Gitlab
if [ "${REPO_EVENT_TYPE}" = "internal_pr" ]
then
   BRANCH=$(curl --silent -H "Authorization: token ${SOURCE_PAT}" -H "Accept: application/vnd.github.antiope-preview+json" https://api.github.com/repos/${SOURCE_REPO}/pulls/${PR_NUMBER} | jq .head.ref | sed "s/\\\"/\\,/g" | sed s/\[,\]//g)
   git checkout "${BRANCH}"
   sha=$(git rev-parse HEAD)
elif [  "${REPO_EVENT_TYPE}" = "push"  ]
then
   git checkout "${BRANCH}"
elif [ "${REPO_EVENT_TYPE}" = "fork_pr" ]
then
   echo "You are running pull request target, make sure your settings are secure, secrets are accessible."
   #Manual change of git
   rm -rf * .*
   fork_repo=$(curl --silent -H "Accept: application/vnd.github.antiope-preview+json" https://api.github.com/repos/${SOURCE_REPO}/pulls/${PR_NUMBER} | jq .head.repo.clone_url)
   fork_repo="${fork_repo:1:${#fork_repo}-2}"
   git clone --quiet ${fork_repo} .
   GITHUB_HEAD_REF=$(curl --silent -H "Accept: application/vnd.github.antiope-preview+json" https://api.github.com/repos/${SOURCE_REPO}/pulls/${PR_NUMBER} | jq .head.ref)
   GITHUB_HEAD_REF="${GITHUB_HEAD_REF:1:${#GITHUB_HEAD_REF}-2}"
   git checkout "${GITHUB_HEAD_REF}"
   BRANCH=external-pr-${PR_NUMBER}
   git branch -m ${BRANCH}
   sha=$(git rev-parse HEAD)
fi


branch_uri="$(urlencode ${BRANCH})"

#Approval section
if [ "${REPO_EVENT_TYPE}" = "push" ]
then
   #Get the latest commit sha on the target gitlab repository. This is currently not being used but can provide a good sanity check.
   base_commitsha=$(curl --header "PRIVATE-TOKEN: $TARGET_PAT" "https://${TARGET_HOSTNAME}/api/v4/projects/${TARGET_PROJECT_ID}/repository/commits?ref_name=${BRANCH}" --silent | jq ".[0] | {id: .id}")
   #Run through the recent 100 commits to find the latest than can be cloned
   #Like the PR an acceptable commit is one which was commited by the user $GITHUB_USERNAME or has an approval comment by them
   sha="$(approvedcommitsha ${GITHUB_USERNAME} ${BRANCH})"
   echo "sha: $sha"
   if [[ $sha != "nil" ]]
   then
      #TODO: check if base_commitsha is older than sha before pushing
      approved=0
      git checkout $sha
   fi
fi

if [[ "${approved}" != "0" && "${REPO_EVENT_TYPE}" = "push" ]]
then
   echo "Commit author ${commitauthor} not associated with repository. Push testing not allowed. CI will exit"
   exit 1
fi
sh -c "git config --global credential.username $GITLAB_USERNAME"
sh -c "git config --global core.askPass /cred-helper.sh"
sh -c "git config --global credential.helper cache"
sh -c "git remote add mirror $*"
sh -c "echo pushing to $BRANCH branch at $(git remote get-url --push mirror)"
#sh -c "git push mirror $branch --force"
sh -c "git push mirror $sha:refs/heads/$BRANCH"
# If the push fails because the target branch is ahead than the push, Pipeline is counted as failed.
push_status=$?
if [[ "${push_status}" != "0" ]] 
then
   echo "Unable to push to target repository, job will fail."
   curl -d '{"state":"failure", "context": "'${TARGET_HOSTNAME}'"}' -H "Authorization: token ${SOURCE_PAT}"  -H "Accept: application/vnd.github.antiope-preview+json" -X POST --silent "https://api.github.com/repos/${SOURCE_REPO}/statuses/${sha}"
   exit 1
fi

sleep $POLL_TIMEOUT

#TODO: see if there is better way than taking the last pipeline
pipeline_id=$(curl --header "PRIVATE-TOKEN: $TARGET_PAT" --silent "https://${TARGET_HOSTNAME}/api/v4/projects/${TARGET_PROJECT_ID}/repository/commits/${BRANCH}" | jq '.last_pipeline.id')

if [ "${pipeline_id}" = "null" ]
then
    echo "pipeline_id is null, so we can't continue."
    echo "Response from https://${TARGET_HOSTNAME}/api/v4/projects/${TARGET_PROJECT_ID}/repository/commits/${BRANCH} was:"
    echo $(curl --header "PRIVATE-TOKEN: $TARGET_PAT" --silent "https://${TARGET_HOSTNAME}/api/v4/projects/${TARGET_PROJECT_ID}/repository/commits/${BRANCH}")
    exit 1
fi

echo "Triggered CI for branch ${BRANCH}"
echo "Working with pipeline id #${pipeline_id}"
echo "Poll timeout set to ${POLL_TIMEOUT}"

ci_status="pending"

until [[ "$ci_status" != "pending" && "$ci_status" != "running" ]]
do
   sleep $POLL_TIMEOUT
   ci_output=$(curl --header "PRIVATE-TOKEN: $TARGET_PAT" --silent "https://${TARGET_HOSTNAME}/api/v4/projects/${TARGET_PROJECT_ID}/pipelines/${pipeline_id}")
   ci_status=$(jq -n "$ci_output" | jq -r .status)
   ci_web_url=$(jq -n "$ci_output" | jq -r .web_url)
   
   echo "Current pipeline status: ${ci_status}"
   if [ "$ci_status" = "running" ]
   then
     echo "Checking pipeline status..."
     curl -d '{"state":"pending", "target_url": "'${ci_web_url}'", "context": "'${TARGET_HOSTNAME}'"}' -H "Authorization: token ${SOURCE_PAT}"  -H "Accept: application/vnd.github.antiope-preview+json" -X POST --silent "https://api.github.com/repos/${SOURCE_REPO}/statuses/${sha}"  > /dev/null 
   fi
done

echo "Pipeline finished with status ${ci_status}"

#TODO: Incorporate a check on the Github PR to see if latest commit has already been tested. This is necessary if users need to automate pipelines. Will allow below deletion without wasting computing cycles.
##Delete remote branch if PR
#if [[ "${REPO_EVENT_TYPE}" = "internal_pr" || "${REPO_EVENT_TYPE}" = "fork_pr" ]]
#then
#   sh -c "git push mirror --delete ${BRANCH}"
#fi

if [ "$ci_status" = "success" ]
then 
  curl -d '{"state":"success", "target_url": "'${ci_web_url}'", "context": "'${TARGET_HOSTNAME}'"}' -H "Authorization: token ${SOURCE_PAT}"  -H "Accept: application/vnd.github.antiope-preview+json" -X POST --silent "https://api.github.com/repos/${SOURCE_REPO}/statuses/${sha}" 
  exit 0
elif [ "$ci_status" = "manual" ] # do not return non-triggered manual builds as a CI failure
then 
  curl -d '{"state":"success", "target_url": "'${ci_web_url}'", "context": "'${TARGET_HOSTNAME}'"}' -H "Authorization: token ${SOURCE_PAT}"  -H "Accept: application/vnd.github.antiope-preview+json" -X POST --silent "https://api.github.com/repos/${SOURCE_REPO}/statuses/${sha}" 
  exit 0
elif [ "$ci_status" = "failed" ]
then 
  curl -d '{"state":"failure", "target_url": "'${ci_web_url}'", "context": "'${TARGET_HOSTNAME}'"}' -H "Authorization: token ${SOURCE_PAT}"  -H "Accept: application/vnd.github.antiope-preview+json" -X POST --silent "https://api.github.com/repos/${SOURCE_REPO}/statuses/${sha}" 
  exit 1
else # no return value, so there's no target URL either
  echo "Pipeline ended without a ci_status: https://${TARGET_HOSTNAME}/api/v4/projects/${TARGET_PROJECT_ID}/pipelines/${pipeline_id}"
  curl -d '{"state":"failure", "context": "'${TARGET_HOSTNAME}'"}' -H "Authorization: token ${SOURCE_PAT}"  -H "Accept: application/vnd.github.antiope-preview+json" -X POST --silent "https://api.github.com/repos/${SOURCE_REPO}/statuses/${sha}"
  exit 1
fi
