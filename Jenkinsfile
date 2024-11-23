pipeline {
  agent {
    kubernetes {
      yaml '''
        apiVersion: v1
        kind: Pod
        metadata:
          labels:
            some-label: some-label-value
        spec:
          containers:
          - name: node
            image: timbru31/node-alpine-git
            command:
            - cat
            tty: true
          - name: docker
            image: docker:24.0.5
            command:
            - cat
            tty: true
            volumeMounts:
            - name: docker-socket
              mountPath: /var/run/docker.sock
          - name: sonarscanner
            image: sonarsource/sonar-scanner-cli
            command:
            - cat
            tty: true
          volumes:
          - name: docker-socket
            hostPath:
              path: /var/run/docker.sock
      '''
      retries 2
    }
  }
  triggers {
    GenericTrigger(
      causeString: 'Triggered by GitHub Push',
      token: 'my-git-token', 
      printPostContent: true,   
      printContributedVariables: true, 
      silentResponse: false
    )
  }
  environment {
    AWS_ACCOUNT_ID = '656732674839'
    AWS_REGION = 'eu-north-1'
    ECR_REPOSITORY = 'goals-app'
    IMAGE_TAG = 'latest'
  }
  stages {
    stage('Prepare') {
      steps {
        container('node') {
          script {
            echo "Cloning repository..."
            sh '''
              git clone https://github.com/elian-cheng/rsschool-task6-docker-app app
              cd app
              echo "Repo files:"
              ls -la
            '''
          }
        }
      }
    }

    stage('Install Dependencies') {
      steps {
        container('node') {
          script {
            echo "Installing dependencies..."
            sh '''
              cd app
              npm install
            '''
          }
        }
      }
    }

    stage('Run Tests') {
      steps {
        container('node') {
          script {
            echo "Running tests..."
            sh '''
              cd app
              npm test
            '''
          }
        }
      }
    }

    stage('Fetch Public IP') {
      steps {
        script {
          env.PUBLIC_IP = sh(script: "curl -s http://169.254.169.254/latest/meta-data/public-ipv4", returnStdout: true).trim()
          env.SONAR_HOST_URL = "http://${env.PUBLIC_IP}:9000"
        }
      }
    }

    stage('SonarQube Analysis') {
      environment {
        SONAR_PROJECT_KEY = credentials('sonar-project-key')
        SONAR_LOGIN = credentials('sonar-login-token')
      }
      steps {
        container('sonarscanner') {
          script {
            sh '''
              sonar-scanner \
                -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                -Dsonar.sources=. \
                -Dsonar.host.url=${SONAR_HOST_URL} \
                -Dsonar.login=${SONAR_LOGIN}
            '''
          }
        }
      }
    }

    stage('Install AWS CLI') {
      steps {
        container('docker') {
          script {
            echo "Installing AWS CLI..."
            sh '''
              apk add --no-cache python3 py3-pip
              pip3 install awscli
              aws --version
            '''
          }
        }
      }
    }

    stage('Build Docker Image') {
      steps {
        container('docker') {
          script {
            echo "Building Docker image..."
            sh '''
              cd app
              pwd
              docker build -t goals-app:latest -f Dockerfile .
            '''
          }
        }
      }
    }

    stage('Publish to ECR') {
      steps {
        container('docker') {
          script {
            echo "Publishing Docker image to ECR..."
            sh '''
              aws ecr get-login-password --region eu-north-1 | docker login --username AWS --password-stdin 656732674839.dkr.ecr.eu-north-1.amazonaws.com
              docker tag goals-app:latest 656732674839.dkr.ecr.eu-north-1.amazonaws.com/goals-app:latest
              docker push 656732674839.dkr.ecr.eu-north-1.amazonaws.com/goals-app:latest
            '''
          }
        }
      }
    }
  }
  post {
    success {
      script {
        echo "Pipeline completed successfully!"
        emailext(
          subject: 'Jenkins Pipeline Success',
            body: "Pipeline '${env.JOB_NAME}' (#${env.BUILD_NUMBER}) completed successfully.\n\nCheck results: ${env.BUILD_URL}",
          to: 'eliang.cheng@gmail.com' 
        )
      }
    }
    failure {
      script {
        echo "Pipeline failed!"
        emailext(
          subject: 'Jenkins Pipeline Failure',
            body: "Pipeline '${env.JOB_NAME}' (#${env.BUILD_NUMBER}) failed.\n\nCheck the details here: ${env.BUILD_URL}",
          to: 'eliang.cheng@gmail.com' 
        )
      }
    }
  }
}