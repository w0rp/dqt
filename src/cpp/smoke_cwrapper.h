#ifndef __SMOKE_CWRAPPER_H_
#define __SMOKE_CWRAPPER_H_

#if defined(_WIN32)
    #if defined(smoke_cwrapper_EXPORTS)
        #define SMOKEC_SPEC __declspec(dllexport)
    #else
        #define SMOKEC_SPEC __declspec(dllimport)
    #endif
#else
    #define SMOKEC_SPEC
#endif

#ifdef __cplusplus
extern "C" {
#endif

SMOKEC_SPEC void dqt_bind_instance(void* classFn, void* object);

SMOKEC_SPEC void* dqt_init_QString_utf16_reference(const short* data, int size);
SMOKEC_SPEC void* dqt_init_QString_utf8_copy(const char* data, int size);
SMOKEC_SPEC void dqt_delete_QString(void* qString);

#ifdef __cplusplus
}
#endif

#endif
