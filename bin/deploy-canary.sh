#!/usr/bin/env bash

CANARY_PATH=$rootdir/app
ACCOUNT_ID=806213497162
REGION=us-west-2
EMF_LANGUAGE=java
IMAGE_NAME=emf-$EMF_LANGUAGE-canary
ECS_CLUSTER_NAME=emf-canary-cluster
ECS_TASK_FAMILY=emf-canary-$EMF_LANGUAGE-tasks
ECS_SERVICE_NAME=emf-canary-$EMF_LANGUAGE-service
ECR_ENDPOINT=$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
ECR_REMOTE=$ECR_ENDPOINT/$IMAGE_NAME

pushd $CANARY_PATH
echo 'BUILDING THE DOCKER IMAGE FOR THE CANARY TESTS'
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_ENDPOINT
docker build . -t $IMAGE_NAME:latest
check_exit

echo 'PUSHING THE EXAMPLE DOCKER IMAGE TO ECR'
imageid=$(docker images -q $IMAGE_NAME:latest)
docker tag $imageid $ECR_REMOTE
docker push $ECR_REMOTE
check_exit

echo 'UPDATING THE ECS SERVICE'
aws ecs update-service \
  --region $REGION \
  --cluster $ECS_CLUSTER_NAME \
  --service $ECS_SERVICE_NAME \
  --force-new-deployment \
  --task-definition $(aws ecs register-task-definition \
                        --network-mode awsvpc \
                        --requires-compatibilities FARGATE \
                        --task-role arn:aws:iam::$ACCOUNT_ID:role/ECSCanaryTaskExecutionRole \
                        --execution-role-arn "arn:aws:iam::$ACCOUNT_ID:role/ECSCanaryTaskExecutionRole" \
                        --region $REGION \
                        --memory 512 \
                        --cpu '0.25 vcpu' \
                        --family $ECS_TASK_FAMILY \
                        --container-definitions "$(cat container-definitions.json)" \
                    | jq --raw-output '.taskDefinition.taskDefinitionArn' | awk -F '/' '{ print $2 }')
