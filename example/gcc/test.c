
#include <stdio.h>

void test_fun(int count, char** strings)
{
	int i;
	for (i = 0; i < count; i++)
		printf("[%d]: %s\n", i, strings[i]);
}
