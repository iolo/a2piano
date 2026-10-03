#ifndef PIANO_H
#define PIANO_H
#include "notes.h"
unsigned char __fastcall__ read_key(void);
unsigned char __fastcall__ detect_layout(void);
void __fastcall__ video_init(unsigned char modern);
unsigned char __fastcall__ normalize_key(unsigned char key);
unsigned char lookup_note(unsigned char key, unsigned char modern);
void clear_screen(void);
void text(unsigned char x,unsigned char y,const char *s);
void draw_piano(unsigned char modern,unsigned char output,unsigned char slot);
void __fastcall__ mb_init(unsigned char slot);
void mb_play(void);
extern unsigned int mb_period;
void speaker_play(void);
extern unsigned char speaker_outer, speaker_inner;
extern unsigned int speaker_count;
extern volatile unsigned char last_key, last_note, event_count, ready, active;
#endif
