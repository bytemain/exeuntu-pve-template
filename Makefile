default: build-exeuntu

build-exeuntu: ## Build the exeuntu Docker image locally
	@echo "Building exeuntu Docker image..."
	docker build -t ghcr.io/boldsoftware/exeuntu:latest .
	@echo "✓ Image built locally as ghcr.io/boldsoftware/exeuntu:latest"

build: build-exeuntu

run: build-exeuntu
	docker run -it \
	  --cap-add=ALL \
	  --security-opt seccomp=unconfined \
	  --security-opt apparmor=unconfined \
	  --cgroupns private \
	  --tmpfs /run \
	  --tmpfs /run/lock \
	  --tmpfs /tmp \
	  --tmpfs /sys/fs/cgroup:rw \
	  ghcr.io/boldsoftware/exeuntu:latest

run-bash: build-exeuntu
	docker run -it \
	  --cap-add=ALL \
	  --security-opt seccomp=unconfined \
	  --security-opt apparmor=unconfined \
	  --cgroupns private \
	  --tmpfs /run \
	  --tmpfs /run/lock \
	  --tmpfs /tmp \
	  --tmpfs /sys/fs/cgroup:rw \
	  ghcr.io/boldsoftware/exeuntu:latest bash

build-pve-template: ## Build a provenance-bound PVE LXC vztmpl archive from source
	sudo ./pve/build-template.sh

test-pve-source: ## Validate PVE scripts and source boundary without a rootfs build
	./pve/test-source.sh
