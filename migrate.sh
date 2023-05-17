#!/bin/bash
File="./repos.txt"
IFS=',' # Internal Field Separator

RepoType="public"
RepoTeamPermission="ADMIN"
RepoTeam=""

for arg in "$@"; do
  shift
  case "$arg" in
    '--repo-type')   set -- "$@" '-y'   ;;
    '--repo-team') set -- "$@" '-t'   ;;
    '--repo-team-permission')   set -- "$@" '-p'   ;;
    *)          set -- "$@" "$arg" ;;
  esac
done

while getopts o:y:t:F:p: flag
do
    echo $flag
    case "${flag}" in
        o) OrgName=${OPTARG};;
        y) RepoType=${OPTARG};;
        t) RepoTeam=${OPTARG};;
        F) File=${OPTARG};;
        p) RepoTeamPermission=${OPTARG};;
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

    if [ -n "$RepoTeam" ]
    then
        RepoTeamId=`gh api graphql -f query="{organization(login:\"${OrgName}\"){team(slug: \"${RepoTeam}\"){id}}}" -q .data.organization.team.id`
        gh api graphql -f query='
            mutation($repositoryId:ID!,$teamIds:[ID!]!,$permission:RepositoryPermission!) {
                updateTeamsRepository(input: {
                permission: $permission
                repositoryId: $repositoryId
                teamIds: $teamIds
                }) { clientMutationId }
            }' -f repositoryId=$repositoryId -f teamIds="${RepoTeamId}" -f permission=$RepoTeamPermission	
    fi

    if [ $Action == "archive" ]
    then
        gh repo archive "${OrgName}/${NewRepoName}" -y	
    fi

 done < "$File"