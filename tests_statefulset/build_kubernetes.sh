#!/bin/bash

# USAGE: ./build_kubernetes.sh
# Option 1: With test_dashboard.yaml: ./build_kubernetes.sh
# Option 2: With Helm chart: ./build_kubernetes.sh --use-helm
# NOTE: Run the next script with the tests_statefulset folder as root
export NODE_OPTIONS=--openssl-legacy-provider # used to build angular in mac correctly
cd ../web
npm i
ng build
cd ..
release_dir=./release
artifacts_dir=${release_dir}/artifacts
rm -r -f ${release_dir}
mkdir -p ${artifacts_dir}

GOOS="linux"
GOARCH="amd64"
platform="linux_amd64"
image="fabrizziocht/dashboard:test"
  
go_executable_output_file=dist/${platform}/release/dashboard

echo building go executable for $GOOS $GOARCH, output will be $go_executable_output_file
env CGO_ENABLED=0 GOOS=$GOOS GOARCH=$GOARCH go build -a -o $go_executable_output_file

platform_release_dir=${release_dir}/${platform}
cd ./tests_statefulset
echo preparing release dir ${platform_release_dir}
mkdir -p ${platform_release_dir}/web/
cp -r ../web/dist ${platform_release_dir}/web/
mv ../$go_executable_output_file ${platform_release_dir}

docker build -t ${image} --no-cache --build-arg BIN_PATH=./release/linux_amd64 .
docker push ${image}

if [ ! -z "$1"  ] && [ "$1" == "--use-helm" ]
then
    echo "using helmchart"
    kustomize build --enable-helm | kubectl apply -n dapr-system -f-
else
    echo "using test_dashboard.yml"
    kubectl apply -f ./test_dashboard.yml
fi

kubectl apply -f ./nginx_test.yml

sleep 5

dapr dashboard -k
