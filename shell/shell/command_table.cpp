#include <iostream>
#include <vector>
#include <string>
#include <functional>
#include <unordered_map>

#include "tokenizer.h"
#include "command_table.h"
#include "builtin.h"

using table = std::unordered_map<std::string, Cmd>;

void register_cmd(table& cmd_table, std::string name, std::function<void()> func, std::string doc) {
    cmd_table[name] = {name, [func](Tokenizer&) { func(); }, doc};
}

void register_cmd(table& cmd_table,std::string name, std::function<void(const std::string&)> func, std::string doc) {
    cmd_table[name] = {name, [func](Tokenizer& tok) { func(tok.input_string); }, doc};
}

void register_cmd(table& cmd_table,std::string name, std::function<void(const std::vector<std::string>&)> func, std::string doc) {
    cmd_table[name] = {name, [func](Tokenizer& tok) { func(tok.input_tokens); }, doc};
}

void init_table(table& cmd_table) {
    register_cmd(cmd_table, "pwd", pwd_command, "Prints current working directory");
    register_cmd(cmd_table, "exit", []() { exit(0); }, "Exit the shell");

    register_cmd(cmd_table, "echo", echo_command, "Prints input to console");

    register_cmd(cmd_table, "which", which_command, "Shows the shell path");

    register_cmd(cmd_table, "cd", cd_command, "Change directory");

    register_cmd(cmd_table, "help", [&cmd_table](const std::vector<std::string>&) {
        for (auto const& [name, c] : cmd_table) {
            printf("%-10s : %s\n", name.c_str(), c.doc.c_str());
        }
    }, "Displays this table");

    register_cmd(cmd_table, "hi", [](const std::string&) { std::cout << "Hello Neo...\n"; }, "???");
}