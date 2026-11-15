#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

static void *real_egl(void) {
 static void *handle;
 if (!handle) { handle=dlopen(getenv("GODOT_REAL_EGL"),RTLD_NOW|RTLD_LOCAL); if(!handle) abort(); }
 return handle;
}
static void *real(const char *name) { void *p=dlsym(real_egl(), name); if (!p) abort(); return p; }

EGLAPI EGLBoolean EGLAPIENTRY eglBindAPI(EGLenum api) { typedef EGLBoolean (EGLAPIENTRY *Fn)(EGLenum api); Fn f=(Fn)real("eglBindAPI"); return f(api); }
EGLAPI EGLBoolean EGLAPIENTRY eglBindTexImage(EGLDisplay dpy, EGLSurface surface, EGLint buffer) { typedef EGLBoolean (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLSurface surface, EGLint buffer); Fn f=(Fn)real("eglBindTexImage"); return f(dpy, surface, buffer); }
EGLAPI EGLint EGLAPIENTRY eglClientWaitSync(EGLDisplay dpy, EGLSync sync, EGLint flags, EGLTime timeout) { typedef EGLint (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLSync sync, EGLint flags, EGLTime timeout); Fn f=(Fn)real("eglClientWaitSync"); return f(dpy, sync, flags, timeout); }
EGLAPI EGLBoolean EGLAPIENTRY eglCopyBuffers(EGLDisplay dpy, EGLSurface surface, EGLNativePixmapType target) { typedef EGLBoolean (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLSurface surface, EGLNativePixmapType target); Fn f=(Fn)real("eglCopyBuffers"); return f(dpy, surface, target); }
EGLAPI EGLContext EGLAPIENTRY eglCreateContext(EGLDisplay dpy, EGLConfig config, EGLContext share_context, const EGLint *attrib_list) { typedef EGLContext (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLConfig config, EGLContext share_context, const EGLint *attrib_list); Fn f=(Fn)real("eglCreateContext"); return f(dpy, config, share_context, attrib_list); }
EGLAPI EGLImage EGLAPIENTRY eglCreateImage(EGLDisplay dpy, EGLContext ctx, EGLenum target, EGLClientBuffer buffer, const EGLAttrib *attrib_list) { typedef EGLImage (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLContext ctx, EGLenum target, EGLClientBuffer buffer, const EGLAttrib *attrib_list); Fn f=(Fn)real("eglCreateImage"); return f(dpy, ctx, target, buffer, attrib_list); }
EGLAPI EGLSurface EGLAPIENTRY eglCreatePbufferFromClientBuffer(EGLDisplay dpy, EGLenum buftype, EGLClientBuffer buffer, EGLConfig config, const EGLint *attrib_list) { typedef EGLSurface (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLenum buftype, EGLClientBuffer buffer, EGLConfig config, const EGLint *attrib_list); Fn f=(Fn)real("eglCreatePbufferFromClientBuffer"); return f(dpy, buftype, buffer, config, attrib_list); }
EGLAPI EGLSurface EGLAPIENTRY eglCreatePbufferSurface(EGLDisplay dpy, EGLConfig config, const EGLint *attrib_list) { typedef EGLSurface (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLConfig config, const EGLint *attrib_list); Fn f=(Fn)real("eglCreatePbufferSurface"); return f(dpy, config, attrib_list); }
EGLAPI EGLSurface EGLAPIENTRY eglCreatePixmapSurface(EGLDisplay dpy, EGLConfig config, EGLNativePixmapType pixmap, const EGLint *attrib_list) { typedef EGLSurface (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLConfig config, EGLNativePixmapType pixmap, const EGLint *attrib_list); Fn f=(Fn)real("eglCreatePixmapSurface"); return f(dpy, config, pixmap, attrib_list); }
EGLAPI EGLSurface EGLAPIENTRY eglCreatePlatformPixmapSurface(EGLDisplay dpy, EGLConfig config, void *native_pixmap, const EGLAttrib *attrib_list) { typedef EGLSurface (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLConfig config, void *native_pixmap, const EGLAttrib *attrib_list); Fn f=(Fn)real("eglCreatePlatformPixmapSurface"); return f(dpy, config, native_pixmap, attrib_list); }
EGLAPI EGLSync EGLAPIENTRY eglCreateSync(EGLDisplay dpy, EGLenum type, const EGLAttrib *attrib_list) { typedef EGLSync (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLenum type, const EGLAttrib *attrib_list); Fn f=(Fn)real("eglCreateSync"); return f(dpy, type, attrib_list); }
EGLAPI EGLBoolean EGLAPIENTRY eglDestroyContext(EGLDisplay dpy, EGLContext ctx) { typedef EGLBoolean (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLContext ctx); Fn f=(Fn)real("eglDestroyContext"); return f(dpy, ctx); }
EGLAPI EGLBoolean EGLAPIENTRY eglDestroyImage(EGLDisplay dpy, EGLImage image) { typedef EGLBoolean (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLImage image); Fn f=(Fn)real("eglDestroyImage"); return f(dpy, image); }
EGLAPI EGLBoolean EGLAPIENTRY eglDestroySurface(EGLDisplay dpy, EGLSurface surface) { typedef EGLBoolean (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLSurface surface); Fn f=(Fn)real("eglDestroySurface"); return f(dpy, surface); }
EGLAPI EGLBoolean EGLAPIENTRY eglDestroySync(EGLDisplay dpy, EGLSync sync) { typedef EGLBoolean (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLSync sync); Fn f=(Fn)real("eglDestroySync"); return f(dpy, sync); }
EGLAPI EGLBoolean EGLAPIENTRY eglGetConfigAttrib(EGLDisplay dpy,EGLConfig config,EGLint attribute,EGLint *value) {
 if(attribute==EGL_NATIVE_VISUAL_ID) { const char *v=getenv("GODOT_PBUFFER_VISUAL");*value=v?strtol(v,0,0):33;return EGL_TRUE; }
 typedef EGLBoolean (*Fn)(EGLDisplay,EGLConfig,EGLint,EGLint *);return ((Fn)real("eglGetConfigAttrib"))(dpy,config,attribute,value);
}
EGLAPI EGLBoolean EGLAPIENTRY eglGetConfigs(EGLDisplay dpy, EGLConfig *configs, EGLint config_size, EGLint *num_config) { typedef EGLBoolean (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLConfig *configs, EGLint config_size, EGLint *num_config); Fn f=(Fn)real("eglGetConfigs"); return f(dpy, configs, config_size, num_config); }
EGLAPI EGLContext EGLAPIENTRY eglGetCurrentContext(void) { typedef EGLContext (EGLAPIENTRY *Fn)(void); Fn f=(Fn)real("eglGetCurrentContext"); return f(); }
EGLAPI EGLDisplay EGLAPIENTRY eglGetCurrentDisplay(void) { typedef EGLDisplay (EGLAPIENTRY *Fn)(void); Fn f=(Fn)real("eglGetCurrentDisplay"); return f(); }
EGLAPI EGLSurface EGLAPIENTRY eglGetCurrentSurface(EGLint readdraw) { typedef EGLSurface (EGLAPIENTRY *Fn)(EGLint readdraw); Fn f=(Fn)real("eglGetCurrentSurface"); return f(readdraw); }
EGLAPI EGLint EGLAPIENTRY eglGetError(void) { typedef EGLint (EGLAPIENTRY *Fn)(void); Fn f=(Fn)real("eglGetError"); return f(); }
EGLAPI EGLBoolean EGLAPIENTRY eglGetSyncAttrib(EGLDisplay dpy, EGLSync sync, EGLint attribute, EGLAttrib *value) { typedef EGLBoolean (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLSync sync, EGLint attribute, EGLAttrib *value); Fn f=(Fn)real("eglGetSyncAttrib"); return f(dpy, sync, attribute, value); }
EGLAPI EGLBoolean EGLAPIENTRY eglInitialize(EGLDisplay dpy, EGLint *major, EGLint *minor) { typedef EGLBoolean (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLint *major, EGLint *minor); Fn f=(Fn)real("eglInitialize"); return f(dpy, major, minor); }
EGLAPI EGLBoolean EGLAPIENTRY eglMakeCurrent(EGLDisplay dpy, EGLSurface draw, EGLSurface read, EGLContext ctx) { typedef EGLBoolean (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLSurface draw, EGLSurface read, EGLContext ctx); Fn f=(Fn)real("eglMakeCurrent"); return f(dpy, draw, read, ctx); }
EGLAPI EGLenum EGLAPIENTRY eglQueryAPI(void) { typedef EGLenum (EGLAPIENTRY *Fn)(void); Fn f=(Fn)real("eglQueryAPI"); return f(); }
EGLAPI EGLBoolean EGLAPIENTRY eglQueryContext(EGLDisplay dpy, EGLContext ctx, EGLint attribute, EGLint *value) { typedef EGLBoolean (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLContext ctx, EGLint attribute, EGLint *value); Fn f=(Fn)real("eglQueryContext"); return f(dpy, ctx, attribute, value); }
EGLAPI const char * EGLAPIENTRY eglQueryString(EGLDisplay dpy, EGLint name) {
 typedef const char * (*Fn)(EGLDisplay,EGLint);
 const char *result=((Fn)real("eglQueryString"))(dpy,name);
 static char client[32768], server[32768];
 if(name==EGL_EXTENSIONS && result) { char *b=dpy==EGL_NO_DISPLAY?client:server; snprintf(b,32768,"%s EGL_KHR_platform_x11 EGL_EXT_platform_x11",result);return b; }
 return result;
}
EGLAPI EGLBoolean EGLAPIENTRY eglQuerySurface(EGLDisplay dpy, EGLSurface surface, EGLint attribute, EGLint *value) { typedef EGLBoolean (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLSurface surface, EGLint attribute, EGLint *value); Fn f=(Fn)real("eglQuerySurface"); return f(dpy, surface, attribute, value); }
EGLAPI EGLBoolean EGLAPIENTRY eglReleaseTexImage(EGLDisplay dpy, EGLSurface surface, EGLint buffer) { typedef EGLBoolean (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLSurface surface, EGLint buffer); Fn f=(Fn)real("eglReleaseTexImage"); return f(dpy, surface, buffer); }
EGLAPI EGLBoolean EGLAPIENTRY eglReleaseThread(void) { typedef EGLBoolean (EGLAPIENTRY *Fn)(void); Fn f=(Fn)real("eglReleaseThread"); return f(); }
EGLAPI EGLBoolean EGLAPIENTRY eglSurfaceAttrib(EGLDisplay dpy, EGLSurface surface, EGLint attribute, EGLint value) { typedef EGLBoolean (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLSurface surface, EGLint attribute, EGLint value); Fn f=(Fn)real("eglSurfaceAttrib"); return f(dpy, surface, attribute, value); }
EGLAPI EGLBoolean EGLAPIENTRY eglSwapBuffers(EGLDisplay dpy, EGLSurface surface) { typedef EGLBoolean (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLSurface surface); Fn f=(Fn)real("eglSwapBuffers"); return f(dpy, surface); }
EGLAPI EGLBoolean EGLAPIENTRY eglSwapInterval(EGLDisplay dpy, EGLint interval) { typedef EGLBoolean (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLint interval); Fn f=(Fn)real("eglSwapInterval"); return f(dpy, interval); }
EGLAPI EGLBoolean EGLAPIENTRY eglTerminate(EGLDisplay dpy) { typedef EGLBoolean (EGLAPIENTRY *Fn)(EGLDisplay dpy); Fn f=(Fn)real("eglTerminate"); return f(dpy); }
EGLAPI EGLBoolean EGLAPIENTRY eglWaitClient(void) { typedef EGLBoolean (EGLAPIENTRY *Fn)(void); Fn f=(Fn)real("eglWaitClient"); return f(); }
EGLAPI EGLBoolean EGLAPIENTRY eglWaitGL(void) { typedef EGLBoolean (EGLAPIENTRY *Fn)(void); Fn f=(Fn)real("eglWaitGL"); return f(); }
EGLAPI EGLBoolean EGLAPIENTRY eglWaitNative(EGLint engine) { typedef EGLBoolean (EGLAPIENTRY *Fn)(EGLint engine); Fn f=(Fn)real("eglWaitNative"); return f(engine); }
EGLAPI EGLBoolean EGLAPIENTRY eglWaitSync(EGLDisplay dpy, EGLSync sync, EGLint flags) { typedef EGLBoolean (EGLAPIENTRY *Fn)(EGLDisplay dpy, EGLSync sync, EGLint flags); Fn f=(Fn)real("eglWaitSync"); return f(dpy, sync, flags); }

// Private test adapter: real GPU-API rendering into a software pbuffer, not an onscreen swapchain.
static EGLDisplay display(void) { typedef EGLDisplay (*Fn)(EGLNativeDisplayType); return ((Fn)real("eglGetDisplay"))(EGL_DEFAULT_DISPLAY); }
EGLAPI EGLDisplay EGLAPIENTRY eglGetDisplay(EGLNativeDisplayType d) { (void)d; return display(); }
EGLAPI EGLDisplay EGLAPIENTRY eglGetPlatformDisplay(EGLenum p, void *d, const EGLAttrib *a) { (void)p;(void)d;(void)a;return display(); }
static EGLDisplay EGLAPIENTRY platform_display(EGLenum p, void *d, const EGLint *a) { (void)p;(void)d;(void)a;return display(); }
EGLAPI EGLBoolean EGLAPIENTRY eglChooseConfig(EGLDisplay d,const EGLint *attributes,EGLConfig *configs,EGLint size,EGLint *num) {
 EGLint copy[128]; int i=0;
 for (; attributes && attributes[i]!=EGL_NONE && i<124; i+=2) { copy[i]=attributes[i];copy[i+1]=attributes[i+1]; if(copy[i]==EGL_SURFACE_TYPE)copy[i+1]=EGL_PBUFFER_BIT; }
 copy[i]=EGL_NONE;
 typedef EGLBoolean (*Fn)(EGLDisplay,const EGLint *,EGLConfig *,EGLint,EGLint *);
 return ((Fn)real("eglChooseConfig"))(d,copy,configs,size,num);
}
static EGLSurface surface(EGLDisplay d,EGLConfig c) {
 const EGLint a[]={EGL_WIDTH,960,EGL_HEIGHT,540,EGL_NONE};
 typedef EGLSurface (*Fn)(EGLDisplay,EGLConfig,const EGLint *);
 return ((Fn)real("eglCreatePbufferSurface"))(d,c,a);
}
EGLAPI EGLSurface EGLAPIENTRY eglCreateWindowSurface(EGLDisplay d,EGLConfig c,EGLNativeWindowType w,const EGLint *a) { (void)w;(void)a;return surface(d,c); }
EGLAPI EGLSurface EGLAPIENTRY eglCreatePlatformWindowSurface(EGLDisplay d,EGLConfig c,void *w,const EGLAttrib *a) { (void)w;(void)a;return surface(d,c); }
static EGLSurface EGLAPIENTRY platform_window(EGLDisplay d,EGLConfig c,void *w,const EGLint *a) { (void)w;(void)a;return surface(d,c); }
EGLAPI __eglMustCastToProperFunctionPointerType EGLAPIENTRY eglGetProcAddress(const char *name) {
 if (!strcmp(name,"eglGetConfigAttrib"))return (__eglMustCastToProperFunctionPointerType)eglGetConfigAttrib;
 if (!strcmp(name,"eglQueryString"))return (__eglMustCastToProperFunctionPointerType)eglQueryString;
 if (!strcmp(name,"eglGetPlatformDisplayEXT"))return (__eglMustCastToProperFunctionPointerType)platform_display;
 if (!strcmp(name,"eglCreatePlatformWindowSurfaceEXT"))return (__eglMustCastToProperFunctionPointerType)platform_window;
 if (!strcmp(name,"eglChooseConfig"))return (__eglMustCastToProperFunctionPointerType)eglChooseConfig;
 if (!strcmp(name,"eglGetDisplay"))return (__eglMustCastToProperFunctionPointerType)eglGetDisplay;
 if (!strcmp(name,"eglGetPlatformDisplay"))return (__eglMustCastToProperFunctionPointerType)eglGetPlatformDisplay;
 if (!strcmp(name,"eglCreateWindowSurface"))return (__eglMustCastToProperFunctionPointerType)eglCreateWindowSurface;
 if (!strcmp(name,"eglCreatePlatformWindowSurface"))return (__eglMustCastToProperFunctionPointerType)eglCreatePlatformWindowSurface;
 typedef __eglMustCastToProperFunctionPointerType (*Fn)(const char *);
 return ((Fn)real("eglGetProcAddress"))(name);
}
