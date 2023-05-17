## MIGRATION OF REPOS FROM GIT PROVIDER TO GITHUB

# PRE REQUISITES

- git
- gh cli
- ssh key config for github connection or change the script to use https

# Parameters

- F: file name with list of repos to be migrated with the following structure (default file name repos.txt)

  - action(migrate,archive),original git url,name of the new repo
  - Example: git@github.com:Test/test.git,services

- o: organization name or username (required)
- repo-type: public,private,internal (public default)
- repo-team: team to be added to the repo
- repo-team-permission: permission of the team to be added (ADMIN default)

# Documentation

- https://cli.github.com/manual/
- https://docs.github.com/en/graphql/reference/mutations
