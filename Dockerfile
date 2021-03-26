FROM makocchi/alpine-git-curl-jq:latest

LABEL "com.github.actions.name"="Trigger Gitlab CI for a Github repository"
LABEL "com.github.actions.description"="Mirroring of commits and pull requests to GitLab, trigger GitLab CI and post results back to GitHub"
LABEL "com.github.actions.icon"="git-commit"
LABEL "com.github.actions.color"="blue"

LABEL "repository"="https://github.com/adityakavalur/github-gitlab-ci"
LABEL "homepage"="https://github.com/adityakavalur/github-gitlab-ci"
LABEL "maintainer"="Aditya Kavalur"


COPY entrypoint.sh /entrypoint.sh
COPY cred-helper.sh /cred-helper.sh
RUN chmod +x /entrypoint.sh
RUN chmod +x /cred-helper.sh
ENTRYPOINT ["/entrypoint.sh"]
