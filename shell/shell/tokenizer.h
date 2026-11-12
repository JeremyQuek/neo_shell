#ifndef TOKENS_H   
#define TOKENS_H

#include <string>
#include <vector>

class Tokenizer {
public:
    std::string input_string;
    std::vector<std::string> input_tokens;
    int argc = 0;
    char** argv = nullptr;

    Tokenizer(const std::string& input);

    void tokenize();
    char** ctokenize();
    
    ~Tokenizer();
};

#endif 