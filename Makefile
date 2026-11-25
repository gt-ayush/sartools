SHELL=/bin/bash

V=0.40.0
BUILDTOOLVER ?= $(V)

CHROOTVER=0.12

TOOLS = sartools
SYSCONFDIR = /etc
PREFIX = /usr/local
LIBDIR = $(PREFIX)/share/$(TOOLS)/lib
DATADIR = $(PREFIX)/share/$(TOOLS)
BUILDDIR = build

rwildcard=$(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))

BINPROGS_SRC_BASE = $(wildcard src/base/*.in)
BINPROGS_BASE = $(addprefix $(BUILDDIR)/,$(patsubst src/base/%,bin/%,$(patsubst %.in,%,$(BINPROGS_SRC_BASE))))
BINPROGS_SRC_PKG = $(wildcard src/pkg/*.in)
BINPROGS_PKG = $(addprefix $(BUILDDIR)/,$(patsubst src/pkg/%,bin/%,$(patsubst %.in,%,$(BINPROGS_SRC_PKG))))
BINPROGS_SRC_ISO = $(wildcard src/iso/*.in)
BINPROGS_ISO = $(addprefix $(BUILDDIR)/,$(patsubst src/iso/%,bin/%,$(patsubst %.in,%,$(BINPROGS_SRC_ISO))))

LIBRARY_SRC_BASE = $(call rwildcard,src/lib/base,*.sh)
LIBRARY_BASE = $(addprefix $(BUILDDIR)/,$(patsubst src/%,%,$(patsubst %.in,%,$(LIBRARY_SRC_BASE))))
LIBRARY_SRC_PKG = $(call rwildcard,src/lib/pkg,*.sh)
LIBRARY_PKG = $(addprefix $(BUILDDIR)/,$(patsubst src/%,%,$(patsubst %.in,%,$(LIBRARY_SRC_PKG))))
LIBRARY_SRC_ISO = $(call rwildcard,src/lib/iso,*.sh)
LIBRARY_ISO = $(addprefix $(BUILDDIR)/,$(patsubst src/%,%,$(patsubst %.in,%,$(LIBRARY_SRC_ISO))))

MAKEPKG_CONFIGS=$(wildcard config/makepkg/*)
PACMAN_CONFIGS=$(wildcard config/pacman/*)
SETARCH_ALIASES = $(wildcard config/setarch-aliases.d/*)

TOOLS_CONFIGS_PKG=$(wildcard config/conf/*pkg*)
TOOLS_CONFIGS_ISO=$(wildcard config/conf/*iso*)

COMPLETIONS = $(addprefix $(BUILDDIR)/,$(patsubst %.in,%,$(wildcard contrib/completion/*/*)))

all: binprogs_base binprogs_pkg binprogs_iso library_base library_pkg library_iso conf_base conf_pkg conf_iso completion
binprogs_base: $(BINPROGS_BASE)
binprogs_pkg: $(BINPROGS_PKG)
binprogs_iso: $(BINPROGS_ISO)
library_base: $(LIBRARY_BASE)
library_pkg: $(LIBRARY_PKG)
library_iso: $(LIBRARY_ISO)
completion: $(COMPLETIONS)

edit = sed -e "s|@datadir[@]|$(DATADIR)|g" \
	-e "s|@libdir[@]|$(LIBDIR)|g" \
	-e "s|@sysconfdir[@]|$(SYSCONFDIR)|g" \
	-e "s|@buildtool[@]|$(TOOLS)|g" \
	-e "s|@buildtoolver[@]|$(BUILDTOOLVER)|g" \
	-e "s|@chrootver[@]|$(CHROOTVER)|g"

GEN_MSG = @echo "GEN $(patsubst $(BUILDDIR)/%,%,$@)"

RM = rm -f

define buildInScript
$(1)/%: $(2)%$(3)
	$$(GEN_MSG)
	@mkdir -p $$(dir $$@)
	@$(RM) "$$@"
	@cat $$< | $(edit) >$$@
	@chmod $(4) "$$@"
	@bash -O extglob -n "$$@"
endef

$(eval $(call buildInScript,build/bin,src/base/,.in,755))
$(eval $(call buildInScript,build/bin,src/pkg/,.in,755))
$(eval $(call buildInScript,build/bin,src/iso/,.in,755))
$(eval $(call buildInScript,build/lib,src/lib/,,644))

$(foreach completion,$(wildcard contrib/completion/*),$(eval $(call buildInScript,build/$(completion),$(completion)/,.in,444)))

conf_base:
	@install -d $(BUILDDIR)/pacman.conf.d $(BUILDDIR)/$(TOOLS)
	@cp -a $(PACMAN_CONFIGS) $(BUILDDIR)/pacman.conf.d

conf_pkg:
	@install -d $(BUILDDIR)/makepkg.conf.d $(BUILDDIR)/$(TOOLS)
	@cp -ra $(MAKEPKG_CONFIGS) $(BUILDDIR)/makepkg.conf.d
	@cp -a $(TOOLS_CONFIGS_PKG) $(BUILDDIR)/$(TOOLS)

conf_iso:
	@install -d $(BUILDDIR)/$(TOOLS)
	@cp -a $(TOOLS_CONFIGS_ISO) $(BUILDDIR)/$(TOOLS)

clean:
	rm -rf $(BUILDDIR)

install_base: binprogs_base
	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/$(TOOLS)
	install -dm0755 $(DESTDIR)$(PREFIX)/bin
	install -dm0755 $(DESTDIR)$(DATADIR)/pacman.conf.d
	install -m0755 $(BINPROGS_BASE) $(DESTDIR)$(PREFIX)/bin
	install -dm0755 $(DESTDIR)$(LIBDIR)
	cp -ra $(BUILDDIR)/lib/base $(DESTDIR)$(LIBDIR)

	for conf in $(notdir $(PACMAN_CONFIGS)); do install -Dm0644 $(BUILDDIR)/pacman.conf.d/$$conf $(DESTDIR)$(DATADIR)/pacman.conf.d/$${conf##*/}; done

install_pkg: binprogs_pkg
	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/$(TOOLS)
	install -dm0755 $(DESTDIR)$(PREFIX)/bin
	install -dm0755 $(DESTDIR)$(DATADIR)/setarch-aliases.d
	install -dm0755 $(DESTDIR)$(DATADIR)/makepkg.conf.d
	install -m0755 $(BINPROGS_PKG) $(DESTDIR)$(PREFIX)/bin
	install -dm0755 $(DESTDIR)$(LIBDIR)
	cp -ra $(BUILDDIR)/lib/pkg $(DESTDIR)$(LIBDIR)

	for conf in $(notdir $(TOOLS_CONFIGS_PKG)); do install -Dm0644 $(BUILDDIR)/$(TOOLS)/$$conf $(DESTDIR)$(SYSCONFDIR)/$(TOOLS)/$${conf##*/}; done

	cp -ra $(BUILDDIR)/makepkg.conf.d -t $(DESTDIR)$(DATADIR)

	for a in $(SETARCH_ALIASES); do install -m0644 $$a -t $(DESTDIR)$(DATADIR)/setarch-aliases.d; done
	ln -sf find-libdeps $(DESTDIR)$(PREFIX)/bin/find-libprovides

	install -Dm0644 $(BUILDDIR)/contrib/completion/bash/artixpkg $(DESTDIR)$(PREFIX)/share/bash-completion/completions/artixpkg
	install -Dm0644 $(BUILDDIR)/contrib/completion/zsh/_artixpkg $(DESTDIR)$(PREFIX)/share/zsh/site-functions/_artixpkg

install_iso: binprogs_iso
	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/$(TOOLS)
	install -dm0755 $(DESTDIR)$(PREFIX)/bin
	install -m0755 $(BINPROGS_ISO) $(DESTDIR)$(PREFIX)/bin
	install -dm0755 $(DESTDIR)$(LIBDIR)
	cp -ra $(BUILDDIR)/lib/iso $(DESTDIR)$(LIBDIR)

	for conf in $(notdir $(TOOLS_CONFIGS_ISO)); do install -Dm0644 $(BUILDDIR)/$(TOOLS)/$$conf $(DESTDIR)$(SYSCONFDIR)/$(TOOLS)/$${conf##*/}; done

install: all install_base install_pkg install_iso

uninstall:
	for f in $(notdir $(BINPROGS)); do rm -f $(DESTDIR)$(PREFIX)/bin/$$f; done
	for f in $(notdir $(LIBRARY)); do rm -f $(DESTDIR)$(DATADIR)/lib/$$f; done
	rm -rf $(DESTDIR)$(DATADIR)/lib
	for conf in $(notdir $(TOOLS_CONFIGS)); do rm -f $(DESTDIR)$(SYSCONFDIR)/$(TOOLS)/$${conf##*/}; done
	rm -rf $(DESTDIR)$(DATADIR)/makepkg.conf.d
	for conf in $(notdir $(PACMAN_CONFIGS)); do rm -f $(DESTDIR)$(DATADIR)/pacman.conf.d/$${conf##*/}; done
	for f in $(notdir $(SETARCH_ALIASES)); do rm -f $(DESTDIR)$(DATADIR)/setarch-aliases.d/$$f; done
	rm -f $(DESTDIR)$(PREFIX)/bin/find-libprovides
	rmdir --ignore-fail-on-non-empty \
		$(DESTDIR)$(DATADIR)/setarch-aliases.d \
		$(DESTDIR)$(DATADIR)/pacman.conf.d \
		$(DESTDIR)$(DATADIR) \
		$(DESTDIR)$(SYSCONFDIR)/$(TOOLS)

dist:
	git archive --format=tar --prefix=$(TOOLS)-$(V)/ v$(V) | gzip > $(TOOLS)-$(V).tar.gz
	gpg --detach-sign --use-agent $(TOOLS)-$(V).tar.gz

check: $(BINPROGS_SRC_BASE) $(BINPROGS_SRC_PKG) $(BINPROGS_SRC_ISO) config/makepkg/x86_64.conf contrib/makepkg/PKGBUILD.proto
	shellcheck -x $^

.PHONY: all binprogs_base binprogs_pkg binprogs_iso library_base library_pkg library_iso conf_base conf_pkg conf_iso clean install install_base install_pkg install_iso uninstall dist check contrib
.DELETE_ON_ERROR:
