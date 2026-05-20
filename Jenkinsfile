pipeline {
    agent none

    environment {
        IMAGE_NAME = 'task-manager'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        REGISTRY = "${env.DOCKER_REGISTRY ?: 'localhost:5000'}"
        JENKINS_AGENT_NAME = 'dynamic-agent'
        // API Jenkins depuis le conteneur master (NE PAS confondre avec JENKINS_URL du job = 8081)
        JENKINS_API_URL = 'http://127.0.0.1:8080'
        JENKINS_AGENT_URL = 'http://jenkins:8080'
        ANSIBLE_SSH_HOST = "${env.ANSIBLE_SSH_HOST ?: '172.17.0.1'}"
        ANSIBLE_SSH_USER = "${env.ANSIBLE_SSH_USER ?: 'ansible'}"
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
                    chmod +x scripts/*.sh
                    export JENKINS_AGENT_SECRET="${JENKINS_AGENT_SECRET}"
                    export JENKINS_AGENT_URL="${JENKINS_AGENT_URL}"
                    unset JENKINS_URL
                    export ANSIBLE_SSH_HOST="${ANSIBLE_SSH_HOST}"
                    export ANSIBLE_SSH_USER="${ANSIBLE_SSH_USER}"
                    ./scripts/run-ansible.sh destroy-agent.yml || true
                    ./scripts/run-ansible.sh create-agent.yml \
                      -e "jenkins_agent_secret=${JENKINS_AGENT_SECRET}"
                '''
                sh '''
                    export JENKINS_API_URL="${JENKINS_API_URL}"
                    export JENKINS_AGENT_NAME="${JENKINS_AGENT_NAME}"
                    ./scripts/wait-for-agent.sh
                '''
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
                            chmod +x scripts/*.sh
                            export IMAGE_TAG="${IMAGE_TAG}"
                            export REGISTRY="${REGISTRY}"
                            export IMAGE_NAME="${IMAGE_NAME}"
                            export ANSIBLE_SSH_HOST="${ANSIBLE_SSH_HOST}"
                            export ANSIBLE_SSH_USER="${ANSIBLE_SSH_USER}"
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
                    chmod +x scripts/*.sh
                    export ANSIBLE_SSH_HOST="${ANSIBLE_SSH_HOST}"
                    export ANSIBLE_SSH_USER="${ANSIBLE_SSH_USER}"
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
