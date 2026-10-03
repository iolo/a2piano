#include "piano.h"
static unsigned char *row(unsigned char y) {
    return (unsigned char *)(0x400u + ((unsigned int)(y&7)<<7) + (y>>3)*40);
}
static void glyph(unsigned char x,unsigned char y,unsigned char c,unsigned char inverse) {
    row(y)[x]=inverse?(c&0x3f):(c|0x80);
}
void text(unsigned char x,unsigned char y,const char *s) {
    while(*s && x<40) glyph(x++,y,*s++,0);
}
void clear_screen(void) {
    unsigned char x,y;
    for(y=0;y<24;++y) for(x=0;x<40;++x) glyph(x,y,' ',0);
}
void mark_note(unsigned char note,unsigned char playing) {
    const Note *n;
    n=&notes[note];
    /* One blank cell above the label; preserve the key's normal/inverse face. */
    glyph(n->column,n->white?14:9,playing?'*':' ',n->white);
}
void draw_piano(unsigned char modern,unsigned char output,unsigned char slot) {
    unsigned char i,x,y;
    const Note *n;
    char slotstr[2];
    clear_screen();
    text(0,0,"A2PIANO                  A3 - F5");
    text(0,2,output?"OUTPUT: MOCKINGBOARD / SLOT ":"OUTPUT: INTERNAL SPEAKER");
    if(output) {slotstr[0]='0'+slot;slotstr[1]=0;text(28,2,slotstr);}
    text(0,3,modern?"LAYOUT: IIE / LATER":"LAYOUT: II+ / OLD KEYBOARD");
    if(output) text(0,4,"TONE: DECAYING");
    text(0,5,"---------------------------------------");
    /* 13 contiguous white keys, each three cells wide. */
    for(i=0;i<NOTE_COUNT;++i) {
        n=&notes[i];
        if(!n->white) continue;
        x=n->column;
        for(y=8;y<=16;++y) {
            glyph(x,y,' ',1);glyph(x+1,y,' ',1);glyph(x+2,y,':',1);
        }
        glyph(x,15,n->label[0],1);glyph(x+1,15,n->label[1],1);
        glyph(x+1,18,modern?n->new_key:n->old_key,0);
    }
    /* Black keys overlap only actual semitone boundaries. */
    for(i=0;i<NOTE_COUNT;++i) {
        n=&notes[i];
        if(n->white) continue;
        x=n->column;
        for(y=8;y<=12;++y) {glyph(x,y,' ',0);glyph(x+1,y,' ',0);}
        glyph(x,10,n->label[0],0);glyph(x+1,10,'#',0);
        glyph(x,11,n->label[2],0);
        glyph(x,7,modern?n->new_key:n->old_key,0);
    }
    /* Replace nonprinting Tab/Esc and arrow codes with textual legends. */
    text(0,18,"   ");
    text(0,19,modern?"TAB=A3":"ESC=A3  LEFT=E5  RIGHT=F5");
    if(!modern) {text(33,18," L  R ");}
    text(0,20,"SPACE: STOP / ONE NOTE AT A TIME");
    text(0,21,release_supported?"HOLD: PLAY / RELEASE ALL KEYS: STOP":
                               "ONE NOTE AT A TIME / MAX 0.5 SECOND");
    text(0,22,"*: ACTIVE KEY");
    text(0,23,"NORMAL SPEED (1 MHZ) / RESET TO SETUP");
}
