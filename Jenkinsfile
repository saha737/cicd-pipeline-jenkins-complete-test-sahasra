pipeline {
    agent any

    environment {
        DOCKER_IMAGE_NAME = "5460/train-schedule" // replace with your Docker Hub username if different
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
                    catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                        def canaryManifest = readFile('train-schedule-kube-canary.yml')
                            .replaceAll('\\$\\{DOCKER_IMAGE_NAME\\}', "${env.DOCKER_IMAGE_NAME}")
                            .replaceAll('\\$\\{BUILD_NUMBER\\}', "${env.BUILD_NUMBER}")
                        writeFile file: 'canary-updated.yml', text: canaryManifest
                        
                        sh 'kubectl apply -f canary-updated.yml'
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
                    def prodCanaryManifest = readFile('train-schedule-kube-canary.yml')
                        .replaceAll('\\$\\{DOCKER_IMAGE_NAME\\}', "${env.DOCKER_IMAGE_NAME}")
                        .replaceAll('\\$\\{BUILD_NUMBER\\}', "${env.BUILD_NUMBER}")
                    writeFile file: 'prod-canary-updated.yml', text: prodCanaryManifest

                    def prodManifest = readFile('train-schedule-kube.yml')
                        .replaceAll('\\$\\{DOCKER_IMAGE_NAME\\}', "${env.DOCKER_IMAGE_NAME}")
                        .replaceAll('\\$\\{BUILD_NUMBER\\}', "${env.BUILD_NUMBER}")
                    writeFile file: 'prod-updated.yml', text: prodManifest

                    sh 'kubectl apply -f prod-canary-updated.yml'
                    sh 'kubectl apply -f prod-updated.yml'
                }
            }
        }
    }
}
