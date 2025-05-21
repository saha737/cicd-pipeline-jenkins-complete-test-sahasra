pipeline {
    agent any

    environment {
        DOCKER_IMAGE_NAME = "5460/train-schedule"
    }

    stages {
        stage('Build') {
            steps {
                echo 'Running build automation'
                sh './gradlew build --no-daemon'
                archiveArtifacts artifacts: 'dist/trainSchedule.zip'
            }
        }

        stage('Build Docker Image') {
            when {
                expression {
                    return env.GIT_BRANCH?.endsWith('master') || env.GIT_BRANCH?.endsWith('main')
                }
            }
            steps {
                script {
                    app = docker.build(DOCKER_IMAGE_NAME)
                    app.inside {
                        sh 'echo Hello, World!'
                    }
                }
            }
        }

        stage('Debug Branch') {
            steps {
                echo "GIT_BRANCH: ${env.GIT_BRANCH}"
            }
        }

        stage('Push Docker Image') {
            when {
                expression {
                    return env.GIT_BRANCH?.endsWith('master') || env.GIT_BRANCH?.endsWith('main')
                }
            }
            steps {
                script {
                    docker.withRegistry('https://registry.hub.docker.com', '17167163-b09e-4b3a-a9ea-f08bee525e5b') {
                        app.push("${env.BUILD_NUMBER}")
                        app.push("latest")
                    }
                }
            }
        }

        stage('CanaryDeploy') {
            when {
                expression {
                    return env.GIT_BRANCH?.endsWith('master') || env.GIT_BRANCH?.endsWith('main')
                }
            }
            environment {
                CANARY_REPLICAS = 1
            }
            steps {
                script {
                    docker.image('bitnami/kubectl:latest').inside {
                        sh '''
                            sed -i "s|REPLACE_IMAGE|5460/train-schedule:${BUILD_NUMBER}|g" train-schedule-kube-canary.yml > prod-canary-updated.yml
                            kubectl apply -f prod-canary-updated.yml
                        '''
                    }
                }
            }
        }

        stage('DeployToProduction') {
    when {
        expression {
            return env.GIT_BRANCH?.endsWith('master') || env.GIT_BRANCH?.endsWith('main')
        }
    }

    environment {
        CANARY_REPLICAS = 0
    }

    steps {
        input 'Deploy to Production?'
        milestone(1)

        script {
            sh """
                sed 's|\\\${DOCKER_IMAGE_NAME}|${DOCKER_IMAGE_NAME}|g; s|\\\${BUILD_NUMBER}|${BUILD_NUMBER}|g' train-schedule-kube.yml > prod-updated.yml
                sed 's|\\\${DOCKER_IMAGE_NAME}|${DOCKER_IMAGE_NAME}|g; s|\\\${BUILD_NUMBER}|${BUILD_NUMBER}|g' train-schedule-kube-canary.yml > prod-canary-updated.yml
            """

            docker.image('bitnami/kubectl:latest').inside('--entrypoint=""') {
                sh '''
                    echo "$KUBECONFIG_CONTENT" > ~/.kube/config
                    kubectl apply -f prod-canary-updated.yml
                    kubectl apply -f prod-updated.yml
                '''
            }
        }
    }
}

    }
}
