# Makefile for Upkie agents
#
# SPDX-License-Identifier: Apache-2.0

CURDIR_NAME = $(shell basename $(CURDIR))

# Help snippet adapted from:
# http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help:
	@echo "Host targets:\n"
	@grep -P '^[a-zA-Z0-9_-]+:.*? ## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "    \033[36m%-24s\033[0m %s\n", $$1, $$2}'
	@echo "\nRobot targets:\n"
	@grep -P '^[a-zA-Z0-9_-]+:.*?### .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?### "}; {printf "    \033[36m%-24s\033[0m %s\n", $$1, $$2}'
	@echo ""

# We expect an "upkie" host in the SSH config
upload:  ## upload agent to the robot
	ssh upkie mkdir -p $(CURDIR_NAME)
	ssh upkie sudo find $(CURDIR_NAME) -type d -name __pycache__ -user root -exec chmod go+wx {} "\;"
	rsync -Lrtu --delete-after \
		--exclude .pixi \
		--exclude cache/ \
		--progress \
		$(CURDIR)/ upkie:$(CURDIR_NAME)/

run_agent:  ### run agent
	pixi run agent
