
.PHONY: install_bins install_luas 

install_bins:
	mkdir -p "$(DESTDIR)$(BINDIR)"
	cd src/bin && \
	luaver="$(LUA_VERSION)" && [ -n "$$luaver" ] || luaver=`$(LUA) -e 'print(_VERSION:sub(5))'`; \
	for f in $(BIN_FILES); \
	do \
	   cp "$$f" "$(DESTDIR)$(BINDIR)/$$f-$$luaver"; \
	   ln -nfs "$$f-$$luaver" "$(DESTDIR)$(BINDIR)/$$f"; \
	done

install_luas:
	mkdir -p "$(DESTDIR)$(LUADIR)/luarocks"
	cd src/luarocks && for f in $(LUAROCKS_FILES); \
	do \
	   d="$(DESTDIR)$(LUADIR)/luarocks"/`dirname "$$f"` && \
	   mkdir -p "$$d" && \
	   cp "$$f" "$$d" || exit 1; \
	done

