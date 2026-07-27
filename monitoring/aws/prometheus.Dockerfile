# Imagen custom de Prometheus para la opcion AWS.
# ECS Fargate no soporta bind mounts de archivos locales como Docker Compose,
# asi que la configuracion se "hornea" dentro de la imagen y se publica en ECR.
# Base oficial: https://hub.docker.com/r/prom/prometheus
FROM prom/prometheus:v2.53.0
COPY monitoring/aws/prometheus-aws.yml /etc/prometheus/prometheus.yml
EXPOSE 9090
