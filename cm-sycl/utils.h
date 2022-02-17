#ifndef UTILS_H
#define UTILS_H

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <iterator>
#include <vector>
#include <algorithm>
#include <random>
#include <ctime>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>

#ifdef __unix__
#include <dirent.h>
#include <unistd.h>
#define GetCurrentDir getcwd
#elif defined _WIN32
#include <windows.h>
#include <dirent.h>
#include <conio.h>
#include <direct.h>
#define GetCurrentDir _getcwd
#endif

#include "common.h"

// Some useful text replacements related to the analysis
// The total number of genes involved for this particular kind of dataset // TODO: Revise the wording
#define U133AArrayLength (22283) 

// Queries should be contained within this sub-directory
#define subDirQueries ("query/")

// Results should be output within this sub-directory
#define subDirResults ("Results/")

// Reference files should be contained within this sub-directory
#define subDirFiles ("reffiles-tab/")

#define separator ('_') // A separator used within file names

//-----------------------------------------------------------------------------------

// General global variables
const int threadsPerBlock = 128;
const bool promptForInput = true; // If false, just use the default input parameters & don't prompt

// Variables related to user input
const int minRandomGenerations = 100;
const int maxRandomGenerations = 1000000;
const int defaultRandomGenerations = 100000;
const int maxENFP = 5;
const int defaultENFP = 1;
const int defaultCompoundChoice = 1;

//-----------------------------------------------------------------------------------

// Prototypes of functions used

// User input functions
int requestNRandomGenerations();
int requestENFP();
int requestCompoundChoice();

// General file & directory functions
int changeToDirectory(const std::string &);
int getCurrentPath(char* buffer);
int changeToSubDirectory(const std::string &, const std::string &);
int getFilesInDirectory (const std::string &, std::vector<std::string> &, const std::string &);

// File reading / parsing functions
void parseQueryFile (const std::string &, std::vector<std::string> &, std::vector<int> & );
std::string parseDrugInfoFromFilename(const std::string &, const int &);
void populateRefGeneNameList(const std::string &, std::vector<std::string> &);
void populateRefRegulationValues(const std::string &, int*, const bool);

// Output function
void writeOutputFileHeader(std::ofstream &outdata, const std::string &sigFilename,
    const int &randomGenerations, const std::vector<std::string> &geneNameList,
    const std::vector<int> &regNum);

// Main processing function
int processQuery(sycl::queue &q,
    const std::vector<std::string> &refFiles, 
    const std::vector<std::string> &sigGeneNameList,
    const std::vector<int> &sigRegValue,
    const int nRandomGenerations,
    const int compoundChoice,
    const int ENFPvalue,
    std::ofstream &outputStream);

// Helper processing functions
int queryToIndex(
    int *qIndex, 
    const std::vector<std::string> &sigGeneNameList,
    const std::vector<int> &sigRegValue,
    const std::vector<std::string> &refGeneNameList);

inline int getNDrugs(const int compoundChoice);

double computePValue(
    sycl::queue &q,
    const int nRandomGenerations,
    const int threadsPerBlock,
    const double averageSetScore,
    const int setSize,
    const int signatureByRNGs,
    const double UCmax,
    buffer<float,1> &device_randomIndexArray,
    buffer<int,1> &device_refRegNum,
    buffer<float,1> &device_arraysAdded);

double computePValueHelper(const double nAboveThreshold, const int nRandomGenerations);

inline double computeUCMax(const int sigNGenes, const int nGenesTotal);

double computeDotProduct(
    sycl::queue &q,
    buffer<int,1> &device_v1,
    buffer<int,1> &device_v2,
    const int vLength,
    const int blockSize,
    const int nThreads);

#endif
