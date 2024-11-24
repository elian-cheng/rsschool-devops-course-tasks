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
    parameters {
    booleanParam(name: 'SHOULD_PUSH_TO_ECR', defaultValue: false, description: 'Set to true in build with params to push Docker image to ECR')
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
    AWS_CREDENTIALS = 'aws-credentials'
    REPO_NAME = 'goals-app'
    IMAGE_TAG = 'latest'
    SONAR_PROJECT_KEY = "Goals-App-Check"
    SONAR_LOGIN = "sqp_1c229ea811bd6e48b5b08b84f17052332323ea86"
    SONAR_HOST_URL = "http://51.20.106.145:9000"
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

    stage('SonarQube Analysis') {
      steps {
        container('sonarscanner') {
          script {
          echo "Running SonarQube analysis..."
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

    stage('Push Docker image to ECR') {
      when { expression { params.SHOULD_PUSH_TO_ECR == true } }
      steps {
        container('docker') {
          script {
            echo "Pushing Docker image to ECR..."
            withAWS(credentials: "${AWS_CREDENTIALS}", region: "${AWS_REGION}") {
              sh '''
                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}
                docker tag ${REPO_NAME}:${IMAGE_TAG} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}:${IMAGE_TAG}
                docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}:${IMAGE_TAG}
              '''
            }
          }
        }
      }
    }

    stage('Create ECR Secret') {
        steps {
            container('docker') {
               script {
                echo "Creating ECR secret..."
                withAWS(credentials: "${AWS_CREDENTIALS}", region: "${AWS_REGION}") {
                  sh '''
                    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}
                    kubectl create secret generic ecr-secret --namespace=jenkins --from-file=.dockerconfigjson=\$HOME/.docker/config.json --dry-run=client -o json | kubectl apply -f -
                  '''
                }
              }
            }
        }
    }

    stage('Deploy to Kubernetes with Helm') {
        when { expression { params.SHOULD_PUSH_TO_ECR == true } }
        steps {
            container('helm') {
              script {
                echo "Deploying to Kubernetes with Helm..."
                withAWS(credentials: "${AWS_CREDENTIALS}", region: "${AWS_REGION}") {
                  sh '''
                    helm upgrade --install ${REPO_NAME} ./helm/${REPO_NAME} \\
                    --set image.repository=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME} \\
                    --set image.tag=${IMAGE_TAG} \\
                    -f ./helm/${REPO_NAME}/values.yaml \\
                    --namespace default                  '''
                }
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