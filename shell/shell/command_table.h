#ifndef COMMAND_TABLE_H
#define COMMAND_TABLE_H

#include <iostream>
#include <vector>
#include <string>
#include <functional>
#include <unordered_map>

#include "tokenizer.h"

struct Cmd {
    std::string name;
    std::function<void(Tokenizer&)> handler; 
    std::string doc;
};

using table = std::unordered_map<std::string, Cmd>;

void register_cmd(table& cmd_table,std::string name, std::function<void()> func, std::string doc);
void register_cmd(table& cmd_table,std::string name, std::function<void(const std::string&)> func, std::string doc);
void register_cmd(table& cmd_table,std::string name, std::function<void(const std::vector<std::string>&)> func, std::string doc);

void init_table(table& cmd_table);

#endif