# Dockerfile for jenkins/anchore/jira integration demonstration
# we will use anchore to look for vulnerabilities with fixes
# in the image and open a jira ticket if they exist

# pvnovarese/ubuntu_sudo_test:latest has known sudo issue with fix available
FROM pvnovarese/ubuntu_sudo_test:latest

# busybox/latest usually has no known problems so it's a good (and fast) antitest
# FROM busybox:latest

CMD ["/bin/sh"]
