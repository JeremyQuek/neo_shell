#include <iostream>
#include <string.h>
#include <cctype>
#include <filesystem>
#include <unistd.h>
#include <stdexcept>

#include "builtin.h"
#include "tokenizer.h"
#include "command_table.h"
#include "program.h"

using namespace std;
namespace fs = filesystem;
extern fs::path WORK_DIR;

extern unordered_map<string, Cmd> cmd_table;         //builtin commands
extern unordered_map<string, string> hash_table;    //paths string since we validate it on initialisation

void pwd_command() {
    cout << WORK_DIR.string();
}

void echo_command(const string& input) {
    cout<<input.substr(5,input.size()-5);
}

void which_command(const vector<string>& input) {
    string cmd = input[1];
    auto it = cmd_table.find(cmd);
    if (it != cmd_table.end()) {
        cout << cmd << ": shell built-in command";
        return;
    }

    auto table_it = hash_table.find(cmd);
    if (table_it != hash_table.end()) {
        cout << table_it->second;
        return;
    }

    string found_cmd;
    if (resolve_path(cmd, found_cmd)) {
        cout << found_cmd;
        return;
    }

    cout << "[SYSTEM_ERR] COMMAND NOT FOUND: " << cmd;
}

void cd_command(const vector<string>& input) {
    if (input.size()==1) {
        return;
    }

    try {
        const string& cd_path = input[1];

        fs::path target = (WORK_DIR / cd_path);
        if (fs::exists(target)) {
            if (!fs::is_directory(target)) {
                cout<<"[SYSTEM_ERR] NOT A DIRECTORY: "<<cd_path;
            }
            else{
                WORK_DIR = fs::canonical(target);
                chdir(target.c_str());
                cout<<endl;
            }
        } else {
            cout<<"[SYSTEM_ERR] NO SUCH FILE OR DIRECTORY: "<<cd_path;
        }
    } 
    catch(exception) {
        return;
    }
}


