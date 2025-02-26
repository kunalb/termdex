CC = gcc
CFLAGS = -Wall -Wextra -fPIC -std=c11 -O2
LIBS = -lsqlite3 -lyaml -lcmark-gfm
TARGET = libmd_files.so

all: $(TARGET)

$(TARGET): md_files.c
	$(CC) $(CFLAGS) -shared -o $@ $< $(LIBS)

clean:
	rm -f $(TARGET)

install: $(TARGET)
	mkdir -p $(DESTDIR)/usr/local/lib
	cp $(TARGET) $(DESTDIR)/usr/local/lib/

.PHONY: all clean install