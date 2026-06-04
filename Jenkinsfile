def version = "v1.${BUILD_NUMBER}"

def dockerhubAccount = 'dockerhub'
def githubAccount = 'github'

def appSourceRepo = 'https://github.com/Duong-Vu-practice-workspace/web-programming-grading-test1.git'
def appSourceBranch = 'main'

def appConfigRepo = 'https://github.com/Duong-Vu-practice-workspace/web-programming-grading-config-test1.git'
def appConfigBranch = 'main'
def helmValueFile = "values-stg.yaml"

pipeline {
    agent any

    environment {
        DOCKER_REGISTRY = 'https://registry-1.docker.io'
        DOCKERHUB_NAMESPACE = 'vucongtuanduong'
    }

    stages {
        stage('Checkout source') {
            steps {
                git branch: appSourceBranch,
                    credentialsId: githubAccount,
                    url: appSourceRepo
            }
        }

        stage('Build and Push API Service') {
            steps {
                script {
                    sh "git reset --hard && git clean -f"
                    dir('backend/web_programming_grading') {
                        def apiImage = docker.build(
                            "${DOCKERHUB_NAMESPACE}/web-grading-api",
                            "-f Dockerfile.api ."
                        )
                        docker.withRegistry(DOCKER_REGISTRY, dockerhubAccount) {
                            apiImage.push(version)
                            apiImage.push('latest')
                        }
                    }
                }
            }
        }

        stage('Build and Push Executor Service') {
            steps {
                script {
                    dir('backend/web_programming_grading') {
                        def execImage = docker.build(
                            "${DOCKERHUB_NAMESPACE}/web-grading-executor",
                            "-f Dockerfile.executor ."
                        )
                        docker.withRegistry(DOCKER_REGISTRY, dockerhubAccount) {
                            execImage.push(version)
                            execImage.push('latest')
                        }
                    }
                }
            }
        }

        stage('Update config repo') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'github',
                    passwordVariable: 'GIT_PASSWORD',
                    usernameVariable: 'GIT_USERNAME'
                )]) {
                    sh """#!/bin/bash
                        set -e
                        CONFIG_REPO="config-repo"
                        [[ -d \${CONFIG_REPO} ]] && rm -rf \${CONFIG_REPO}
                        git clone ${appConfigRepo} --branch ${appConfigBranch} \${CONFIG_REPO}
                        cd \${CONFIG_REPO}
                        sed -i 's|tag: .*|tag: "${version}"|' ${helmValueFile}
                        git config user.email "jenkins@web-grading.com"
                        git config user.name "Jenkins CI"
                        git add .
                        git commit -m "Update images to version ${version}"
                        git push https://\${GIT_USERNAME}:\${GIT_PASSWORD}@github.com/Duong-Vu-practice-workspace/web-programming-grading-config-test1.git
                        cd ..
                        rm -rf \${CONFIG_REPO}
                    """
                }
            }
        }
    }
}
