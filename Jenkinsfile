// FoodHub APPLICATION pipeline (build, test, scan, package, deploy).
// It never changes infrastructure: that is the separate pipeline in jenkins/Jenkinsfile.infra.
//
// Use a "Multibranch Pipeline" job: the "develop" branch is built, tested and scanned, but only "main" is deployed.

pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()              // two deployments must never run at once
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20', artifactNumToKeepStr: '10'))
    }

    triggers {
        githubPush()                           // GitHub webhook: build on every push
        pollSCM('H/5 * * * *')                 // safety net in case a webhook is missed (cheap: only checks for new commits)
    }

    parameters {
        string(name: 'NOTIFY_EMAIL', defaultValue: '', description: 'Optional: email address for the result (needs SMTP configured in Jenkins)')
        booleanParam(name: 'FORCE_DEPLOY', defaultValue: false, description: 'Deploy even when the branch is not main')
    }

    environment {
        AWS_REGION         = 'ap-south-1'
        AWS_DEFAULT_REGION = 'ap-south-1'
        EKS_CLUSTER_NAME   = 'foodhub-dev-eks'
        K8S_NAMESPACE      = 'foodhub'
        SONARQUBE_SERVER   = 'sonarqube'            // name configured in Manage Jenkins > System > SonarQube servers
        TRIVY_CACHE_DIR    = '/var/lib/jenkins/.cache/trivy'
        REPORT_DIR         = 'reports'
        DEPLOYED           = 'false'
    }

    stages {

        // 1 ------------------------------------------------------------------
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_SHORT = sh(script: 'git rev-parse --short=8 HEAD', returnStdout: true).trim()
                    env.BUILD_TAG_NAME = "build-${env.BUILD_NUMBER}"
                    env.SHA_TAG_NAME   = "sha-${env.GIT_SHORT}"
                    echo "Commit ${env.GIT_SHORT}  ->  image tags ${env.BUILD_TAG_NAME} and ${env.SHA_TAG_NAME}"
                }
                sh 'mkdir -p "$REPORT_DIR"'
            }
        }

        // 2 ------------------------------------------------------------------
        stage('Dependency installation') {
            parallel {
                stage('Frontend: npm ci') {
                    steps { dir('frontend') { sh 'npm ci --no-audit --no-fund' } }
                }
                stage('Backend: Maven dependencies') {
                    steps { dir('backend') { sh 'mvn -B -q dependency:go-offline' } }
                }
            }
        }

        // 3 ------------------------------------------------------------------
        stage('Frontend build') {
            steps { dir('frontend') { sh 'npm run build' } }
        }

        // 4 ------------------------------------------------------------------
        stage('Backend Maven build') {
            steps { dir('backend') { sh 'mvn -B clean package -DskipTests' } }
        }

        // 5 ------------------------------------------------------------------
        stage('Unit testing') {
            steps {
                dir('frontend') { sh 'npm test' }
                dir('backend')  { sh 'mvn -B test' }
            }
            post {
                always { junit testResults: 'backend/target/surefire-reports/*.xml', allowEmptyResults: false }
            }
        }

        // 6 ------------------------------------------------------------------
        stage('SonarQube analysis') {
            steps {
                // withSonarQubeEnv injects SONAR_HOST_URL and the token (from a Jenkins credential), so neither is in Git
                withSonarQubeEnv("${SONARQUBE_SERVER}") {
                    sh 'sonar-scanner -Dsonar.projectVersion="${BUILD_TAG_NAME}"'
                }
            }
        }

        // 7 ------------------------------------------------------------------
        stage('Quality gate') {
            steps {
                // SonarQube calls Jenkins back through a webhook; abortPipeline fails the build if the gate is red
                timeout(time: 10, unit: 'MINUTES') { waitForQualityGate abortPipeline: true }
            }
        }

        // 8 ------------------------------------------------------------------
        stage('Trivy filesystem scan') {
            steps {
                // Pass 1 writes the reports and never fails. Pass 2 enforces the policy in trivy.yaml (HIGH/CRITICAL fail).
                sh '''
                    trivy fs --config trivy.yaml --exit-code 0 --format json --output "$REPORT_DIR/trivy-fs.json" .
                    trivy fs --config trivy.yaml --exit-code 0 --format template --template "@jenkins/trivy/html.tpl" --output "$REPORT_DIR/trivy-fs.html" .
                    trivy fs --config trivy.yaml --exit-code 1 .
                '''
            }
        }

        // 9 ------------------------------------------------------------------
        stage('Terraform validation') {
            steps {
                dir('terraform') {
                    sh '''
                        terraform fmt -check -recursive
                        terraform init -backend=false -input=false
                        terraform validate
                    '''
                }
            }
        }

        // 10 -----------------------------------------------------------------
        stage('Trivy IaC scan') {
            steps {
                sh '''
                    trivy config --config trivy.yaml --exit-code 0 --format json --output "$REPORT_DIR/trivy-iac.json" terraform kubernetes docker-compose.yml backend/Dockerfile frontend/Dockerfile
                    trivy config --config trivy.yaml --exit-code 1 terraform kubernetes docker-compose.yml backend/Dockerfile frontend/Dockerfile
                '''
            }
        }

        // 11 -----------------------------------------------------------------
        stage('AWS authentication') {
            // Moved before the image build only because the image name contains the AWS account id.
            // No keys are involved: the AWS CLI uses the role attached to this EC2 instance.
            steps {
                script {
                    def account = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
                    env.ECR_REGISTRY = "${account}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                    sh 'aws sts get-caller-identity --query Arn --output text'
                }
            }
        }

        // 12 -----------------------------------------------------------------
        stage('Docker image build') {
            steps {
                sh '''
                    docker build -t "$ECR_REGISTRY/foodhub-backend:$BUILD_TAG_NAME"  -t "$ECR_REGISTRY/foodhub-backend:$SHA_TAG_NAME"  backend
                    docker build -t "$ECR_REGISTRY/foodhub-frontend:$BUILD_TAG_NAME" -t "$ECR_REGISTRY/foodhub-frontend:$SHA_TAG_NAME" frontend
                '''
            }
        }

        // 13 -----------------------------------------------------------------
        stage('Trivy image scan') {
            steps {
                sh '''
                    for app in backend frontend; do
                      IMG="$ECR_REGISTRY/foodhub-$app:$BUILD_TAG_NAME"
                      trivy image --config trivy.yaml --exit-code 0 --format template --template "@jenkins/trivy/html.tpl" --output "$REPORT_DIR/trivy-image-$app.html" "$IMG"
                      trivy image --config trivy.yaml --exit-code 1 "$IMG"
                    done
                '''
            }
        }

        // 14 + 15 ------------------------------------------------------------
        stage('ECR authentication and image push') {
            steps { sh 'ECR_REGISTRY="$ECR_REGISTRY" BUILD_TAG="$BUILD_TAG_NAME" SHA_TAG="$SHA_TAG_NAME" bash scripts/ecr-push.sh' }
        }

        // 16 -----------------------------------------------------------------
        stage('EKS authentication') {
            when { anyOf { branch 'main'; expression { params.FORCE_DEPLOY } } }
            steps {
                sh '''
                    aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME"
                    kubectl auth can-i update deployments -n "$K8S_NAMESPACE"
                '''
            }
        }

        // 17 -----------------------------------------------------------------
        stage('Kubernetes deployment') {
            when { anyOf { branch 'main'; expression { params.FORCE_DEPLOY } } }
            steps {
                script { env.DEPLOYED = 'true' }
                sh 'ECR_REGISTRY="$ECR_REGISTRY" IMAGE_TAG="$BUILD_TAG_NAME" bash scripts/deploy.sh'
            }
        }

        // 18 -----------------------------------------------------------------
        stage('Rollout verification') {
            when { anyOf { branch 'main'; expression { params.FORCE_DEPLOY } } }
            steps {
                sh '''
                    kubectl -n "$K8S_NAMESPACE" rollout status deployment/foodhub-backend  --timeout=300s
                    kubectl -n "$K8S_NAMESPACE" rollout status deployment/foodhub-frontend --timeout=180s
                    kubectl -n "$K8S_NAMESPACE" get pods -o wide
                '''
            }
        }

        // 19 -----------------------------------------------------------------
        stage('API health check') {
            when { anyOf { branch 'main'; expression { params.FORCE_DEPLOY } } }
            steps { sh 'bash scripts/health-check.sh "$K8S_NAMESPACE"' }
        }
    }

    // 20 ---------------------------------------------------------------------
    post {
        always {
            archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
            publishHTML(target: [reportDir: 'reports', reportFiles: 'trivy-fs.html,trivy-image-backend.html,trivy-image-frontend.html',
                                 reportName: 'Trivy security reports', keepAll: true, allowMissing: true, alwaysLinkToLastBuild: true])
            sh 'docker image prune -f --filter "until=24h" || true'    // keep the disk from filling up
        }
        success {
            echo "SUCCESS: ${env.BUILD_TAG_NAME} (${env.GIT_SHORT})"
            script { notifyByEmail('SUCCESS') }
        }
        failure {
            script {
                if (env.DEPLOYED == 'true') {
                    // ROLLBACK STRATEGY: a deployment happened and a later check failed, so return to the previous revision.
                    echo 'Deployment verification failed: rolling back to the previous revision.'
                    sh 'bash scripts/rollback.sh || true'
                }
                notifyByEmail('FAILURE')
            }
        }
    }
}

def notifyByEmail(String result) {
    if (params.NOTIFY_EMAIL?.trim()) {
        mail to: params.NOTIFY_EMAIL,
             subject: "[FoodHub] ${result}: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
             body: "Result: ${result}\nCommit: ${env.GIT_SHORT}\nTag: ${env.BUILD_TAG_NAME}\nBuild: ${env.BUILD_URL}"
    }
}
