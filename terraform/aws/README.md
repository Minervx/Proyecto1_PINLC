# Terraform - Opción nube (AWS)

Despliega el mismo stack que la opción local (app + Prometheus + Grafana),
sobre ECS Fargate, con las 3 imágenes publicadas en ECR, descubriéndose
internamente vía **Cloud Map** (`pin-lc.local`), y expuestas al público a través
de un **Application Load Balancer** con una URL estable por servicio (no hace
falta ir a buscar la IP de cada tarea a mano).

## Requisitos previos (una sola vez)

1. **Cuenta de AWS** + usuario **IAM** con permisos programáticos (Access Key
   ID + Secret Access Key).
2. **Rol de ejecución de ECS**: IAM → Roles → Create role → caso de uso
   "Elastic Container Service → Elastic Container Service Task" → adjuntar
   `AmazonECSTaskExecutionRolePolicy`. Copiar el ARN.
3. **VPC con al menos 2 subnets en Availability Zones distintas** (el ALB lo
   exige). Alcanza con la VPC por defecto de tu cuenta, que ya trae subnets
   públicas en varias AZs.
4. **AWS CLI configurado**: `aws configure`.
5. **Bootstrap del bucket S3** para el state remoto (una sola vez, con un
   nombre único a nivel global):

   ```bash
   aws s3api create-bucket \
     --bucket pin-lc-task-api-terraform-state \
     --region us-east-1

   aws s3api put-bucket-versioning \
     --bucket pin-lc-task-api-terraform-state \
     --versioning-configuration Status=Enabled
   ```

   Si ese nombre ya está tomado (los buckets S3 son únicos globalmente),
   cambiá el valor de `bucket` en `backend.tf` por otro (por ejemplo,
   agregando tu usuario o número de cuenta) y usá el mismo nombre en el
   comando de arriba.

## 1. Construir y publicar las 3 imágenes en ECR

Primero hay que crear los repositorios (Terraform los crea, pero para el
primer push conviene tenerlos ya):

```bash
cd terraform/aws
terraform init
terraform apply -target=aws_ecr_repository.app \
                 -target=aws_ecr_repository.prometheus \
                 -target=aws_ecr_repository.grafana \
  -var="ecs_execution_role_arn=<ARN del rol>" \
  -var="vpc_id=<vpc-xxxx>" \
  -var='subnet_ids=["subnet-aaaa","subnet-bbbb"]'
```

Login en ECR y build/push (desde la raíz del repo, no desde `terraform/aws`):

```bash
cd ../..
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <account_id>.dkr.ecr.us-east-1.amazonaws.com

TAG=v1

docker build -t <account_id>.dkr.ecr.us-east-1.amazonaws.com/pin-lc-task-api:$TAG .
docker push <account_id>.dkr.ecr.us-east-1.amazonaws.com/pin-lc-task-api:$TAG

docker build -f monitoring/aws/prometheus.Dockerfile \
  -t <account_id>.dkr.ecr.us-east-1.amazonaws.com/pin-lc-task-api-prometheus:$TAG .
docker push <account_id>.dkr.ecr.us-east-1.amazonaws.com/pin-lc-task-api-prometheus:$TAG

docker build -f monitoring/aws/grafana.Dockerfile \
  -t <account_id>.dkr.ecr.us-east-1.amazonaws.com/pin-lc-task-api-grafana:$TAG .
docker push <account_id>.dkr.ecr.us-east-1.amazonaws.com/pin-lc-task-api-grafana:$TAG
```

(En el pipeline de CI/CD esto lo hace automáticamente el job `aws-docker-build-push`,
ver `.github/workflows/ci-cd.yml`.)

## 2. Aplicar el resto de la infraestructura

```bash
cd terraform/aws
terraform apply \
  -var="ecs_execution_role_arn=<ARN del rol>" \
  -var="vpc_id=<vpc-xxxx>" \
  -var='subnet_ids=["subnet-aaaa","subnet-bbbb"]' \
  -var="image_tag=v1"
```

Esto crea: cluster ECS, namespace de Cloud Map, security groups (ALB y tareas),
el Load Balancer con sus 3 listeners/target groups, y los 3 servicios Fargate.
Ya no hace falta crear un security group a mano — Terraform crea los que
necesita (`alb.tf`). Si igual querés sumar otro existente, `security_group_ids`
sigue disponible como lista opcional.

## 3. Acceder a los servicios (URLs estables vía ALB)

Al terminar el `apply`:

```bash
terraform output app_url          # http://<alb-dns>
terraform output prometheus_url   # http://<alb-dns>:9090
terraform output grafana_url      # http://<alb-dns>:3001
```

Esas URLs no cambian aunque ECS recree alguna tarea — a diferencia de usar la
IP pública de la tarea directamente.

- **ECS → Clusters → pin-lc-task-api-cluster → Services**: estado de los 3 servicios.
- **EC2 → Load Balancers → pin-lc-task-api-alb → Target groups**: health checks de cada uno.
- **CloudWatch → Log groups**: `/ecs/pin-lc-task-api`, `/ecs/pin-lc-task-api-prometheus`,
  `/ecs/pin-lc-task-api-grafana`.

## 4. Destruir todo al terminar (evitar costos)

```bash
terraform destroy <mismas variables que el apply>
```

El bucket S3 del backend no se borra con `destroy` (es intencional, para no
perder el historial de states); si querés eliminarlo también:

```bash
aws s3 rm s3://pin-lc-task-api-terraform-state --recursive
aws s3api delete-bucket --bucket pin-lc-task-api-terraform-state --region us-east-1
```

## Referencias oficiales

- Provider AWS: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- Backend S3: https://developer.hashicorp.com/terraform/language/backend/s3
- ALB: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html
- ECS Service Discovery / Cloud Map: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-discovery.html
- Amazon ECR: https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html
- ECS Fargate: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html
