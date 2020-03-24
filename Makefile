all: libkashim

ifeq ($(shell uname),Darwin)
RPATH := -Wl,-rpath,'@executable_path/../lib' -Wl,-rpath,'@executable_path'
INSTALL_NAME = -install_name '@rpath/libkashim.dylib'
else ifneq ($(findstring MSYS,$(shell uname)),)
RPATH :=
else
RPATH := -Wl,-rpath,'$$ORIGIN/../lib' -Wl,-rpath,'$$ORIGIN'
endif

$(libdir):
	mkdir -p $(libdir)

libkashim.$(dlext): shim.c
	$(CC) $(CFLAGS) $< -g -o $@ $(LDFLAGS) -shared $(INSTALL_NAME)
libkashim: libkashim.$(dlext)
install-libkashim: $(libdir) libkashim.$(dlext)
	cp libkashim.$(dlext) $(libdir)/

install: install-libkashim

clean:
	rm -rf libkashim.*

.SUFFIXES: