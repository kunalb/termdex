CC = gcc
CFLAGS = -Wall -Wextra -g
LIBS = -lsqlite3
TARGET = test_extension

all: $(TARGET)

$(TARGET): test.c
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)

clean:
	rm -f $(TARGET)

.PHONY: all clean