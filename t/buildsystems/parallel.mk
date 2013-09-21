all: FIRST SECOND

TMPFILE ?= $(CURDIR)/parallel.mk.lock

rmtmpfile:
	@rm -f "$(TMPFILE)"

FIRST: rmtmpfile
	@c=0; \
    while [ $$c -le 5 ] && \
          ([ ! -e "$(TMPFILE)" ] || [ "`cat "$(TMPFILE)"`" != "SECOND" ]); do \
        c=$$(($$c+1)); \
        sleep 0.1; \
    done; \
    rm -f "$(TMPFILE)"; \
    if [ $$c -gt 5 ]; then exit 10; else exit 0; fi

SECOND: rmtmpfile
	@echo $@ > "$(TMPFILE)"

.PHONY: all FIRST SECOND rmtmpfile
