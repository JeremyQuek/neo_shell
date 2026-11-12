# --- COMPILER & FLAGS ---
CXX      := g++
CXXFLAGS := -std=c++17 -O3 -Wall

FILES := builtin.cpp tokenizer.cpp command_table.cpp program.cpp ./system/sys_setup.cpp 

TARGET := shell
$(TARGET): main.cpp
	$(CXX) $(CXXFLAGS) main.cpp -o $(TARGET) $(FILES)
