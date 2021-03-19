# Mirror to GitLab and trigger GitLab CI

A GitHub Action that mirrors commits and pull requests from Github to GitLab. The workflow involves 3 repositories, namely: mirror, source(SOURCE_REPO) and target(GITLAB_PROJECT_ID). The mirror and source repositories need to be on Github whereas the target repository is on Gitlab. The mirror repository, through manual action/trigger scans the source repo and clones selective items to the target repository. Examples of github actions in the mirror repository are provided below. CI in Gitlab will be triggered based on the settings of the target repository. This action will wait and return the status and url of the pipeline back to the source repository on GitHub. 

To provide some level of security, branch `main` restricts what commits can be cloned (and therefore initiate CI) into Gitlab. Activites tied to the (approved-)user providing the SOURCE_PAT, a Github token, are eligible to be cloned. The events considered are push and pull requests. Commits, based in push or in a pull request, are eligible if they are authored by the approved-user or if the commit/PR has an approval comment associated with it. In the case of testing a PR the comment must be more recent than the latest commit. The approved user is expected to review the code before undertaking these actions. 

The most common workflow is testing pull requests from forks. To test the code modifications we source the fork repo and create a temporary branch `external-pr-${PR_NUMBER}` on the Gitlab instance. All branches associated with pull requests will be deleted from Gitlab at the end of the action. It is important to remember that all actions including pull requests end up as pushes on the Gitlab side. Therefore, your `.gitlab-ci.yml` file needs to account for this.

Push workflows target a specific branch. Whereas PRs can target a specific PR by providing the optional argument PR_NUMBER

## Example workflows

There are 3 example workflows: push, internal pull request and fork pull request

```workflow          
name: Mirror commits
on: workflow_dispatch
jobs:
  pushmirror:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
        with:
          # This should be the same as GITHUB_REPO below, this is the SOURCE_REPO which is being polled for commits and PRs
          repository: <namespace>/<repo_name>
          token: ${{ secrets.SOURCE_PAT }}
          fetch-depth: 0
      - name: Push testing on external Gitlab
        uses: adityakavalur/github-gitlab-ci@main
        with:
          args: "https://gitlab.com/<namespace>/<repo_name>.git"
        env:
          GITLAB_HOSTNAME: "gitlab.com"
          GITLAB_USERNAME: "<your gitlab username>"
          #The below password is really a PAT, needs write
          GITLAB_PASSWORD: ${{ secrets.GITLAB_PAT }}
          #The below password is a GITHUB PAT, GITHUB does not allow secrets with the name GITHUB in them.
          SOURCE_PAT: ${{ secrets.SOURCE_PAT }}
          GITHUB_TOKEN: ${{ secrets.SOURCE_PAT }}
          GITLAB_PROJECT_ID: "<Gitlab project id>"
          POLL_TIMEOUT: "120"
          REPO_EVENT_TYPE: push
          BRANCH: main
          GITHUB_REPO: <namespace>/<repo_name>
          APPROVAL_STRING: triggerstring
          
name: Internal PR
on: workflow_dispatch
jobs:
  internalpr:
    runs-on: ubuntu-latest
    steps:        
      - uses: actions/checkout@v2
        with:
          # This should be the same as GITHUB_REPO below, this is the SOURCE_REPO which is being polled for commits and PRs
          repository: <namespace>/<repo_name>
          token: ${{ secrets.SOURCE_PAT }}
          fetch-depth: 0
      - name: Internal PR testing on external Gitlab
        uses: adityakavalur/github-gitlab-ci@main
        with:
          args: "https://gitlab.com/<namespace>/<repo_name>.git"
        env:
          GITLAB_HOSTNAME: "gitlab.com"
          GITLAB_USERNAME: "<your gitlab username>"
          GITLAB_PASSWORD: ${{ secrets.GITLAB_PAT }}
          SOURCE_PAT: ${{ secrets.SOURCE_PAT }}
          GITHUB_TOKEN: ${{ secrets.SOURCE_PAT }}
          GITLAB_PROJECT_ID: "<gitlab project id>"
          POLL_TIMEOUT: "120"
          REPO_EVENT_TYPE: internal_pr
          TARGET_BRANCH: main
          GITHUB_REPO: <namespace>/<repo_name>
          PR_NUMBER: <Optional>
          APPROVAL_STRING: <approval comment that authorizes commits by non-approved users>

name: Fork PR
on: workflow_dispatch
jobs:
  forkpr:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
        with:
          repository: <namespace>/<repo_name>
          token: ${{ secrets.SOURCE_PAT }}
          fetch-depth: 0
      - name: Fork PR testing on external Gitlab
        uses: adityakavalur/github-gitlab-ci@main
        with:
          args: "https://gitlab.com/<namespace>/<repo_name>.git"
        env:
          GITLAB_HOSTNAME: "gitlab.com"
          GITLAB_USERNAME: "<your gitlab username>"
          GITLAB_PASSWORD: ${{ secrets.GITLAB_PAT }}
          SOURCE_PAT: ${{ secrets.SOURCE_PAT }}
          GITHUB_TOKEN: ${{ secrets.SOURCE_PAT }}
          GITLAB_PROJECT_ID: "<gitlab project id>"
          POLL_TIMEOUT: "120"
          REPO_EVENT_TYPE: fork_pr
          TARGET_BRANCH: main
          GITHUB_REPO: <namespace>/<repo_name>
          PR_NUMBER: <Optional>
          APPROVAL_STRING: triggerstring
```

Be sure to define the secrets `SOURCE_PAT` and `GITLAB_PAT` in secrets.
