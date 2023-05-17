#!/bin/bash
File="./repos.txt"
IFS=',' # Internal Field Separator

RepoType="public"

while getopts o:rt:t:F flag
do
    case "${flag}" in
        o) OrgName=${OPTARG};;
        type) RepoType=${OPTARG};;
        F) File=${OPTARG};;
    esac
done

echo ${OrgName:?missing -o}

while IFS= read -r line
do
	read -a params <<< "$line"
    Action=${params[0]}
    OriginalRepoUrl=${params[1]}
    OriginalRepoName="$(basename "${OriginalRepoUrl}" .git).git"
    NewRepoName=${params[2]}

	git clone --bare "${OriginalRepoUrl}" && cd "${OriginalRepoName}"

	gh repo create "${OrgName}/${NewRepoName}" --${RepoType} -d "MIGRATED FROM ${OriginalRepoUrl}" && git push --mirror "git@github.com:${OrgName}/${NewRepoName}.git" 

    #--team ${RepoTeam}

	cd ..
	rm -rf $OriginalRepoName	
	
    repositoryId=`gh api graphql -f query="{repository(owner:\"${OrgName}\",name:\"${NewRepoName}\"){id}}" -q .data.repository.id`

    gh api graphql -f query='
        mutation($repositoryId:ID!,$branch:String!,$requiredReviews:Int!) {
            createBranchProtectionRule(input: {
            repositoryId: $repositoryId
            pattern: $branch
            requiresApprovingReviews: true
            requiredApprovingReviewCount: $requiredReviews
            requireLastPushApproval: true
            requiresConversationResolution: true
            requiresStatusChecks: true
            requiresStrictStatusChecks: true
            }) { clientMutationId }
        }' -f repositoryId=$repositoryId -f branch="[main,master,develop]*" -F requiredReviews=2


    if [ $Action == "archive" ]
    then
        gh repo archive "${OrgName}/${NewRepoName}" -y	
    fi

 done < "$File"