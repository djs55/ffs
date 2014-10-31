COMMANDS=Datapath.activate  Datapath.attach  Datapath.deactivate  Datapath.detach

.PHONY: clean
clean:
	rm -f *.exe

.PHONY: test
test:
	# Running the commands will invoke the typechecker
	for command in $(COMMANDS); do \
	        echo $$command ; \
		./$$command --test ; \
	done

DESTDIR?=/
SCRIPTDIR?=/usr/lib/xapi-storage-script/datapath/file

.PHONY: install
install:
	mkdir -p $(DESTDIR)$(SCRIPTDIR)
	install -m 0755 $(COMMANDS) $(DESTDIR)$(SCRIPTDIR)
