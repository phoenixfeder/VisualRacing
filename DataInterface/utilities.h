#ifndef UTILITIES_H
#define UTILITIES_H

#include <Windows.h>
#include <tlhelp32.h>

class Utilities {
public:
    static bool isProcessRunning(const wchar_t* name);
};


#endif //UTILITIES_H
