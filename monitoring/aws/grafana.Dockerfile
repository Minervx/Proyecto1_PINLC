# Imagen custom de Grafana para la opcion AWS, con datasource y dashboard
# ya provisionados (mismo patron que el Dockerfile de Prometheus).
# Base oficial: https://hub.docker.com/r/grafana/grafana
FROM grafana/grafana:11.1.0
COPY monitoring/aws/grafana-provisioning-aws/ /etc/grafana/provisioning/
COPY monitoring/aws/dashboards/app-dashboard.json /var/lib/grafana/dashboards/app-dashboard.json
EXPOSE 3000
