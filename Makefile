.PHONY: lint test build deploy destroy build_ami

PUBLIC_KEY_PATH="/home/vagrant/.ssh/id_rsa_fake-expat-claim-service.pub"
KEY_NAME="fake-expat-claim-service"
AMI=$(shell grep 'artifact,0,id' /dev/null deploy/ami-build.log | cut -d, -f6 | cut -d: -f2)
REGION=$(shell grep 'artifact,0,id' /dev/null deploy/ami-build.log | cut -d, -f6 | cut -d: -f1)
PACKER_CMD="/usr/local/bin/packer"

install:
	npm install

lint:
	jshint .

test:
	# Stand up the not real HMRC service
	istanbul cover node_modules/.bin/_mocha test/*

mutation_test:
	npm run stryker

build: install lint test mutation_test

package: install 

build_ami:
	(cd deploy && \
	${PACKER_CMD} build -machine-readable packer.json | tee ami-build.log)
	
deploy:
	(cd deploy && \
	terraform apply -var "key_name=$(KEY_NAME)" -var "public_key_path=$(PUBLIC_KEY_PATH)" -var "aws_region=$(REGION)" -var "aws_ami=$(AMI)")

destroy:
	(cd deploy && \
	terraform destroy -var "key_name=$(KEY_NAME)" -var "public_key_path=$(PUBLIC_KEY_PATH)" -var "aws_region=$(REGION)" -var "aws_ami=$(AMI)")

deploy_inf:
	(cd deploy && \
	terraform apply -var "key_name=$(KEY_NAME)" -var "public_key_path=$(PUBLIC_KEY_PATH)" -var "aws_region=$(REGION)" -var "aws_ami=$(AMI)")

.PHONY: build_docker
build_docker:
	docker build -t fake-expat-claim-service:v5 .

.PHONY: run_container_daemon
run_container_daemon:
	docker run -d -p 8000:8000 --name fake-expat-claim-service -t fake-expat-claim-service:v1

.PHONY: kill_docker
kill_docker:
	docker kill fake-expat-claim-service
	docker rm fake-expat-claim-service

.PHONY: health
health:
	curl -I "http://$(shell cd deploy && terraform output address)/meta/health"

.PHONY: smoke
smoke:
	curl -X POST -H "Content-type: application/json" -d @sample-claim.json -I "http://$(shell cd deploy && terraform output address)/claims"


