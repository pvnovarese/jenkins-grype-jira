pipeline {
  environment {
    // shouldn't need the registry variable unless you're not using dockerhub
    // registry = 'registry.hub.docker.com'
    //
    // change this HUB_CREDENTIAL to the ID of whatever jenkins credential has your registry user/pass
    // first let's set the docker hub credential and extract user/pass
    // we'll use the USR part for figuring out where are repository is
    HUB_CREDENTIAL = "docker-hub"
    // use credentials to set DOCKER_HUB_USR and DOCKER_HUB_PSW
    DOCKER_HUB = credentials("${HUB_CREDENTIAL}")
    // change repository to your DockerID
    REPOSITORY = "${DOCKER_HUB_USR}/jenkins-grype-demo"
    TAG = ":devbuild-${BUILD_NUMBER}"   
    
    // set path for executables.  I put these in jenkins_home as noted
    // in README but you may install it somewhere else like /usr/local/bin
    SYFT_LOCATION = "/var/jenkins_home/syft"
    GRYPE_LOCATION = "/var/jenkins_home/grype"
  } // end environment
  
  agent any
  stages {
    
    stage('Checkout SCM') {
      steps {
        checkout scm
      } // end steps
    } // end stage "checkout scm"
    
    stage('Build image and tag with build number') {
      steps {
        script {
          dockerImage = docker.build REPOSITORY + TAG
        } // end script
      } // end steps
    } // end stage "build image and tag w build number"
    
    stage('Analyze with grype') {
      steps {
        sh "echo '${REPOSITORY}${TAG} has fixable issues:' > jira_body.txt"
        sh "echo >> jira_body.txt"
        // run grype with json output, in jq, parse matches and select items 
        // that do not have null "fixedInVersion" and output those items'
        // artifact name (i.e. package name) and version to upgrade to.
        
        sh "${GRYPE_LOCATION} -o json ${REPOSITORY}${TAG} | jq -r '.matches[] | select(.vulnerability.fixedInVersion | . != null ) | [.artifact.name, .vulnerability.fixedInVersion]|@tsv' >> jira_body.txt"
        
        sh """
            head -c -1 jira_top.json > jira_create_issue.json
            cat jira_body.txt | sed -e :a -e '\$!N;s/\\n/\\\\n/;ta' | tr '\\t' '  ' | tr -d '\\\n' >> jira_create_issue.json
            //cat jira_body.txt | tr '\\\n' '\\\\\\n' | tr '\\t' ' ' >> jira_create_issue.json
            cat jira_bottom.json >> jira_create_issue.json
            cat jira_create_issue.json | curl --data-binary @- --request POST --url 'https://anchore8.atlassian.net/rest/api/2/issue' --user 'paul.novarese@anchore.com:XlhZAhzZQdhiWTK10r9V77CC' --header 'Accept: application/json' --header 'Content-Type: application/json'
        """
        //sh "head -c -1 jira_top.json > jira_create_issue.json"
        //sh "cat jira_top.json > jira_create_issue.json"
        //sh "cat jira_body.txt | tr '\n' '\\n' >> jira_create_issue.json"
        //sh "cat jira_bottom.json >> jira_create_issue.json"
        //sh "cat jira_create_issue.json | tr '\n' '\\n | curl --data-binary @- --request POST --url 'https://anchore8.atlassian.net/rest/api/3/issue' --user 'paul.novarese@anchore.com:XlhZAhzZQdhiWTK10r9V77CC' --header 'Accept: application/json' --header 'Content-Type: application/json'"
          
        // sh 'set -o pipefail ; /var/jenkins_home/grype -f high -q -o json ${REPOSITORY}:${BUILD_NUMBER} | jq .matches[].vulnerability.severity | sort | uniq -c'
      } // end steps
    } // end stage "analyze with grype"
    
    
    stage('Re-tag as prod and push stable image to registry') {
      steps {
        script {
          docker.withRegistry('', HUB_CREDENTIAL) {
            dockerImage.push('prod') 
            // dockerImage.push takes the argument as a new tag for the image before pushing
          }
        } // end script
      } // end steps
    } // end stage "retag as prod"

    stage('Clean up') {
      // delete the images locally
      steps {
        sh 'docker rmi ${REPOSITORY}${TAG} ${REPOSITORY}:prod'
      } // end steps
    } // end stage "clean up"

  } // end stages
} // end pipeline
