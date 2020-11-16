#!/usr/bin/env bash

sudo snap install yq

## copy the project folder for the phoenix env from STG
echo "PROJECT_NAME: ${PROJECT_NAME}"
echo "PHOENIX_NAME: ${PHOENIX_NAME}"
cp -Rv prd/${PROJECT_NAME}/ stg/${PROJECT_NAME}-${PHOENIX_NAME}/

## run yq to replace namespace
yq write -i stg/${PROJECT_NAME}-${PHOENIX_NAME}/namespace.yaml 'metadata.name' ${PROJECT_NAME}-${PHOENIX_NAME}

for f in $(find stg/${PROJECT_NAME}-${PHOENIX_NAME}/*/ -name '*.yaml'); do
  yq write -i $f 'metadata.namespace' ${PROJECT_NAME}-${PHOENIX_NAME}
done

for f in $(find stg/${PROJECT_NAME}-${PHOENIX_NAME}/helmreleases -name '*.yaml'); do
  yq write -i $f 'metadata.annotations."filter.fluxcd.io/chart-image"' glob:${PHOENIX_NAME}-*
  yq read $f "spec.values.image" | sed "s/\(:\)\(.*\)/\1${PHOENIX_NAME}-${GITHASH}/" | xargs -I '{}' yq write -i $f 'spec.values.image' {}

  LENGTH=$(yq read $f --length 'spec.values.url')
  for (( i=0; i<$LENGTH; i++ )) ; do
    yq read $f "spec.values.url[$i]" | sed "0,/\./s//-${PHOENIX_NAME}./" | xargs -I '{}' yq write -i $f "spec.values.url[$i]" {}
  done

  yq read $f 'spec.values.wordpress.origin' | sed "0,/\./s//-${PHOENIX_NAME}./" | xargs -I '{}' yq write -i $f 'spec.values.wordpress.origin' {}
  yq write -i $f 'spec.values.replicaCount' --style=single 1
  yq write -i $f 'spec.values.cronjobs.active' false
done

## add new phoenix files to the index
git add stg/${PROJECT_NAME}-${PHOENIX_NAME}

echo "Created Phoenix ${PHOENIX_NAME}"
