#include "piano.h"
volatile unsigned char last_key, last_note=NO_NOTE, event_count, ready, active;
static unsigned char wait_key(void) {
    unsigned char k;
    do { k=read_key(); } while(!k);
    return normalize_key(k);
}
int main(void) {
    unsigned char family,modern,output=0,slot=0,k,n;
    family=detect_layout();modern=(family==1);
    video_init(modern);
    clear_screen();
    text(0,1,"A2PIANO / A3 TO F5");
    text(0,3,family==2?"UNKNOWN MODEL: CHOOSE YOUR KEYBOARD":
                       (modern?"DETECTED: IIE / LATER":"DETECTED: APPLE II+"));
    text(0,5,"KEYBOARD: O=OLD  N=NEW");
    text(0,6,modern?"RETURN USES NEW (IIE / LATER)":"RETURN USES OLD (II+)");
    do{k=wait_key();}while(k!=13 && k!='O' && k!='N');
    if(k=='O')modern=0;
    if(k=='N')modern=1;
#ifndef SPEAKER_ONLY
    text(0,9,"OUTPUT: RETURN/S=SPEAKER  M=MOCKINGBOARD");
    do{k=wait_key();}while(k!=13 && k!='S' && k!='M');
    if(k=='M') {
        text(0,11,"USE A SLOT WITH A COMPATIBLE CARD.");
        text(0,12,"SLOT 1-7?  ESC CANCELS TO SPEAKER");
        do{k=wait_key();}while(k!=27 && (k<'1' || k>'7'));
        if(k!=27) {
            slot=k-'0';
            text(0,14,"INITIALIZE CARD? Y=YES / OTHER=CANCEL");
            if(wait_key()=='Y')output=1;
        }
    }
#endif
#ifndef SPEAKER_ONLY
    if(output) mb_init(slot);
#endif
    draw_piano(modern,output,slot);
    ready=1;
    for(;;) {
        k=wait_key();
        n=lookup_note(k,modern);
        last_key=k;last_note=n;++event_count;
#ifndef DIAGNOSTIC
        if(n!=NO_NOTE) {
            active=1;
#ifndef SPEAKER_ONLY
            if(output) {
                mb_period=notes[n].ay_period;
                mb_play();
            } else
#endif
            {
            speaker_outer=notes[n].delay_outer;
            speaker_inner=notes[n].delay_inner;
            speaker_count=notes[n].toggles;
            speaker_play();
            }
            active=0;
        }
#endif
    }
}
