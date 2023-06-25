#!/bin/bash
docker run --name practice_task_2 -v ./sql:/root/sql -e POSTGRES_PASSWORD=@sde_password012 -e POSTGRES_USER=test_sde -e POSTGRES_DB=demo -p 5432:5432 -d postgres
