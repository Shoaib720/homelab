# Jenkins-Docker

## How to use this image

### Docker CLI

```
docker volume create jenkins_home

docker run -d\
    --name jenkins \
    -p 8080:8080 \
    -p 50000:50000 \
    --group-add <host_docker_gid> \
    -v jenkins_home:/var/jenkins_home \
    -v /var/run/docker.sock:/var/run/docker.sock \
    shoaib1999/jenkins-docker:lts-jdk11
```

### docker-compose

```
version: '3.9'

services:
  jenkins:
    image: docker.io/shoaib1999/jenkins-docker:lts-jdk11
    ports:
      - '8080:8080'
      - '50000:50000'
    volumes:
      - 'jenkins_home:/var/jenkins_home'
      - '/var/run/docker.sock:/var/run/docker.sock'
    group_add:
      - '<host_docker_gid>'
    
volumes:
  jenkins_home:
    driver: local
```