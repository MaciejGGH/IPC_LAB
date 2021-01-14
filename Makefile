.ONESHELL:

pg-up:
	docker-compose -f docker-compose.pg.yml up -d

pg-down:
	docker-compose -f docker-compose.pg.yml down

pg-logs:
	docker-compose -f docker-compose.pg.yml logs -f

pg-clean:
	docker-compose -f docker-compose.pg.yml down -v