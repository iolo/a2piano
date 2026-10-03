#include "piano.h"
unsigned char __fastcall__ normalize_key(unsigned char key) {
    if (key >= 'a' && key <= 'z') key -= 32;
    return key;
}
unsigned char lookup_note(unsigned char key, unsigned char modern) {
    unsigned char i;
    key=normalize_key(key);
    for(i=0;i<NOTE_COUNT;++i)
        if(key==(modern?notes[i].new_key:notes[i].old_key)) return i;
    return NO_NOTE;
}
