#!/bin/bash

# set variables
CUSTOM_VERSION=0.2.4
CUSTOM_TAG=alpine-openldap

# build image openldap
DOCKER_BUILDKIT=0; 

docker build \
  --build-arg=OPENLDAP_VERSION=2.6.10-r0 \
  --tag=johann8/${CUSTOM_TAG}:${CUSTOM_VERSION} \
  --file=Dockerfile . 2>&1 | tee ./build.log

# Result of build
_BUILD=$?

# If Build oK then tag docker image to latest
if ! [ ${_BUILD} = 0 ]; then
   echo "ERROR: Docker Image build was not successful"
   exit 1
else
   echo "Docker Image build successful"
   docker images -a
   docker tag johann8/${CUSTOM_TAG}:${CUSTOM_VERSION} johann8/${CUSTOM_TAG}:latest
fi

# push docker image to dockerhub
if [ ${_BUILD} = 0 ]; then
   echo "Pushing docker images to dockerhub..."
   docker push johann8/${CUSTOM_TAG}:latest
   docker push johann8/${CUSTOM_TAG}:${CUSTOM_VERSION}
   _PUSH=$?
   docker images -a | grep openldap
fi

#delete build
if [ ${_PUSH} = 0 ]; then
   echo "Deleting docker images..."
   docker rmi johann8/${CUSTOM_TAG}:latest
   docker rmi johann8/${CUSTOM_TAG}:${CUSTOM_VERSION}
   #docker rmi $(docker images -f "dangling=true" -q)
   docker images -a
fi
