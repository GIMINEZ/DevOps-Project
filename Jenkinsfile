pipeline {
    agent any

    environment {
        IMAGE_NAME = 'task-manager'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        REGISTRY = "${env.DOCKER_REGISTRY ?: 'localhost:5000'}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install & Test') {
            steps {
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install -r requirements-dev.txt
                    pytest tests/ -v --cov=app --cov-report=term-missing
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} ."
                sh "docker tag ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY}/${IMAGE_NAME}:latest"
            }
        }

        stage('Push to Registry') {
            steps {
                sh "docker push ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
                sh "docker push ${REGISTRY}/${IMAGE_NAME}:latest"
            }
        }

        stage('Deploy') {
            steps {
                echo 'Déploiement via Ansible — à configurer selon votre infra'
                // sh 'ansible-playbook -i inventory deploy.yml'
            }
        }
    }

    post {
        always {
            cleanWs()
        }
    }
}
