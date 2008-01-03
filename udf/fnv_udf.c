/* To compile:
 * gcc -fPIC -Wall -I/usr/include/mysql -shared -o fnv_udf.so fnv_udf.c
 */

#include <my_global.h>
#include <my_sys.h>
#include <mysql.h>
#include <ctype.h>

/* On the first call, use this as the initial_value. */
#define HASH_64_INIT 0x84222325cbf29ce4ULL
/* Default for NULLs, just so the result is never NULL. */
#define HASH_NULL_DEFAULT 0x0a0b0c0d
/* Magic number for the hashing. */
static const ulonglong FNV_64_PRIME = 0x100000001b3ULL;

/* Prototypes */

ulonglong hash64(const void *buf, size_t len, ulonglong hval);
my_bool fnv_64_init( UDF_INIT* initid, UDF_ARGS* args, char* message );
ulonglong fnv_64(UDF_INIT *initid, UDF_ARGS *args, char *is_null, char *error );

/* Implementations */

ulonglong hash64(const void *buf, size_t len, ulonglong hval)
{
   const unsigned char *bp = (const unsigned char*)buf;
   const unsigned char *be = bp + len;

   /* FNV-1 hash each octet of the buffer */
   for (; bp != be; ++bp) {
      /* multiply by the 64 bit FNV magic prime mod 2^64 */
      hval *= FNV_64_PRIME;
      /* xor the bottom with the current octet */
      hval ^= (ulonglong)*bp;
   }

   return hval;
}

/*
** FNV_64 function
*/
my_bool
fnv_64_init( UDF_INIT* initid, UDF_ARGS* args, char* message )
{
   initid->maybe_null = 0;      /* The result will never be NULL */
   return 0;
}


ulonglong
fnv_64(UDF_INIT *initid, UDF_ARGS *args, char *is_null, char *error )
{

   uint null_default = HASH_NULL_DEFAULT;
   ulonglong result  = HASH_64_INIT;
   uint i            = 0;

   for ( ; i < args->arg_count; ++i ) {

/*
      Item_result result_type = args->arg_type[i];
      if ( result_type == STRING_RESULT &&
            args[i]->field_type() == MYSQL_TYPE_TIMESTAMP)
      {
         because val_int() is faster.
         result_type = INT_RESULT;
      }
*/

      if ( !args->maybe_null[i] ) {
         result
            = hash64((const void*)args->args[i], args->lengths[i], result);
      }
      else {
         result
            = hash64((const void*)&null_default, sizeof(null_default), result);
      }
   }
   return result;
}
