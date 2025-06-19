test:
	@echo "Running tests..."
	@cd tests/docker && docker-compose up --build --exit-code-from sql_test && cd -
	@echo "Tests completed."

.PHONY: test
