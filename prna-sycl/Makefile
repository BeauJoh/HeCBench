include ../makefile_sycl_include.mk
#===============================================================================
# Program name & source code list
#===============================================================================

program = main

c_source = main.c base.c param.c util.c
sycl_source = prna.cpp 

obj = $(c_source:.c=.o) $(sycl_source:.cpp=.o) 

#===============================================================================
# Targets to Build
#===============================================================================

$(program): $(obj)
	$(CC) $(CFLAGS) $(obj) -o $@ $(LDFLAGS)

%.o: %.cpp
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

base.o : base.c base.h util.h
main.o : main.c prna.h util.h base.h
param.o : param.c param.h util.h real.h
prna.o : prna.cpp base.h prna.h util.h param.h real.h cu.h
util.o : util.c util.h


clean:
	rm -rf $(program) $(obj)

test: $(program)
	./$(program) ../prna-cuda/test.seq

run: $(program)
	./$(program) ../prna-cuda/HIV1-NL43.seq
