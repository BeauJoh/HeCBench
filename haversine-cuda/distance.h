#ifndef DIST_H
#define DIST_H

#include <math.h>

#if defined __CUDACC__
#include <cuda.h>

#elif defined __HIPCC__
#include <hip/hip_runtime.h>

#elif defined _OPENMP
#include <omp.h>
typedef struct __attribute__((__aligned__(16)))
{
  double x, y, z, w;
} double4;

#else
#include "common.h"

#endif

#define DEGREE_TO_RADIAN  M_PI / 180.0
#define RADIAN_TO_DEGREE  180.0 / M_PI
#define EARTH_RADIUS_KM   6371.0

#endif

