#include <stdio.h>
#include <stdlib.h>

char *line;

char *dup_line(void) {
  char *p, *s, *t;

  if (line == NULL)
    return (0);
  s = line;
  while (*s != '\n')
    ++s;

  printf("s - line = %d\n", s - line);
  p = malloc(s - line + 1);

  s = line;
  t = p;
  while ((*t++ = *s++) != '\n')
    continue;

  // while ((*t = *s) != '\n') {
  //   t++;
  //   s++;
  // }
  // t++;
  // s++;
  // // continue;

  printf("p = '%s'\n", p);
  printf("s = '%s'\n", s);
  printf("t = '%s'\n", t);

  return (p);
}

int main() {
  line = "hello\nworld";
  // line = "hello world";
  // printf(dup_line());
  char *a = malloc(10);
  a[0] = '!';
  free(a);
  printf("%s", a);
  return 0;
}
