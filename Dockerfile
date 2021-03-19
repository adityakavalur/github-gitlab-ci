FROM makocchi/alpine-git-curl-jq:latest

LABEL "com.github.actions.name"="Gitlab external mirroring"
LABEL "com.github.actions.description"="Mirroring of commits and pull requests to GitLab, trigger GitLab CI and post results back to GitHub"
LABEL "com.github.actions.icon"="git-commit"
LABEL "com.github.actions.color"="blue"

LABEL "repository"="https://github.com/adityakavaluar/gitlab-external-mirror"
LABEL "homepage"="https://github.com/adityakavalur/gitlab-external-mirror"
LABEL "maintainer"="Aditya Kavalur"


COPY entrypoint.sh /entrypoint.sh
COPY cred-helper.sh /cred-helper.sh
ENTRYPOINT ["/entrypoint.sh"]
