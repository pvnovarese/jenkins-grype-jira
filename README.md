# Demo: Integrating Jenkins, Grype, and Jira

This is a very rough demo of integrating Jenkins, Grype, and Jira.  This repo will open Jira tickets for vulnerabilties that have reported fixes in the images we scan. 

## Step 1: Deploy Jenkins

### Option A: simple docker run

We're going to run jenkins in a container to make this fairly self-contained and easily disposable.  This command will run jenkins and bind to the host's docker sock (if you don't know what that means, don't worry about it, it's not important).

`# docker run -u root -d --name jenkins --rm -p 8080:8080 -p 50000:50000 -v /var/run/docker.sock:/var/run/docker.sock -v /tmp/jenkins-data:/var/jenkins_home jenkinsci/blueocean`

### Option B: Docker Compose

If you're comfortable with Docker Compose, there's a compose file in this repo that will spin up jenkins and docker-in-docker.  The advantage of using this over Option A is that cleanup will be a lot easier, you just throw the docker-in-docker container away when you're done.  

## Step 2: Jenkins Setup

We'll need to install jq in the jenkins container:

`# docker exec jenkins apk add jq`

Once Jenkins is up and running, we have just a few things to configure:
- Get the initial password (`# docker logs jenkins`)
- log in on port 8080
- Unlock Jenkins using the password from the logs
- Select “Install Selected Plugins” and create an admin user
- Create a credential with your Jira username and password (mine is called "jira-cred" - you may need to edit the jenkinsfile to relfect your credential's name)
- Create a secret text credential with your Jira URL (e.g. foobar.atlassian.net) named "jira-url"
- (OPTIONAL) Create a credential so we can push images into Docker Hub:
	- go to manage jenkins -> manage credentials
	- click “global” and “add credentials”
	- Use your Docker Hub username and password (get an access token from Docker Hub if you are using multifactor authentication), and set the ID of the credential to “docker-hub”.
	- If you want to do this, uncomment the "Re-tag as prod and push stable image to registry" stage in the Jenkinsfile.

## Step 3: Get Syft and Grype 
We can download the binaries directly into our bind mount directory we created we spun up the jenkins container:

`curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sudo sh -s -- -b /tmp/jenkins-data`
`curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /tmp/jenkins-data`


## Step 4: Check for fixable CVEs and open Jira tickets automatically

- Fork this repo
- In the Jenkinsfile, change the lines in the Environment section as needed to reflect your credentials and Jira endpoints, project IDs, etc.
- From the jenkins main page, select “New Item” 
- Name it “jenkins-grype-jira”
- Choose “pipeline” and click “OK”
- On the configuration page, scroll down to “Pipeline”
- For “Definition,” select “Pipeline script from SCM”
- For “SCM,” select “git”
- For “Repository URL,” paste in the URL of your forked github repo
	e.g. https://github.com/pvnovarese/jenkins-grype-jira (use your github username)
- Click “Save”
- You’ll now be at the top-level project page.  Click “Build Now”

Jenkins will check out the repo and build an image using the provided Dockerfile.  This image is based on ubuntu with a sudo package installed that has known vulnerabilties.  Once the image is built, Jenkins will scan it with grype and extract any vulnerabilties that have known fixes from the grype output.  If it finds any, it will open a Jira ticket with the package name, CVE number, severity, and version of the package with the fix.

## Step 5: Cleanup
- (OPTION A) If you used the docker run method for standing up Jenkins, kill the jenkins container (it will automatically be removed since we specified --rm when we created it):
	`# docker kill jenkins`
- (OPTION B) If you used the Compose method for standing up Jenkins:
- 	`# docker-compose down`
- Remove the jenkins-data directory from /tmp
	`# sudo rm -rf /tmp/jenkins-data/`
- Remove all demo images from your local machine:
	`# docker image ls | grep -E "jenkins-grype-jira" | awk '{print $3}' | xargs docker image rm -f`

