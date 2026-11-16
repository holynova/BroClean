#ifndef BROWSER_SCOPE_PROCESS_H
#define BROWSER_SCOPE_PROCESS_H
#include <stdint.h>
#include <stddef.h>
typedef struct {
    int32_t pid;
    int32_t ppid;
    uint32_t uid;
    uint64_t start_microseconds;
    uint64_t resident_bytes;
    int memory_available;
    char path[4096];
    char name[64];
} BSProcess;
int bs_list_pids(int32_t *buffer, int capacity);
int bs_read_process(int32_t pid, BSProcess *output);
// Returns malloc'd argv-only NUL-separated bytes (never environment); caller frees.
char *bs_copy_arguments(int32_t pid, size_t *length, char *origin, size_t origin_capacity);
int bs_owns_listening_port(int32_t pid, uint16_t port);
void bs_wipe(void *buffer, size_t length);
#endif
