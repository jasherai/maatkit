// Yes, the only purpose of this program is segfault.
// See issue 135.
#include <stdio.h>
int main() {
   fprintf(stderr, "Going to segfault...\n");
   char *s = "thanks wikipedia";
   *s = 'a';
}
