#include "CProcess.h"
#include <libproc.h>
#include <sys/sysctl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int bs_list_pids(int32_t *buffer, int capacity) {
    return proc_listallpids(buffer, capacity * (int)sizeof(int32_t));
}

int bs_read_process(int32_t pid, BSProcess *output) {
    struct proc_bsdinfo bsd = {0};
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, sizeof(bsd)) != sizeof(bsd)) return 0;
    memset(output, 0, sizeof(*output));
    output->pid = pid; output->ppid = bsd.pbi_ppid; output->uid = bsd.pbi_uid;
    output->start_microseconds = bsd.pbi_start_tvsec * 1000000ULL + bsd.pbi_start_tvusec;
    strlcpy(output->name, bsd.pbi_name[0] ? bsd.pbi_name : bsd.pbi_comm, sizeof(output->name));
    proc_pidpath(pid, output->path, sizeof(output->path));
    struct proc_taskinfo task = {0};
    if (proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &task, sizeof(task)) == sizeof(task)) {
        output->memory_available = 1;
        output->resident_bytes = task.pti_resident_size;
    }
    return 1;
}

char *bs_copy_arguments(int32_t pid, size_t *length, char *origin, size_t origin_capacity) {
    *length = 0;
    int argmax = 0; size_t max_size = sizeof(argmax);
    int max_mib[] = {CTL_KERN, KERN_ARGMAX};
    if (sysctl(max_mib, 2, &argmax, &max_size, NULL, 0) || argmax <= 0 || argmax > 8*1024*1024) return NULL;
    char *buffer = calloc(1, argmax);
    if (!buffer) return NULL;
    size_t size = argmax;
    int mib[] = {CTL_KERN, KERN_PROCARGS2, pid};
    if (sysctl(mib, 3, buffer, &size, NULL, 0) || size < sizeof(int)) { free(buffer); return NULL; }
    int argc; memcpy(&argc, buffer, sizeof(argc));
    if (argc <= 0 || argc > 65536) { free(buffer); return NULL; }
    char *end = buffer + size, *p = buffer + sizeof(int);
    char *nul = memchr(p, 0, end - p);
    if (!nul) { free(buffer); return NULL; }
    if (origin && origin_capacity) strlcpy(origin, p, origin_capacity);
    p = nul + 1;
    while (p < end && *p == 0) ++p;
    char *start = p;
    for (int i = 0; i < argc; ++i) {
        if (p >= end || !(nul = memchr(p, 0, end - p))) { free(buffer); return NULL; }
        p = nul + 1;
    }
    size_t count = p - start;
    char *args = malloc(count);
    if (args) { memcpy(args, start, count); *length = count; }
    // Wipe the buffer, which may contain environment variables.
    bs_wipe(buffer, size);
    free(buffer);
    return args;
}

int bs_owns_listening_port(int32_t pid, uint16_t port) {
    int size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, NULL, 0);
    if (size <= 0 || size > 16*1024*1024) return 0;
    size += 32 * sizeof(struct proc_fdinfo);
    struct proc_fdinfo *fds = malloc(size);
    if (!fds) return 0;
    int bytes = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, fds, size);
    int result = 0;
    for (int i = 0; i < bytes / (int)sizeof(*fds); ++i) {
        if (fds[i].proc_fdtype != PROX_FDTYPE_SOCKET) continue;
        struct socket_fdinfo socket = {0};
        if (proc_pidfdinfo(pid, fds[i].proc_fd, PROC_PIDFDSOCKETINFO, &socket, sizeof(socket)) != sizeof(socket)) continue;
        if (socket.psi.soi_kind != SOCKINFO_TCP) continue;
        struct tcp_sockinfo tcp = socket.psi.soi_proto.pri_tcp;
        if (tcp.tcpsi_state == TSI_S_LISTEN && ntohs((uint16_t)tcp.tcpsi_ini.insi_lport) == port) { result = 1; break; }
    }
    free(fds);
    return result;
}

void bs_wipe(void *buffer, size_t length) {
    volatile unsigned char *p = buffer;
    while (length--) *p++ = 0;
}
