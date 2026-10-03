#ifndef NOTES_H
#define NOTES_H
#define NOTE_COUNT 21
#define NO_NOTE 255
/* Generated from equal temperament; all pitch and mapping data live here. */
typedef struct {
    char label[4];
    unsigned char old_key, new_key, white, column;
    unsigned char delay_outer, delay_inner;
    unsigned int toggles, ay_period;
} Note;
extern const Note notes[NOTE_COUNT];
#endif
