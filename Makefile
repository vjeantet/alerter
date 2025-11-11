# Makefile for alerter
# macOS User Notifications for the command line

BINARY_NAME=alerter
VERSION=2.0.0
BUILD_DIR=build

# Go build flags
GOFLAGS=-ldflags="-s -w"

.PHONY: all build clean install test help

all: build

## build: Build the alerter binary
build:
	@echo "Building $(BINARY_NAME)..."
	@mkdir -p $(BUILD_DIR)
	CGO_ENABLED=1 go build $(GOFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME) .
	@echo "Built: $(BUILD_DIR)/$(BINARY_NAME)"

## build-release: Build and code sign for release
build-release: build
	@echo "Code signing $(BINARY_NAME)..."
	codesign --force --sign - $(BUILD_DIR)/$(BINARY_NAME)
	@echo "Done!"

## clean: Clean build artifacts
clean:
	@echo "Cleaning..."
	@rm -rf $(BUILD_DIR)
	@go clean
	@echo "Cleaned!"

## install: Install the binary to /usr/local/bin
install: build
	@echo "Installing $(BINARY_NAME) to /usr/local/bin..."
	@mkdir -p /usr/local/bin
	@cp $(BUILD_DIR)/$(BINARY_NAME) /usr/local/bin/$(BINARY_NAME)
	@chmod +x /usr/local/bin/$(BINARY_NAME)
	@echo "Installed!"

## test: Run a test notification
test: build
	@echo "Running test notification..."
	@$(BUILD_DIR)/$(BINARY_NAME) -message "Test notification from alerter $(VERSION)" -title "Alerter Test" -sound default

## test-actions: Test action buttons
test-actions: build
	@echo "Running action button test..."
	@$(BUILD_DIR)/$(BINARY_NAME) -message "Choose an option" -title "Action Test" -actions "Yes,No,Maybe"

## test-reply: Test reply type notification
test-reply: build
	@echo "Running reply test..."
	@$(BUILD_DIR)/$(BINARY_NAME) -reply "Type your response" -message "What is your name?" -title "Reply Test"

## help: Show this help message
help:
	@echo "Alerter $(VERSION) - macOS User Notifications"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'

.DEFAULT_GOAL := help
