# Dockerfile for jenkins/gripe integration demonstration
# we will use grype to look for vulnerabilities with fixes
# in the image and open a jira ticket if they exist
# FROM pvnovarese/ubuntu_sudo_test:latest
# FROM alpine:latest
FROM busybox:latest
CMD ["/bin/sh"]
