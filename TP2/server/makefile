all: servtcp clitcp

servtcp: servtcp.c 
	gcc -o servtcp servtcp.c 

clitcp: clitcp.c 
	gcc -o clitcp clitcp.c

.PHONY: clean

clean: 
	rm -f clitcp servtcp
