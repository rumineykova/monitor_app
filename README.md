README
=============

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
	├── rebar
	├── rebar.config
	├── resources
	├── src
	│   └──  parser
	└── test
    	└── test_resources

deps: Dependencies to other projects </br>
ebin: Compilation binary file </br>
include: Header file for data structures</br>
log: Log files</br>
priv: </br>
src: Source code</br>
src/parser: Implementation of Scribble parser</br>
test: eunit testing files</br>
test/test_resources: auxiliar file for testing</br>



