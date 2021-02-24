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
    
    
    // we'll need the anchore credential to pass the user
    // and password to syft so it can upload the results
    ANCHORE_CREDENTIAL = "AnchoreJenkinsUser"
    // use credentials to set ANCHORE_USR and ANCHORE_PSW
    ANCHORE = credentials("${ANCHORE_CREDENTIAL}")
    
    // url for anchore-cli
    ANCHORE_CLI_URL = "http://anchore-priv.novarese.net:8228/v1/"
    
    // use credentials to set JIRA_USR and JIRA_PSW
    JIRA_CREDENTIAL = "jira-anchore8"
    JIRA = credentials("${JIRA_CREDENTIAL}")
    JIRA_URL = "anchore8.atlassian.net"
    
    JIRA_PROJECT = "10000"
    JIRA_ASSIGNEE = "5fc52f03f2df6c0076c94c94"
    
    // change repository to your DockerID
    REPOSITORY = "${DOCKER_HUB_USR}/jenkins-anchore-jira-vuln"
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
          docker.withRegistry( '', HUB_CREDENTIAL ) { 
            dockerImage.push() 
          }
        } // end script
      } // end steps      
    } // end stage "build image and tag w build number"
    
    stage('Analyze with Anchore') {
      steps {
        //     
        // analyze image with anchore-cli. pull vunlerabilities,
        // and build payload to open a jira ticket to fix any problems.
        //
        sh """
          ## queue image for analysis
          anchore-cli --url ${ANCHORE_CLI_URL} --u ${ANCHORE_USR} --p ${ANCHORE_PSW} image add ${REPOSITORY}${TAG}
          ## wait for analysis to complete
          anchore-cli --url ${ANCHORE_CLI_URL} --u ${ANCHORE_USR} --p ${ANCHORE_PSW} image wait ${REPOSITORY}${TAG}
          ## pull vulnerability report and wash it through jq
          anchore-cli --json --url ${ANCHORE_CLI_URL} --u ${ANCHORE_USR} --p ${ANCHORE_PSW} image vuln ${REPOSITORY}${TAG} all | \
            jq -r '.vulnerabilities[] | select(.fix | . != "None") | [.package, .vuln, .severity, .fix]|@tsv' > xxx_jira_body.txt
          ##
          ## this jq filter isn't too badd because the vulnerabilty report is pretty small
          ## and straightfowrward (compared to a full evaluation which can include an entire
          ## policy bundle)...
          ## the jq filter essentially selects the vulnerabilities that don't have "None"
          ## listed as the fix (i.e. the ones where we have a known fix we could apply
          ## today) and outputs the package, vunlerability identifier (usually the CVE
          ## number, or security advisory number for vendor advisories), the severity,
          ## and the fix (usually a package version) and formats them all as tab seperated.
          ##
        """
        //
        // you can also do something similar with grype, in this case we
        // want to use jq to select items that do not have null "fixedInVersion" 
        // and output those items' artifact name (i.e. package name) and version 
        // to upgrade to.
        // sh "${GRYPE_LOCATION} -o json ${REPOSITORY}${TAG} | jq -r '.matches[] | select(.vulnerability.fixedInVersion | . != null ) | [.artifact.name, .vulnerability.id, .vulnerability.severity, .vulnerability.fixedInVersion]|@tsv' > jira_body.txt"
        //
      } // end steps
    } // end stage "analyze"

     stage('Open Jira Ticket if Needed') {
      steps {       
        script {
          //
          // this groovy script checks the number of lines in xxx_jira_body.txt, and 
          // if it's not zero, then it opens a jira ticket.  I'm not sure why I did it
          // this way, it would make more sense to just put the wc -l and the if/then
          // logic in the main shell section with the rest of it but here we are.
          //
          DESC_BODY_LINES = sh (
            script: 'cat xxx_jira_body.txt | wc -l',
            returnStdout: true
          ).trim()
          if (DESC_BODY_LINES != '0') {
            sh """
              ### building json for jira
              echo '{ "fields": { "project": { "id": "${JIRA_PROJECT}" }, "issuetype": { "id": "10002" }, "summary": "Anchore detected fixable vulnerabilities", "reporter": { "id": "${JIRA_ASSIGNEE}" }, "labels": [ "anchore" ], "assignee": { "id": "${JIRA_ASSIGNEE}" }, "description": "' | head -c -1 > xxx_jira_header.txt
              echo '${REPOSITORY}${TAG} has fixable issues:' >> xxx_jira_header.txt
              echo >> xxx_jira_header.txt
              cat xxx_jira_header.txt xxx_jira_body.txt | sed -e :a -e '\$!N;s/\\n/\\\\n/;ta' | tr '\\t' '  ' | tr -d '\\\n' > xxx_jira_v2_payload.json  # escape newlines, convert tabs to spaces, remove any remaining newlines
              echo '" } }' >> xxx_jira_v2_payload.json
              echo "opening jira ticket"
              cat xxx_jira_v2_payload.json | curl --data-binary @- --request POST --url 'https://${JIRA_URL}/rest/api/2/issue' --user '${JIRA_USR}:${JIRA_PSW}'  --header 'Accept: application/json' --header 'Content-Type: application/json'
            """
          } else {
            echo "no problems detected"
          } //end if/else
        } //end script
        
      } // end steps
    } // end stage "Open Jira"
    
    
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
