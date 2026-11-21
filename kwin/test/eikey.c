// eikey FD HOLD_SECONDS TABS: hold Alt, press Tab TABS times, hold HOLD_SECONDS, then release
#include <libei.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <poll.h>
#include <time.h>
static struct ei_device *kb;
static void key(int code,int down){ ei_device_keyboard_key(kb,code,down); ei_device_frame(kb,ei_now(ei_device_get_context(kb))); }
int main(int argc,char**argv){
  int fd=atoi(argv[1]); int hold=atoi(argv[2]); int tabs=atoi(argv[3]);
  struct ei *ei=ei_new_sender(NULL); ei_configure_name(ei,"eikey");
  if(ei_setup_backend_fd(ei,fd)){fprintf(stderr,"setup fail\n");return 1;}
  int stage=0; time_t t0=0;
  for(;;){
    struct pollfd p={ei_get_fd(ei),POLLIN,0};
    poll(&p,1,100); ei_dispatch(ei);
    struct ei_event *e;
    while((e=ei_get_event(ei))){
      switch(ei_event_get_type(e)){
      case EI_EVENT_SEAT_ADDED: ei_seat_bind_capabilities(ei_event_get_seat(e),EI_DEVICE_CAP_KEYBOARD,NULL); break;
      case EI_EVENT_DEVICE_ADDED: {struct ei_device*d=ei_event_get_device(e); if(ei_device_has_capability(d,EI_DEVICE_CAP_KEYBOARD)){kb=ei_device_ref(d);} break;}
      case EI_EVENT_DEVICE_RESUMED: if(kb && ei_event_get_device(e)==kb && !stage){ ei_device_start_emulating(kb,1); stage=1; t0=time(0);
          key(56,1); usleep(200000);
          for(int i=0;i<tabs;i++){ key(15,1); usleep(100000); key(15,0); usleep(100000);} } break;
      case EI_EVENT_DISCONNECT: return 0;
      default: break; }
      ei_event_unref(e);
    }
    if(stage==1 && time(0)-t0>=hold){ key(56,0); usleep(200000); return 0; }
  }
}
