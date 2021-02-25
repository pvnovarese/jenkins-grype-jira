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
    
    // // we don't need this anchore credential for grype usage,
    // // but you could use this if you wanted to replace grype
    // // with anchore-cli and anchore engine.
    // // cf. https://github.com/pvnovarese/jenkins-anchore-jira-vuln/
    //
    // // we'll need the anchore credential to pass the user
    // // and password to syft so it can upload the results
    // ANCHORE_CREDENTIAL = "AnchoreJenkinsUser"
    // // use credentials to set ANCHORE_USR and ANCHORE_PSW
    // ANCHORE = credentials("${ANCHORE_CREDENTIAL}")
    // 
    // // url for anchore-cli
    // ANCHORE_CLI_URL = "http://anchore-priv.novarese.net:8228/v1/"
    
    // use credentials to set JIRA_USR and JIRA_PSW
    // NOTE that this user will be the reporter of record for any
    // tickets we create, and the password for this credential should
    // be an API key, not the normal authentication password for this
    // user.
    JIRA_CREDENTIAL = "jira-cred"
    JIRA = credentials("${JIRA_CREDENTIAL}")
    // name of credential (secret text) with jira URL
    JIRA_URL = "jira-url"
    
    // These are kind of a pain to figure out, you can probably google it
    // but I should document it here, the PROJECT is a numeric ID jira uses
    // internally instead of the text key that most humans see.  Likewise,
    // ASSIGNEE is an internal ID instead of the email address or plain text
    // name that you would normally see.
    // The reporter for the ticket will be set according to the owner of the 
    // credentials we use to authenticate to the api endpoint so we don't 
    // need to worry about that.
    //
    JIRA_PROJECT = "10000"
    JIRA_ASSIGNEE = "5fc52f03f2df6c0076c94c94"
    
    // you can mess with these if you want, it doesn't really matter
    // unless you decide to uncomment the parts below where we push 
    // images to docker hub.  Since we're using grype locally, we don't
    // need to do that in order to analyze the images as we would if 
    // we were using anchore engine, but you might want to do it if
    // (e.g.) an image has zero vulnerabilities or whatever criteria
    // you want to use.
    REPOSITORY = "${DOCKER_HUB_USR}/jenkins-grype-jira"
    TAG = ":devbuild-${BUILD_NUMBER}"   
    
    // set path for executables.  I put these in jenkins_home as noted
    // in README just for convenience in making this example simple
    // to get going quickly, but this is not really a great practice 
    // in general and you may install somewhere else like /usr/local/bin
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
        // analyze image with grype and get vulnerabilites in json format,
        // then use jq to select only vulns with a published fix.  we'll 
        // stash this in a temp file for now.
        //
        sh """
          ${GRYPE_LOCATION} -o json ${REPOSITORY}${TAG} | \
          jq -r '.matches[] | select(.vulnerability.fixedInVersion | . != null ) | [.artifact.name, .vulnerability.id, .vulnerability.severity, .vulnerability.fixedInVersion]|@tsv' > jira_body.txt
        """
        // 
        // the jq filter selects items that do not have null "fixedInVersion" 
        // and outputs those items' artifact name (i.e. package name), the
        // vuln ID (e.g. CVE number), the severity, and version to upgrade to.
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
