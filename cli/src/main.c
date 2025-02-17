#include <stdio.h>

#include <stdlib.h>
#include <string.h>
#include <unistd.h>

void usage(char* cmdline) {
  fprintf(stderr,
	  "Terminal inDeX\n"
	  "Usage: %s [nejprh]\n"
	  "Manage markdown notes in a folder.\n\n"
	  "Subcommands:\n"
	  "  i|init                   Mark folder as the root directory, create a config file\n"
	  "  n|new [template]         Create a new note using a template\n"
	  "  j|journal [time] [date]  Create a journal entry for the year, half, month, quarter, week or date\n"
	  "  e|edit [path]            Open path in $EDITOR\n"
	  "  p|pomodoro               Start a new pomodoro\n"
	  "\n"
	  "Report bugs to: bhalla.kunal@gmail.com\n"
	  , cmdline);
}

void launch_editor(char *path) {
}

void journal(int argc, char *argv[argc + 1]) {
}

void pomodoro(int argc, char *argv[argc + 1]) {
}

void newfile(int argc, char *argv[argc + 1]) {
}

void edit(int argc, char *argv[argc + 1]) {
}

void parse_args(int argc, char *argv[argc +1]) {
  if (argc < 2) {
    usage(argv[0]);
    exit(EXIT_FAILURE);
  }

  const char *cmd = argv[1];

  if (strcmp(cmd, "n") == 0 || strcmp(cmd, "new") == 0) {
      printf("new");
  } else if (strcmp(cmd, "e") == 0 || strcmp(cmd, "edit") == 0) {
      printf("edit");
  } else if (strcmp(cmd, "j") == 0 || strcmp(cmd, "journal") == 0) {
      printf("journal");
  } else if (strcmp(cmd, "p") == 0 || strcmp(cmd, "pomodoro") == 0) {
      printf("pomodoro");
  } else if (strcmp(cmd, "r") == 0 || strcmp(cmd, "ripgrep") == 0) {
      printf("ripgrep");
  } else if (strcmp(cmd, "h") == 0 ||
	     strcmp(cmd, "help") == 0 ||
	     strcmp(cmd, "-h") == 0 ||
	     strcmp(cmd, "--help") == 0) {
      usage(argv[0]);
      exit(EXIT_SUCCESS);
  }
}

int main(int argc, char *argv[argc + 1]) {
  parse_args(argc, argv);
  return EXIT_SUCCESS;
}
