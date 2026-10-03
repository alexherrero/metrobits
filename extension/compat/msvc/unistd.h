// Microsoft's compiler has no <unistd.h>. MicropolisCore's engine includes it,
// and so does our engine host, for the working folder (getcwd, chdir) and
// PATH_MAX. These are the Windows versions of what they use. This folder is on
// the include path only when building with Microsoft's compiler (see
// SConstruct), so the engine itself is unchanged.
//
// Part of Metrobits, which is GPLv3 with Electronic Arts' additional terms
// (see LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).

#pragma once

#include <direct.h>
#include <io.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>

#ifndef PATH_MAX
#define PATH_MAX _MAX_PATH
#endif

#ifndef S_ISDIR
#define S_ISDIR(mode) (((mode) & _S_IFMT) == _S_IFDIR)
#endif
