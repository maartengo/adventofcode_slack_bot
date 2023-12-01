FROM mcr.microsoft.com/powershell:alpine-3.12
ENV LANG=en_US.UTF-8
ENV COMPlus_EnableDiagnostics=0
ENV TZ="Europe/Amsterdam"

# Run as non-root user
USER 1001:1001

COPY Logging.psm1 Logging.psm1
COPY slackbot.ps1 slackbot.ps1
COPY result.json result.json
# TODO: remove copy of result.json

ENTRYPOINT ["pwsh", "slackbot.ps1"]