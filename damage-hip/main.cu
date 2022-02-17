#include <stdlib.h>
#include <stdio.h>
#include <hip/hip_runtime.h>
#include "kernel.h"

// threads per block
#define BS 256

double LCG_random_double(uint64_t * seed)
{
  const unsigned long m = 9223372036854775808ULL; // 2^63
  const unsigned long a = 2806196910506780709ULL;
  const unsigned long c = 1ULL;
  *seed = (a * (*seed) + c) % m;
  return (double) (*seed) / (double) m;
}

int main(int argc, char* argv[]) {
  if (argc != 2) {
    printf("Usage: %s <number of points>\n", argv[0]);
    return 1;
  }

  const int n = atoi(argv[1]);
  const int m = (n + BS - 1) / BS; // number of groups

  int *nlist = (int*) malloc (sizeof(int) * n);
  int *family = (int*) malloc (sizeof(int) * m);
  int *n_neigh = (int*) malloc (sizeof(int) * m);
  double *damage = (double*) malloc (sizeof(double) * m);

  unsigned long seed = 123;
  for (int i = 0; i < n; i++) {
    nlist[i] = (LCG_random_double(&seed) > 0.5) ? 1 : -1;
  }

  for (int i = 0; i < m; i++) {
    int s = 0;
    for (int j = 0; j < BS; j++) {
      s += (nlist[i*BS+j] != -1) ? 1 : 0;
    }
    // non-zero values
    family[i] = s + 1 + s * LCG_random_double(&seed);
  }

  int *d_nlist;
  hipMalloc((void**)&d_nlist, sizeof(int)*n);
  hipMemcpy(d_nlist, nlist, sizeof(int)*n, hipMemcpyHostToDevice);

  int *d_family;
  hipMalloc((void**)&d_family, sizeof(int)*m);
  hipMemcpy(d_family, family, sizeof(int)*m, hipMemcpyHostToDevice);

  int *d_n_neigh;
  hipMalloc((void**)&d_n_neigh, sizeof(int)*m);

  double *d_damage;
  hipMalloc((void**)&d_damage, sizeof(double)*m);

  dim3 blocks (BS);
  dim3 grids ((n+BS-1)/BS);

  for (int i = 0; i < 100; i++) 
    damage_of_node <<< grids, blocks, BS*sizeof(int) >>> (
      n, d_nlist, d_family, d_n_neigh, d_damage);

  hipMemcpy(n_neigh, d_n_neigh, sizeof(int)*m, hipMemcpyDeviceToHost);
  hipMemcpy(damage, d_damage, sizeof(double)*m, hipMemcpyDeviceToHost);

  double sum = 0.0;
  for (int i = 0; i < m; i++) sum += damage[i]; 
  printf("Checksum: total damage = %lf\n", sum);

  hipFree(d_nlist);
  hipFree(d_family);
  hipFree(d_n_neigh);
  hipFree(d_damage);

  free(nlist);
  free(family);
  free(n_neigh);
  free(damage);

  return 0;
}
