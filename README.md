# Demo: Integrating Anchore, Jenkins, and Jira (for Vulnerabilties)

This is a very rough demo of integrating Jenkins, Anchore, and Jira.  This repo will open Jira tickets for vulnerabilties that have reported fixes in the images we scan. 

## Part 1: Jenkins Setup

We're going to run jenkins in a container to make this fairly self-contained and easily disposable.  This command will run jenkins and bind to the host's docker sock (if you don't know what that means, don't worry about it, it's not important).

`$ docker run -u root -d --name jenkins --rm -p 8080:8080 -p 50000:50000 -v /var/run/docker.sock:/var/run/docker.sock -v /tmp/jenkins-data:/var/jenkins_home jenkinsci/blueocean
`

and we'll need to install jq, python3, and anchore-cli in the jenkins container:

`$ docker exec jenkins apk add jq python3 && python3 -m ensurepip && pip3 install anchore-cli`

Once Jenkins is up and running, we have just a few things to configure:
- Get the initial password (`$ docker logs jenkins`)
- log in on port 8080
- Unlock Jenkins using the password from the logs
- Select “Install Selected Plugins” and create an admin user
- Create a credential so we can push images into Docker Hub:
	- go to manage jenkins -> manage credentials
	- click “global” and “add credentials”
	- Use your Docker Hub username and password (get an access token from Docker Hub if you are using multifactor authentication), and set the ID of the credential to “Docker Hub”.
- Create a credential with your Jira username and password (mine is called "jira-anchore8" - you may need to edit the jenkinsfile to relfect your credential's name)
- Create a credential with your Anchore Engine/Enterprise username and password (mine is called AnchoreJenkinsUser). 

## Part 2: Get Syft and Grype (optional)
(optional, the Jenkinsfile only uses anchore-cli but we can split some of this stuff out using Anchore toolbox)
We can download the binaries directly into our bind mount directory we created we spun up the jenkins container:

`curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sudo sh -s -- -b /tmp/jenkins-data`
`curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /tmp/jenkins-data`


## Part 3: Check for fixable CVEs and open Jira tickets automatically

- Fork this repo
- In the Jenkinsfile, change the lines in the Environment section as needed to reflect your credentials and Anchore/Jira endpoints, project IDs, etc.
- From the jenkins main page, select “New Item” 
- Name it “jenkins-anchore-jira-vuln”
- Choose “pipeline” and click “OK”
- On the configuration page, scroll down to “Pipeline”
- For “Definition,” select “Pipeline script from SCM”
- For “SCM,” select “git”
- For “Repository URL,” paste in the URL of your forked github repo
	e.g. https://github.com/pvnovarese/jenkins-anchore-jira-vuln (use your github username)
- Click “Save”
- You’ll now be at the top-level project page.  Click “Build Now”

Jenkins will check out the repo and build an image using the provided Dockerfile.  This image is based on ubuntu with a sudo package installed that has known vulnerabilties.  Once the image is built, Jenkins will add it to Anchore's queue to be analyzed, pull the vulnerability report, and then extract any vulnerabilties that have known fixes.  If it finds any, it will open a Jira ticket with the package name, CVE number, severity, and version of the package with the fix.

## Part 4: Cleanup
- Kill the jenkins container (it will automatically be removed since we specified --rm when we created it):
	`pvn@gyarados /home/pvn> docker kill jenkins`
- Remove the jenkins-data directory from /tmp
	`pvn@gyarados /home/pvn> sudo rm -rf /tmp/jenkins-data/`
- Remove all demo images from your local machine:
	`pvn@gyarados /home/pvn> docker image ls | grep -E "jenkins-anchore-jira-vuln" | awk '{print $3}' | xargs docker image rm -f`

