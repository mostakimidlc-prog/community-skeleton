pipeline {
    agent any
    environment {
        DOCKERHUB_USER = 'mostakimidlc-prog'   // replace with your Docker Hub username
        IMAGE_NAME = 'uvdesk-app'
    }
    stages {
        stage('Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/mostakimidlc-prog/community-skeleton.git'
            }
        }
        stage('Build Docker Image') {
            steps {
                sh 'docker build -t $DOCKERHUB_USER/$IMAGE_NAME:latest .'
            }
        }
        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-cred', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
                    sh 'docker push $DOCKER_USER/$IMAGE_NAME:latest'
                }
            }
        }
    }
}
