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

        // stage('CanaryDeploy') {
        //     when {
        //         expression {
        //             return env.GIT_BRANCH?.endsWith('master') || env.GIT_BRANCH?.endsWith('main')
        //         }
        //     }
        //     environment {
        //         CANARY_REPLICAS = 1
        //     }
        //     steps {
        //         script {
        //             docker.image('registry.k8s.io/kubectl:v1.32.2').inside {
        //                 sh '''
        //                     sed -i "s|REPLACE_IMAGE|sahasra13/train-schedule:${BUILD_NUMBER}|g" train-schedule-kube-canary.yml > prod-canary-updated.yml
        //                     kubectl apply -f prod-canary-updated.yml
        //                 '''
        //             }
        //         }
        //     }
        // }
        stage('DeployToProduction') {
            when {
                expression {
                def b1 = (env.BRANCH_NAME ?: '')
                def b2 = (env.GIT_BRANCH ?: '')
                (b1 == 'master' || b1 == 'main' ||
                b2 == 'master' || b2 == 'main' ||
                b2.endsWith('/master') || b2.endsWith('/main'))
                }
            }
            steps {
                input 'Deploy to Production?'
                milestone(1)
                script {
                    def branchTag = (env.BRANCH_NAME ?: env.GIT_BRANCH ?: 'master')
                        .replaceAll('^origin/', '')
                        .replaceAll('[^a-zA-Z0-9_.-]', '-')
                    env.IMAGE = "${DOCKER_IMAGE_NAME}:${branchTag}-${BUILD_NUMBER}"

                    withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG_FILE')]) {
                        sh """
                          set -eux
                          export KUBECONFIG="$KUBECONFIG_FILE"

                          # Canary rollout (1 pod or whatever your canary manifest sets)
                          sed "s|REPLACE_IMAGE|${IMAGE}|g" train-schedule-kube-canary.yml | kubectl apply -f -
  
                          # Full production rollout
                          sed "s|REPLACE_IMAGE|${IMAGE}|g" train-schedule-kube.yml | kubectl apply -f -
    
                          # Optional visibility
                          kubectl get deploy -l app=train-schedule -o wide
                        """
                    }
                }
            }
        }    
    }
}
