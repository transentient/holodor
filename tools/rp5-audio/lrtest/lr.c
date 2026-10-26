/* lrtest.exe: plays lr.wav (next to the exe) once through winmm, the way a Windows game would. */
#include <windows.h>
#include <mmsystem.h>
int WINAPI WinMain(HINSTANCE h, HINSTANCE p, LPSTR c, int n)
{
    PlaySoundA(c && *c ? c : "lr.wav", NULL, SND_FILENAME | SND_SYNC);
    return 0;
}
