#ifndef SUBPROCESS_H
#define SUBPROCESS_H

#include <string>

void start_process(std::string& executable_path, char** args); 
bool resolve_path(std::string& cmd, std::string& executable_path);
#endif