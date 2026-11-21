// eiclick FD X Y BUTTON(evdev: 272 links, 273 rechts, 274 mitte) HOLD_SECONDS
#include <libei.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <poll.h>
#include <time.h>
int main(int argc,char**argv){
  int fd=atoi(argv[1]); double x=atof(argv[2]),y=atof(argv[3]); int btn=atoi(argv[4]); int hold=atoi(argv[5]);
  struct ei *ei=ei_new_sender(NULL); ei_configure_name(ei,"eiclick");
  if(ei_setup_backend_fd(ei,fd)){fprintf(stderr,"setup fail\n");return 1;}
  struct ei_device *abs=NULL,*rel=NULL; int stage=0; time_t t0=0;
  for(;;){
    struct pollfd p={ei_get_fd(ei),POLLIN,0}; poll(&p,1,100); ei_dispatch(ei);
    struct ei_event *e;
    while((e=ei_get_event(ei))){
      switch(ei_event_get_type(e)){
      case EI_EVENT_SEAT_ADDED: ei_seat_bind_capabilities(ei_event_get_seat(e),EI_DEVICE_CAP_POINTER,EI_DEVICE_CAP_POINTER_ABSOLUTE,EI_DEVICE_CAP_BUTTON,NULL); break;
      case EI_EVENT_DEVICE_ADDED: {struct ei_device*d=ei_event_get_device(e); fprintf(stderr,"device %s abs=%d rel=%d btn=%d\n",ei_device_get_name(d),ei_device_has_capability(d,EI_DEVICE_CAP_POINTER_ABSOLUTE),ei_device_has_capability(d,EI_DEVICE_CAP_POINTER),ei_device_has_capability(d,EI_DEVICE_CAP_BUTTON));
          if(ei_device_has_capability(d,EI_DEVICE_CAP_POINTER_ABSOLUTE)) abs=ei_device_ref(d); break;}
      case EI_EVENT_DEVICE_RESUMED: if(abs && ei_event_get_device(e)==abs && !stage){ stage=1; t0=time(0);
          ei_device_start_emulating(abs,1);
          ei_device_pointer_motion_absolute(abs,x,y); ei_device_frame(abs,ei_now(ei)); usleep(300000);
          ei_device_button_button(abs,btn,1); ei_device_frame(abs,ei_now(ei)); usleep(100000);
          ei_device_button_button(abs,btn,0); ei_device_frame(abs,ei_now(ei)); } break;
      case EI_EVENT_DISCONNECT: return 0;
      default: break; }
      ei_event_unref(e);
    }
    if(stage==1 && time(0)-t0>=hold) return 0;
  }
}
