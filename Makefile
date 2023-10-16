## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
##                   COLOR THEME                   ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
DEFAULT=\033[0m 
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
WHITE_FG=\033[37m 
RED_FG=\033[31m 
GREEN_FG=\033[32m 
YELLOW_FG=\033[33m 
BLUE_FG=\033[34m 
PURPLE_FG=\033[35m 
CYAN_FG=\033[36m 
BLACK_FG=\033[30m 
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
WHITE_BG=\033[47m 
RED_BG=\033[41m 
GREEN_BG=\033[42m
YELLOW_BG=\033[43m  
BLUE_BG=\033[44m 
PURPLE_BG=\033[45m
CYAN_BG=\033[46m 
BLACK_BG=\033[40m 
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ## 
##                   VARIABLES                     ## 
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ## 
CONTAINER := sql3
VOLUME := $(shell docker inspect --format='{{range .Mounts}}{{.Name}}{{end}}' $(CONTAINER))

.PHONY: list new prune create_container create_table add_data add_views add_others_parts part3 part4 part5 part6
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ## 
##                    COMMANDS                     ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ## 
list:
	@-docker container ls --filter='name=$(CONTAINER)' 
	@echo VOLUME: $(VOLUME)

new: prune create_container create_table add_data add_views

prune:
	@-docker stop $(CONTAINER) 
	@-docker container rm $(CONTAINER)
	@-docker volume rm $(VOLUME)

	
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ## 
##                     HEPLERS                     ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ## 
create_container: 
	@echo "\n"
	@echo "$(BLACK_FG)$(GREEN_BG)                                                $(DEFAULT)"
	@echo "$(BLACK_FG)$(GREEN_BG)               CREATE CONTAINER                 $(DEFAULT)"
	@echo "$(BLACK_FG)$(GREEN_BG)                                                $(DEFAULT)\n"
	@-docker ps --all
	@echo "_________________________________________________\n"
	@-docker run --name $(CONTAINER) -e POSTGRES_PASSWORD=test12345 -d -p 21000:5432 postgres
	@echo "_________________________________________________\n"
	@-docker ps --all
	@echo "_________________________________________________\n"
	@echo "Waiting for the container to start for 5 seconds ..."
	@sleep 5

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ## 
##                      PARTS                      ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ## 
part1:
	@echo "\n"
	@echo "$(BLACK_FG)$(BLUE_BG)                                                $(DEFAULT)"
	@echo "$(BLACK_FG)$(BLUE_BG)        CREATE STRUCTURE / IMPORT DATA          $(DEFAULT)"
	@echo "$(BLACK_FG)$(BLUE_BG)                                                $(DEFAULT)\n"
	@-PGPASSWORD=test12345 psql -h localhost -p 21000 -U postgres -f part1.sql 
	@-PGPASSWORD=test12345 psql -h localhost -p 21000 -U postgres -f part1_add_data.sql 

part2:
	@echo "\n"
	@echo "$(BLACK_FG)$(PURPLE_BG)                                                $(DEFAULT)"
	@echo "$(BLACK_FG)$(PURPLE_BG)                   ADD VIEWS                    $(DEFAULT)"
	@echo "$(BLACK_FG)$(PURPLE_BG)                                                $(DEFAULT)\n"
	@-PGPASSWORD=test12345 psql -h localhost -p 21000 -U postgres -f part2_1_CustomersView.sql 
	@-PGPASSWORD=test12345 psql -h localhost -p 21000 -U postgres -f part2_2_PurchaseHistory.sql
	@-PGPASSWORD=test12345 psql -h localhost -p 21000 -U postgres -f part2_3_Periods.sql
	@-PGPASSWORD=test12345 psql -h localhost -p 21000 -U postgres -f part2_4_GroupsView.sql

part3:
	@echo "\n"
	@echo "$(BLACK_FG)$(YELLOW_BG)                                                $(DEFAULT)"
	@echo "$(BLACK_FG)$(YELLOW_BG)                    PART 3                      $(DEFAULT)"
	@echo "$(BLACK_FG)$(YELLOW_BG)                                                $(DEFAULT)\n"
	PGPASSWORD=test12345 psql -h localhost -p 21000 -U postgres -f part3.sql

part4:
	@echo "\n"
	@echo "$(BLACK_FG)$(WHITE_BG)                                                $(DEFAULT)"
	@echo "$(BLACK_FG)$(WHITE_BG)                    PART 4                      $(DEFAULT)"
	@echo "$(BLACK_FG)$(WHITE_BG)                                                $(DEFAULT)\n"
	PGPASSWORD=test12345 psql -h localhost -p 21000 -U postgres -f part4.sql 

part5:
	@echo "\n"
	@echo "$(BLACK_FG)$(WHITE_BG)                                                $(DEFAULT)"
	@echo "$(BLACK_FG)$(WHITE_BG)                    PART 5                      $(DEFAULT)"
	@echo "$(BLACK_FG)$(WHITE_BG)                                                $(DEFAULT)\n"
	PGPASSWORD=test12345 psql -h localhost -p 21000 -U postgres -f part5.sql

part6:
	@echo "\n"
	@echo "$(BLACK_FG)$(WHITE_BG)                                                $(DEFAULT)"
	@echo "$(BLACK_FG)$(WHITE_BG)                    PART 6                      $(DEFAULT)"
	@echo "$(BLACK_FG)$(WHITE_BG)                                                $(DEFAULT)\n"
	PGPASSWORD=test12345 psql -h localhost -p 21000 -U postgres -f part6.sql



