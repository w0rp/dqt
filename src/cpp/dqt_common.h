#ifndef __DQT_COMMON_H_
#define __DQT_COMMON_H_

#if defined QTD_DLL_WRAPPER_BUILD
#define DQT_DECL  Q_DECL_EXPORT
#else
#define DQT_DECL Q_DECL_IMPORT
#endif

#endif

