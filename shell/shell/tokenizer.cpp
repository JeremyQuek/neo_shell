#include <vector>
#include <string.h>
#include <sstream>
#include "tokenizer.h" 

using namespace std;


Tokenizer::Tokenizer(const string& input) : input_string(input), argc(0), argv(nullptr) {}

void Tokenizer::tokenize() {
    if (!input_tokens.empty()) return;

    stringstream ss(input_string);  
    string token;        
    while (ss >> token) {
        input_tokens.push_back(token);  
        argc++;      
    }
}

char** Tokenizer::ctokenize() {
    if (argv) return argv; 
    tokenize();


    argv = new char*[argc + 1];
    for (int i = 0; i < argc; i++) {
       
        argv[i] = new char[input_tokens[i].size() + 1];
        strcpy(argv[i], input_tokens[i].c_str());
    }
    argv[argc] = nullptr; 
    return argv;
}


Tokenizer::~Tokenizer() {
    if (argv) {
        for (int i = 0; i < argc; i++) {
            delete[] argv[i]; 
        }
        delete[] argv; 
    }
}