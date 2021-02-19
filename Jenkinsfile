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
    
    // use credentials to set JIRA_USR and JIRA_PSW
    JIRA_CREDENTIAL = "jira-anchore8"
    JIRA = credentials("${JIRA_CREDENTIAL}")
    JIRA_URL = "anchore8.atlassian.net"
    
    JIRA_PROJECT = "10000"
    JIRA_ASSIGNEE = "5fc52f03f2df6c0076c94c94"
    
    // change repository to your DockerID
    REPOSITORY = "${DOCKER_HUB_USR}/jenkins-grype-jira"
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
    
    stage('Analyze with Anchore') {
      steps {
        
        // run grype with json output, in jq, parse matches and select items 
        // that do not have null "fixedInVersion" and output those items'
        // artifact name (i.e. package name) and version to upgrade to.
        sh "${GRYPE_LOCATION} -o json ${REPOSITORY}${TAG} | jq -r '.matches[] | select(.vulnerability.fixedInVersion | . != null ) | [.artifact.name, .vulnerability.id, .vulnerability.severity, .vulnerability.fixedInVersion]|@tsv' > jira_body.txt"
        
        // use plugin to analyze image (or we could use syft pipeline scanning mode
        // then pull vunlerabilities with anchore-cli (we could alternatively pull
        // policy violations instead), build payload to open a jira ticket to fix
        // any problems
        sh """
          echo "scanning ${REPOSITORY}:${TAG}
          anchore-cli image add --force --dockerfile ./Dockerfile ${REPOSITORY}${TAG}
          anchore-cli image wait ${REPOSITORY}${TAG}
          anchore-cli --json image vuln ${REPOSITORY}${TAG} all | jq -r '.vulnerabilities[] | select(.fix | . != "None") | [.package, .vuln, .severity, .fix]|@tsv' > jira_body.txt
        """

        script {
          DESC_BODY_LINES = sh (
            script: 'wc -l jira_body.txt',
            returnStdout: true
          ).trim()
          if (DESC_BODY_LINES != 0) {
            sh """
              echo "building header for jira ticket descrpition field"
              echo '${REPOSITORY}${TAG} has fixable issues:' > jira_header.txt
              echo >> jira_header.txt
              echo "building json for jira"
              head -c -1 v2_head.json > v2_create_issue.json      # remove last byte (newline)
              cat jira_header.txt jira_body.txt | sed -e :a -e '\$!N;s/\\n/\\\\n/;ta' | tr '\\t' '  ' | tr -d '\\\n' >> v2_create_issue.json  # escape newlines, convert tabs to spaces, remove any remaining newlines
              cat v2_tail.json >> v2_create_issue.json
              echo "opening jira ticket"
              cat v2_create_issue.json | curl --data-binary @- --request POST --url 'https://${JIRA_URL}/rest/api/2/issue' --user '${JIRA_USR}:${JIRA_PSW}'  --header 'Accept: application/json' --header 'Content-Type: application/json'
            """
          } else {
            echo "no problems detected"
          } //end if/else
        } //end script
        
      } // end steps
    } // end stage "analyze"
    
    
    //stage('Re-tag as prod and push stable image to registry') {
    //  steps {
    //    script {
    //      docker.withRegistry('', HUB_CREDENTIAL) {
    //        dockerImage.push('prod') 
    //        // dockerImage.push takes the argument as a new tag for the image before pushing
    //      }
    //    } // end script
    //  } // end steps
    //} // end stage "retag as prod"

    stage('Clean up') {
      // delete the images locally
      steps {
        sh 'docker rmi ${REPOSITORY}${TAG}'
        // ${REPOSITORY}:prod'
      } // end steps
    } // end stage "clean up"

  } // end stages
} // end pipeline
