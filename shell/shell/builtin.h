#ifndef BUILTIN_H
#define BUILTIN_H

#include <string>

void pwd_command();
void echo_command(const std::string& input);
void which_command(const std::vector<std::string>& input);
void cd_command(const std::vector<std::string>& args);

#endif