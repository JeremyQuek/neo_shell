#include <iostream>
#include <stdio.h>
#include <string.h>
#include <unordered_map>
#include <cctype>
#include <unistd.h>
#include <filesystem>

#include <poll.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <fcntl.h>

#include <signal.h>
#include "builtin.h"
#include "tokenizer.h"
#include "program.h"
#include "command_table.h"
#include "system/sys_setup.h"



// Set namespace
using namespace std;
namespace fs = filesystem;

// Initialise globals
extern "C" char **environ;
fs::path WORK_DIR = fs::current_path();
unordered_map<string, Cmd> cmd_table;         //builtin commands
vector<fs::path> sys_paths;                   //paths as std::fs::path cause we need to validate dynamic path
unordered_map<string, string> hash_table;     //paths as string since we validate it on initialisation

void flush_stdin();

int main() {setvbuf(stdout, NULL, _IONBF, 0);   
    init_table(cmd_table);
    init_sys_cache();

    signal(SIGINT, SIG_IGN);  
    signal(SIGTSTP, SIG_IGN);

    string line;
    while (true) {
        flush_stdin();
        if (!getline(cin, line)) break;  

        Tokenizer tok(line);
        tok.ctokenize();
        vector<string>& tokens = tok.input_tokens;
        string& cmd = tokens[0];

        auto it = cmd_table.find(cmd);
        if (it != cmd_table.end()) {
            it->second.handler(tok);
        } else {
            string executable_path;
            if (resolve_path(cmd, executable_path)) {
                start_process(executable_path, tok.argv);
            }
            else {
                cout << "[SYSTEM_ERR] UNKNOWN SIGNAl:" << cmd;
            }
        }
        cout<<endl;
    }
    return 0;
}



void flush_stdin() {
    cin.clear();
    struct pollfd pfd;
    pfd.fd = STDIN_FILENO;
    pfd.events = POLLIN;
    // "Drain" while there is data to be read
    // poll returns > 0 if there is data, 0 if timeout, < 0 on error
    while (poll(&pfd, 1, 0) > 0) {
        char c;
        if (read(STDIN_FILENO, &c, 1) <= 0) break; 
    }
    cin.sync();
}
