#include <vector>
#include <string.h>
#include <unordered_map>

#include <sstream> 
#include <iostream>
#include <fstream>
#include <filesystem>

using namespace std;
namespace fs = filesystem;
extern vector<fs::path> sys_paths;  //paths as std::fs::path cause we need to validate dynamic path
extern unordered_map<string, string> hash_table; //paths string since we validate it on initialisation

void load_cache();  
void load_paths();

void init_sys_cache() {
    try { 
        load_cache(); 
    } catch (const exception& e) { 
        cerr << "Error loading hash table: " << e.what() << endl; 
    }

    try { 
        load_paths(); 
    } catch (const exception& e) { 
        cerr << "Error loading system paths: " << e.what() << endl; 
    }
}

void load_cache(){
    ifstream file("../src/shell/system/hash_table.alias");
    if (!file.is_open()) {
        cerr << "Could not read source shell hash file!" << endl;
        return;
    }

    string line;
    while (getline(file, line)) {
        int idx = line.find('=');
        if (idx != string::npos) {
            string executable_cmd(line.substr(0, idx));
            string executable_path(line.substr(idx+1));
            hash_table[executable_cmd] = executable_path;
        }
    }
    file.close();
}

//todo fix shell env path
void load_paths() {
    std::ifstream file("../src/shell/system/sys_path.alias");
    if (!file.is_open()) {
        cerr << "Could not read source shell sys path!" << endl;
        return;
    }

    std::string segment;
    while (std::getline(file, segment, ':')) {
        if (segment.empty()) continue;

        fs::path current_p(segment);
        if (!fs::exists(current_p) || !fs::is_directory(current_p)) {
            continue; 
        }
        try {
            sys_paths.push_back(fs::canonical(current_p));
        } catch (const fs::filesystem_error& e) {
            continue; 
        }
  
    }
    file.close();
}