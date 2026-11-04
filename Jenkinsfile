pipeline {
    agent { label 'docker-agent' }

    options {
        timeout(time: 10, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        GIT_CREDENTIALS_ID = 'github-pantechgympro-deploy'
        ALLOWED_BRANCHES    = 'qa,staging,prod'
        COMPOSE_FILE        = 'docker-compose.server.yml'
    }

    parameters {
        string(name: 'REPO',   defaultValue: 'gympro-infra', description: 'Repo que disparo el webhook (repository.name)')
        string(name: 'BRANCH', defaultValue: 'refs/heads/qa', description: 'Ref que disparo el webhook (ref)')
    }

    stages {

        stage('Validar rama y componente') {
            steps {
                script {
                    env.TARGET_BRANCH = params.BRANCH.replaceAll('refs/heads/', '')

                    if (!env.ALLOWED_BRANCHES.split(',').contains(env.TARGET_BRANCH)) {
                        currentBuild.result = 'NOT_BUILT'
                        error("Rama '${env.TARGET_BRANCH}' no esta en la lista de ramas protegidas (${env.ALLOWED_BRANCHES}); se omite el pipeline.")
                    }

                    env.BUILD_API = (params.REPO == 'gympro-api' || params.REPO == 'gympro-infra') ? 'true' : 'false'
                    env.BUILD_WEB = (params.REPO == 'gympro-web' || params.REPO == 'gympro-infra') ? 'true' : 'false'

                    echo "Repo disparador: ${params.REPO} | Rama: ${env.TARGET_BRANCH} | API=${env.BUILD_API} WEB=${env.BUILD_WEB}"
                }
            }
        }

        stage('Checkout') {
            steps {
                dir('gympro-infra') {
                    git branch: 'terraform',
                        credentialsId: env.GIT_CREDENTIALS_ID,
                        url: 'git@github.com:PantechGympro/gympro-infra.git'
                }
                script {
                    if (env.BUILD_API == 'true') {
                        dir('gympro-api') {
                            git branch: env.TARGET_BRANCH,
                                credentialsId: env.GIT_CREDENTIALS_ID,
                                url: 'git@github.com:PantechGympro/gympro-api.git'
                        }
                    }
                    if (env.BUILD_WEB == 'true') {
                        dir('gympro-web') {
                            git branch: env.TARGET_BRANCH,
                                credentialsId: env.GIT_CREDENTIALS_ID,
                                url: 'git@github.com:PantechGympro/gympro-web.git'
                        }
                    }
                }
            }
        }

        stage('Validar dependencias') {
            steps {
                dir('gympro-infra') {
                    script {
                        if (env.BUILD_API == 'true' && !fileExists('../gympro-api/requirements.txt')) {
                            error('Falta requirements.txt en gympro-api; no se puede construir la imagen.')
                        }
                        if (env.BUILD_WEB == 'true' && !fileExists('../gympro-web/package-lock.json')) {
                            error('Falta package-lock.json en gympro-web; no se puede construir la imagen.')
                        }
                        // Placeholder de .env para que `docker compose config` no falle
                        // (mismo truco ya usado en la CI de GitHub Actions de este repo).
                        sh 'test -f ../gympro-api/.env || touch ../gympro-api/.env.example'
                    }
                    echo 'Dependencias de los componentes a construir verificadas (instalacion real ocurre dentro de cada imagen Docker).'
                }
            }
        }

        stage('Construir imagenes Docker') {
            steps {
                dir('gympro-infra') {
                    script {
                        def servicios = []
                        if (env.BUILD_API == 'true') servicios << 'api'
                        if (env.BUILD_WEB == 'true') servicios << 'web'
                        sh "docker compose -f ${COMPOSE_FILE} build ${servicios.join(' ')}"
                    }
                }
            }
        }

        stage('Validar contenedores') {
            steps {
                dir('gympro-infra') {
                    script {
                        def servicios = []
                        if (env.BUILD_API == 'true') servicios << 'api'
                        if (env.BUILD_WEB == 'true') servicios << 'web'

                        sh "docker compose -f ${COMPOSE_FILE} up -d --no-deps ${servicios.join(' ')}"
                        sh 'sleep 8'

                        servicios.each { s ->
                            def estado = sh(
                                script: "docker compose -f ${COMPOSE_FILE} ps -q ${s} | xargs docker inspect -f '{{.State.Running}}'",
                                returnStdout: true
                            ).trim()
                            if (estado != 'true') {
                                sh "docker compose -f ${COMPOSE_FILE} logs ${s}"
                                error("El contenedor de '${s}' no quedo corriendo; se detiene el pipeline.")
                            }
                            echo "Contenedor '${s}': OK"
                        }
                    }
                }
            }
        }

        stage('Publicar reporte') {
            steps {
                dir('gympro-infra') {
                    script {
                        writeFile file: 'build-report.md', text: """# Reporte de ejecucion — build ${env.BUILD_NUMBER}

- Repo disparador: ${params.REPO}
- Rama: ${env.TARGET_BRANCH}
- Componentes construidos: API=${env.BUILD_API} WEB=${env.BUILD_WEB}
- Resultado: EXITOSO
- Duracion: ${currentBuild.durationString}
"""
                    }
                    archiveArtifacts artifacts: 'build-report.md', allowEmptyArchive: false
                }
            }
        }
    }

    post {
        always {
            dir('gympro-infra') {
                sh "docker compose -f ${COMPOSE_FILE} down || true"
            }
            cleanWs()
        }
        failure {
            echo "Pipeline FALLO para ${params.REPO}@${env.TARGET_BRANCH} (build ${env.BUILD_NUMBER}) — despliegue detenido, no se continua."
        }
    }
}