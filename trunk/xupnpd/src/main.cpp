#include <stdio.h>
#include <syslog.h>
#include <string.h>
#include <unistd.h>
#include "luaxlib.h"
#include "luaxcore.h"

int main(int argc,char** argv)
{
    const char* p=strrchr(argv[0],'/');

    if(p)
    {
        char location[512];
        int n=p-argv[0];
        if(n>=sizeof(location))
            n=sizeof(location)-1;
        strncpy(location,argv[0],n);
        location[n]=0;

        int rc=chdir(location);

        argv[0]=(char*)p+1;
    }

    lua_State* L=lua_open();
    if(L)
    {
        luaL_openlibs(L);
        luaopen_luaxlib(L);
        luaopen_luaxcore(L);

        lua_newtable(L);
        for(int i=0;i<argc;i++)
        {
            lua_pushinteger(L,i+1);
            lua_pushstring(L,argv[i]);
            lua_rawset(L,-3);        
        }
        lua_setglobal(L,"arg");

        char initfile[128];
        snprintf(initfile,sizeof(initfile),"%s.lua",argv[0]);

        if(luaL_loadfile(L,initfile) || lua_pcall(L,0,0,0))
        {
            const char* s=lua_tostring(L,-1);

            if(core::detached)
                syslog(LOG_INFO,"%s",s);
            else
                fprintf(stderr,"%s\n",s);

            lua_pop(L,1);
        }

        lua_close(L);
    }                                    
    
    return 0;
}
