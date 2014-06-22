README
=============

author: Ferran Obiols

version: alpha v1.2


TODO:
-------
##### DONE

- refactor
- testing: Coverage ~76% 
- configuration checking
- sending projection files

#### PENDENT

- Recover state when crash
- Change projection filename role -> protocol_role
- Complete testing

###### TO FIX
Genearl:
	
	Add description to all modules

db_utils:
 
	get_table: Disc storage? when to update how to decide?
	
monscr_test:
	
	Config_test: Have to recive the config confirmation Asynchornously!!!
	
role:

	manage_projection_file: Directory conflictivity when run form app due to path reference
	
	



Project structure
--------

	├── deps    
	│   ├── amqp_client
	│   ├── goldrush
	│   ├── lager
	│   └── rabbit_common
	├── ebin
	├── include
	├── log
	├── priv
	├── resources
	├── src
	│   └──  parser
	└── test
    	└── test_resources

deps: Dependencies to other projects 

ebin: Compilation binary file 

include: Header file for data structures

log: Log files

priv: 

src: Source code

src/parser: Implementation of Scribble parser

test: eunit testing files

test/test_resources: auxiliar file for testing


