test:
	@echo "Running tests..."
	PGPASSWORD=postgres
	@export PGPASSWORD
	@docker-compose -f docker-compose.test.yml run -d --rm migrate_test
	@pg_prove tests/*.sql -d metrics -U postgres -h localhost -p 5432
	@docker-compose -f docker-compose.test.yml down -v --remove-orphans

.PHONY: test
