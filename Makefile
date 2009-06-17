# This generates a list of synopses of debhelper commands, and substitutes
# it in to the #LIST# line on the man page fed to it on stdin. Must be passed
# parameters of all the executables or pod files to get the synopses from.
# For correct conversion of pod tags (like S< >) #LIST# must be substituted in
# the pod file and not in the troff file.
MAKEMANLIST=perl -e ' \
		undef $$/; \
		foreach (@ARGV) { \
		        open (IN, $$_) or die "$$_: $$!"; \
		        $$file=<IN>; \
		        close IN; \
		        if ($$file=~m/=head1 .*?\n\n(.*?) - (.*?)\n\n/s) { \
		                $$collect.="=item $$1(1)\n\n$$2\n\n"; \
		        } \
		} \
		END { \
			while (<STDIN>) { \
		        	s/\#LIST\#/$$collect/; \
				print; \
			}; \
		}'

# Figure out the `current debhelper version.
VERSION=$(shell expr "`dpkg-parsechangelog |grep Version:`" : '.*Version: \(.*\)')

PERLLIBDIR=$(shell perl -MConfig -e 'print $$Config{vendorlib}')/Debian/Debhelper

POD2MAN=pod2man -c Debhelper -r "$(VERSION)"

DH_AUTO_POD=man/dh_auto_pod

# l10n to be built is determined from .po files
LANGS=$(notdir $(basename $(wildcard man/po4a/po/*.po)))

build: version
	find . -maxdepth 1 -type f -perm +100 -name "dh*" -a ! -name "dh_auto*" \
		-exec $(POD2MAN) {} {}.1 \;
	cat debhelper.pod | \
		$(MAKEMANLIST) `find . -maxdepth 1 -type f -perm +100 -name "dh_*" | sort` | \
		$(POD2MAN) --name="debhelper" --section=7  > debhelper.7
	# Generate dh_auto program PODs and manual pages
	./run find . -maxdepth 1 -type f -perm +100 -name "dh_auto_*" \
		-exec $(DH_AUTO_POD) {} -oman/{}.pod \;
	cd man; for pod in dh_auto_*.pod; do $(POD2MAN) --section=1 $$pod "../$${pod%.pod}.1"; done
	# Generate dh_auto POD and manual page
	./run $(DH_AUTO_POD) -oman/dh_auto.pod
	$(POD2MAN) --section=7 man/dh_auto.pod dh_auto.7
	# Generate dh_auto build system manual pages
	find Debian/Debhelper/Buildsystem -maxdepth 1 -type f -name "*.pm" \
		-exec sh -c 'n=`basename {}`;n=$${n%.pm}; $(POD2MAN) --section=7 --name dh_auto_$$n {} dh_auto_$$n.7' \;
	# Translations
	po4a -L UTF-8 man/po4a/po4a.cfg 
	set -e; \
	for lang in $(LANGS); do \
		dir=man/$$lang; \
		for file in $$dir/dh*.pod; do \
			prog=`basename $$file | sed 's/.pod//'`; \
			$(POD2MAN) $$file $$prog.$$lang.1; \
		done; \
		cat $$dir/debhelper.pod | \
			$(MAKEMANLIST) `find $$dir -type f -maxdepth 1 -name "dh_*.pod" | sort` | \
			$(POD2MAN) --name="debhelper" --section=7 > debhelper.$$lang.7; \
	done

version:
	printf "package Debian::Debhelper::Dh_Version;\n\$$version='$(VERSION)';\n1" > \
		Debian/Debhelper/Dh_Version.pm

clean:
	rm -f *.1 *.7 man/dh_auto*.pod Debian/Debhelper/Dh_Version.pm
	po4a --rm-translations --rm-backups man/po4a/po4a.cfg
	for lang in $(LANGS); do \
		if [ -e man/$$lang ]; then rmdir man/$$lang; fi; \
	done;

install:
	install -d $(DESTDIR)/usr/bin \
		$(DESTDIR)/usr/share/debhelper/autoscripts \
		$(DESTDIR)$(PERLLIBDIR)/Sequence \
		$(DESTDIR)$(PERLLIBDIR)/Buildsystem
	install $(shell find -maxdepth 1 -mindepth 1 -name dh\* -executable |grep -v \.1\$$) $(DESTDIR)/usr/bin
	install -m 0644 autoscripts/* $(DESTDIR)/usr/share/debhelper/autoscripts
	install -m 0644 Debian/Debhelper/*.pm $(DESTDIR)$(PERLLIBDIR)
	install -m 0644 Debian/Debhelper/Sequence/*.pm $(DESTDIR)$(PERLLIBDIR)/Sequence
	install -m 0644 Debian/Debhelper/Buildsystem/*.pm $(DESTDIR)$(PERLLIBDIR)/Buildsystem

test: version
	./run perl -MTest::Harness -e 'runtests grep { ! /CVS/ && ! /\.svn/ && -f && -x } @ARGV' t/* t/buildsystems/*
	# clean up log etc
	./run dh_clean
