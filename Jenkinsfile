pipeline {
    agent any

    environment {
        DOCKER_IMAGE_NAME = "sahasra13/train-schedule"
    }

    stages {
        stage('Pre-clean Node Cache') {
            steps {
                sh '''
                rm -rf .gradle/nodejs .gradle/npm ~/.gradle/nodejs ~/.gradle/npm
                rm -rf node_modules
                rm -f package-lock.json   # this project is old; lockfile can trigger npm 3/5 quirks
                '''
            }
        }

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
                    docker.withRegistry('https://index.docker.io/v1/', 'dockerhub-creds') {
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
                    docker.image('registry.k8s.io/kubectl:v1.32.2').inside {
                        sh '''
                            sed -i "s|REPLACE_IMAGE|sahasra13/train-schedule:${BUILD_NUMBER}|g" train-schedule-kube-canary.yml > prod-canary-updated.yml
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
            withCredentials([string(credentialsId: 'kubeconfig-content', variable: 'KUBECONFIG_CONTENT')]) {    

                docker.image('registry.k8s.io/kubectl:v1.32.2').inside('--entrypoint=""') {
                    sh '''
                        set -e
                        mkdir -p ~/.kube
                        echo "$KUBECONFIG_CONTENT" > ~/.kube/config
                        chmod 600 ~/.kube/config
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
}
