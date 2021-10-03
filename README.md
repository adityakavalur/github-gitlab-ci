# Mirror to GitLab and trigger GitLab CI

This is a GitHub Action that mirrors commits and pull requests from Github to GitLab.
The workflow involves 3 repositories, namely: 
1. mirroring repo, 
2. source(SOURCE_REPO) and 
3. target(TARGET_REPO). 

The mirroring and source repositories need to be on Github whereas the target repository should be on Gitlab. A Github action in the mirroring repository, triggered by a manual action, scans the source repo and clones selective items to the target repository. Examples of github actions in the mirror repository are provided below. CI in Gitlab will be triggered based on the settings of the target repository. This action will wait and return the status and url of the pipeline back to the source repository on GitHub. 

To provide some level of security, the action restricts what commits can be cloned (and therefore initiate CI) into Gitlab. Activites tied to the (approved-)user providing the SOURCE_PAT, a Github token, are eligible to be cloned. The events considered are push and pull requests. Commits, based in push or in a pull request, are eligible if they are authored by the approved-user or if the commit/PR has an approval comment associated with it. In the case of testing a PR the comment must be more recent than the latest commit. The approved user is expected to review the code before undertaking these actions. 

> **_NOTE:_**  For comment based approvals in push workflows, the comments associated with the commits are checked. Whereas for PR workflows only the PR comments are checked, the commit comments associated with the PR are not checked. The comments on commits do show up in the PR, however Github does not associate them with the PR in the same way as a direct comment.


The most important workflow is testing pull requests from forks, as this is not natively supported in Gitlab. To test the code modifications we source the fork repo and create a temporary branch `external-pr-${PR_NUMBER}` on the Gitlab instance. It is important to remember that all actions including pull requests end up as pushes on the Gitlab side. Therefore, your `.gitlab-ci.yml` file needs to account for this and cannot leverage pre-defined variables such as `CI_PIPELINE_SOURCE` to define distinct workflows for each action.

Push workflows target a specific branch. Whereas PRs can target a specific PR by providing the optional argument PR_NUMBER

Possible steps:
Setting up the workflow
1. Create a mirroring repository (see example repository below)
2. Add one or more of the example workflows provided below for your intended workflow
3. Create source and target PAT and add them to the mirroring repo
Using the workflow
4. If commits/PR are from non-approved user, provide approval string in commit/PR comment.
5. Trigger GitHub action in mirroring repository.

## Example repositories
Source repo: https://github.com/adityakavalur/source_repo
Mirroring repo: https://github.com/adityakavalur/mirroring_repo
Target repo: https://gitlab.com/akavalur/target_repo


## Example workflows

There are 3 example workflows that this action can support: push, internal pull request and fork pull request. You can leverage any or all of them. All fields are mandatory unless explicitly specified.

Example of an action for mirroring push commits
```workflow          
name: Mirror commits
on: workflow_dispatch
jobs:
  pushmirror:
    runs-on: ubuntu-latest
    env:
      SOURCE_REPO: <namespace>/<repo_name>
      TARGET_REPO: "<complete url e.g. https://gitlab.com/namespace/repository.git>"
    steps:
      - uses: actions/checkout@v2
        with:
          repository: ${{ env.SOURCE_REPO }}
          token: ${{ secrets.SOURCE_PAT }}
          fetch-depth: 0
      - name: Push testing on external Gitlab
        uses: adityakavalur/github-gitlab-ci@v0.1.1
        with:
          args: ${{ env.TARGET_REPO }}
        env:
          TARGET_PAT: ${{ secrets.TARGET_PAT }}
          SOURCE_PAT: ${{ secrets.SOURCE_PAT }}
          GITHUB_TOKEN: ${{ secrets.SOURCE_PAT }}
          POLL_TIMEOUT: "<Optional, value in seconds, default is 10 seconds>"
          REPO_EVENT_TYPE: push
          BRANCH: main
          APPROVAL_STRING: <Optional, approval comment that authorizes commits by non-approved users>
```

Example of an action for mirroring a pull request from within the repository
```workflow 
name: Internal PR
on: workflow_dispatch
jobs:
  internalpr:
    runs-on: ubuntu-latest
    env:
      SOURCE_REPO: <namespace>/<repo_name>
      TARGET_REPO: "<complete url e.g. https://gitlab.com/namespace/repository.git>"
    steps:        
      - uses: actions/checkout@v2
        with:
          repository: ${{ env.SOURCE_REPO }}
          token: ${{ secrets.SOURCE_PAT }}
          fetch-depth: 0
      - name: Internal PR testing on external Gitlab
        uses: adityakavalur/github-gitlab-ci@main
        with:
          args: ${{ env.TARGET_REPO }}
        env:
          TARGET_PAT: ${{ secrets.TARGET_PAT }}
          SOURCE_PAT: ${{ secrets.SOURCE_PAT }}
          GITHUB_TOKEN: ${{ secrets.SOURCE_PAT }}
          POLL_TIMEOUT: "<Optional, value in seconds, default is 10 seconds>"
          REPO_EVENT_TYPE: internal_pr
          PR_NUMBER: <Optional>
          APPROVAL_STRING: <Optional, approval comment that authorizes commits by non-approved users>
```

Example of an action for mirroring a pull request from a fork
```workflow
name: Fork PR
on: workflow_dispatch
jobs:
  forkpr:
    runs-on: ubuntu-latest
    env:
      SOURCE_REPO: <namespace>/<repo_name>
      TARGET_REPO: "<complete url e.g. https://gitlab.com/namespace/repository.git>"      
    steps:
      - uses: actions/checkout@v2
        with:
          repository: ${{ env.SOURCE_REPO }}
          token: ${{ secrets.SOURCE_PAT }}
          fetch-depth: 0
      - name: Fork PR testing on external Gitlab
        uses: adityakavalur/github-gitlab-ci@main
        with:
          args: ${{ env.TARGET_REPO }}
        env:
          TARGET_PAT: ${{ secrets.TARGET_PAT }}
          SOURCE_PAT: ${{ secrets.SOURCE_PAT }}
          GITHUB_TOKEN: ${{ secrets.SOURCE_PAT }}
          POLL_TIMEOUT: "<Optional, value in seconds, default is 10 seconds>"
          REPO_EVENT_TYPE: fork_pr
          PR_NUMBER: <Optional>
          APPROVAL_STRING: <Optional, approval comment that authorizes commits by non-approved users>
```

Be sure to define the secrets `SOURCE_PAT` and `TARGET_PAT` in secrets.


This repo expands on work done by SvanBoxel in https://github.com/SvanBoxel/gitlab-mirror-and-ci-action
