pipeline {
    agent none

    environment {
        IMAGE_NAME = 'task-manager'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        REGISTRY = "${env.DOCKER_REGISTRY ?: 'localhost:5000'}"
        JENKINS_AGENT_NAME = 'dynamic-agent'
        JENKINS_URL = "${env.JENKINS_URL ?: 'http://localhost:8081'}"
        // Définir JENKINS_AGENT_SECRET dans Jenkins → Job → Environment (recommandé)
        // ou créer une credential Secret text id: jenkins-agent-secret
        JENKINS_AGENT_SECRET = "${env.JENKINS_AGENT_SECRET ?: 'a5a0e3edd653bfab20ec5c1ec8baa16dc94b34a962918c33ce6f439f9cbbdfd6'}"
    }

    stages {
        stage('Provision Agent') {
            agent { label 'built-in' }
            steps {
                checkout scm
                sh '''
                    chmod +x scripts/run-ansible.sh scripts/wait-for-agent.sh
                    ./scripts/run-ansible.sh destroy-agent.yml || true
                    ./scripts/run-ansible.sh create-agent.yml \
                      -e "jenkins_agent_secret=${JENKINS_AGENT_SECRET}"
                '''
                sh './scripts/wait-for-agent.sh'
            }
        }

        stage('CI/CD') {
            agent { label 'dynamic-agent' }
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
                        sh '''
                            chmod +x scripts/run-ansible.sh
                            ./scripts/run-ansible.sh deploy.yml \
                              -e "image_tag=${IMAGE_TAG}" \
                              -e "registry=${REGISTRY}" \
                              -e "image_name=${IMAGE_NAME}"
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            node('built-in') {
                checkout scm
                sh '''
                    chmod +x scripts/run-ansible.sh
                    ./scripts/run-ansible.sh destroy-agent.yml || true
                '''
            }
        }
        success {
            echo "Pipeline terminé — Application : http://localhost:8080"
        }
        failure {
            echo 'Pipeline en échec — agent supprimé dans post always.'
        }
    }
}
