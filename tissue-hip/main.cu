/*
  Accumulate contributions of tissue source
  strengths "qt" and previous solute levels "ctprev" to tissue solute levels "ct".
  Each tissue point is assigned one or more threads: step is the number of threads
  This spreads it over more threads.
  TWS September 2014
 */
 
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <hip/hip_runtime.h>

void reference(
    const   int *__restrict__ d_tisspoints,
    const float *__restrict__ d_gtt,
    const float *__restrict__ d_gbartt,
          float *__restrict__ d_ct,
    const float *__restrict__ d_ctprev,
    const float *__restrict__ d_qt,
    int nnt, int nntDev, int step, int isp)
{
  for (int i = 0; i < step * nnt; i++) {
    int jtp,ixyz,ix,iy,iz,jx,jy,jz,istep;
    int nnt2 = 2*nnt;
    float p = 0.f;

    int itp = i/step;
    int itp1 = i%step;
    if(itp < nnt) {
      ix = d_tisspoints[itp];
      iy = d_tisspoints[itp+nnt];
      iz = d_tisspoints[itp+nnt2];
      for(jtp=itp1; jtp<nnt; jtp+=step){
        jx = d_tisspoints[jtp];
        jy = d_tisspoints[jtp+nnt];
        jz = d_tisspoints[jtp+nnt2];
        ixyz = abs(jx-ix) + abs(jy-iy) + abs(jz-iz) + (isp-1)*nntDev;
        p += d_gtt[ixyz]*d_ctprev[jtp] + d_gbartt[ixyz]*d_qt[jtp];
      }
      if(itp1 == 0) d_ct[itp] = p;
    }

    for(istep=1; istep<step; istep++)
      if(itp1 == istep && itp < nnt) d_ct[itp] += p;
  }
}

__global__ void tissue(
    const   int *__restrict__ d_tisspoints,
    const float *__restrict__ d_gtt,
    const float *__restrict__ d_gbartt,
          float *__restrict__ d_ct,
    const float *__restrict__ d_ctprev,
    const float *__restrict__ d_qt,
    int nnt, int nntDev, int step, int isp)
{
  int jtp,ixyz,ix,iy,iz,jx,jy,jz,istep;
  int nnt2 = 2*nnt;
  float p = 0.f;

  const int i = blockDim.x * blockIdx.x + threadIdx.x;
  const int itp = i/step;
  const int itp1 = i%step;
  if(itp < nnt) {
    ix = d_tisspoints[itp];
    iy = d_tisspoints[itp+nnt];
    iz = d_tisspoints[itp+nnt2];
    for(jtp = itp1; jtp < nnt; jtp += step) {
      jx = d_tisspoints[jtp];
      jy = d_tisspoints[jtp+nnt];
      jz = d_tisspoints[jtp+nnt2];
      ixyz = abs(jx-ix) + abs(jy-iy) + abs(jz-iz) + (isp-1)*nntDev;
      p += d_gtt[ixyz]*d_ctprev[jtp] + d_gbartt[ixyz]*d_qt[jtp];
    }
    if(itp1 == 0) d_ct[itp] = p;
  }
  // d_ct is incremented in sequence from the needed threads
  for(istep=1; istep<step; istep++)
    if(itp1 == istep && itp < nnt) d_ct[itp] += p;
}

int main() {
  int *d_tisspoints;
  float *d_gtt;
  float *d_gbartt;
  float *d_ct;
  float *d_ctprev;
  float *d_qt;
  const int nnt = 4000;
  const int nntDev = 4000;
  const int nsp = 2;

    int* h_tisspoints = (int*) malloc (3*nntDev*sizeof(int));
  float* h_gtt = (float*) malloc (nsp*nntDev*sizeof(float));
  float* h_gbartt = (float*) malloc (nsp*nntDev*sizeof(float));
  float* h_ct = (float*) malloc (nntDev*sizeof(float));
  float* h_ctprev = (float*) malloc (nntDev*sizeof(float));
  float* h_qt = (float*) malloc (nntDev*sizeof(float));
  float* h_ct_gold = (float*) malloc (nntDev*sizeof(float));

  // bound the distance between any two 3D points 
  for (int i = 0; i < 3 * nntDev; i++) {
    h_tisspoints[i] = rand() % (nntDev / 3);
  }
  for (int i = 0; i < nsp * nntDev; i++) {
    h_gtt[i] = rand() / (float)RAND_MAX;
    h_gbartt[i] = rand() / (float)RAND_MAX;
  }
  for (int i = 0; i < nntDev; i++) {
    h_ct[i] = h_ct_gold[i] = 0;
    h_ctprev[i] = rand() / (float)RAND_MAX;
    h_qt[i] = rand() / (float)RAND_MAX;
  }

  hipMalloc((void **)&d_tisspoints, 3*nntDev*sizeof(int));
  hipMalloc((void **)&d_gtt, nsp*nntDev*sizeof(float));
  hipMalloc((void **)&d_gbartt, nsp*nntDev*sizeof(float));
  hipMalloc((void **)&d_ct, nntDev*sizeof(float));
  hipMalloc((void **)&d_ctprev, nntDev*sizeof(float));
  hipMalloc((void **)&d_qt, nntDev*sizeof(float));

  hipMemcpy(d_tisspoints, h_tisspoints, 3*nntDev*sizeof(int), hipMemcpyHostToDevice);
  hipMemcpy(d_gtt, h_gtt, nsp*nntDev*sizeof(float), hipMemcpyHostToDevice);
  hipMemcpy(d_gbartt, h_gbartt, nsp*nntDev*sizeof(float), hipMemcpyHostToDevice);
  hipMemcpy(d_ct, h_ct, nntDev*sizeof(float), hipMemcpyHostToDevice);
  hipMemcpy(d_ctprev, h_ctprev, nntDev*sizeof(float), hipMemcpyHostToDevice);
  hipMemcpy(d_qt, h_qt, nntDev*sizeof(float), hipMemcpyHostToDevice);

  int threadsPerBlock = 256;
  int step = 4; //a power of two 
  int blocksPerGrid = (step*nnt + threadsPerBlock - 1) / threadsPerBlock;

  for (int i = 0; i < 350; i++) {
    hipLaunchKernelGGL(tissue, blocksPerGrid, threadsPerBlock, 0, 0, 
        d_tisspoints,d_gtt,d_gbartt,d_ct,d_ctprev,d_qt,nnt,nntDev,step,1);

    hipLaunchKernelGGL(tissue, blocksPerGrid, threadsPerBlock, 0, 0, 
        d_tisspoints,d_gtt,d_gbartt,d_ct,d_ctprev,d_qt,nnt,nntDev,step,2);
  }

  hipMemcpy(h_ct, d_ct, nntDev*sizeof(float), hipMemcpyDeviceToHost);

  // verify
  for (int i = 0; i < 350; i++) {
    reference(h_tisspoints,h_gtt,h_gbartt,h_ct_gold,h_ctprev,h_qt,nnt,nntDev,step,1);
    reference(h_tisspoints,h_gtt,h_gbartt,h_ct_gold,h_ctprev,h_qt,nnt,nntDev,step,2);
  }

  bool ok = true;
  for (int i = 0; i < nntDev; i++) {
    if (fabsf(h_ct[i] - h_ct_gold[i]) > 1e-3) {
      printf("@%d: %f %f\n", i, h_ct[i], h_ct_gold[i]);
      ok = false;
      break;
    }
  }

  free(h_tisspoints);
  free(h_gtt);
  free(h_gbartt);
  free(h_ct);
  free(h_ct_gold);
  free(h_ctprev);
  free(h_qt);
  hipFree(d_tisspoints);
  hipFree(d_gtt);
  hipFree(d_gbartt);
  hipFree(d_ct);
  hipFree(d_ctprev);
  hipFree(d_qt);

  printf("%s\n", ok ? "PASS" : "FAIL");
  return 0;
}
