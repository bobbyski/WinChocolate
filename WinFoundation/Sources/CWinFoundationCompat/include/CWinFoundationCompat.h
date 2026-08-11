#ifndef CWINFOUNDATIONCOMPAT_H
#define CWINFOUNDATIONCOMPAT_H

#include <stdint.h>

typedef uint8_t uuid_t[16];

typedef struct WinFoundationGUID {
    uint32_t data1;
    uint16_t data2;
    uint16_t data3;
    uint8_t data4[8];
} WinFoundationGUID;

#if defined(_WIN32)
int32_t WFCoCreateGuid(WinFoundationGUID *guid);

void *WFWinHttpOpenRequest(
    void *connection,
    const uint16_t *verb,
    const uint16_t *object_name,
    const uint16_t *version,
    const uint16_t *referrer,
    const uint16_t *const *accept_types,
    uint32_t flags
);

int32_t WFWinHttpSendRequest(
    void *request,
    const uint16_t *headers,
    uint32_t headers_length,
    void *optional_data,
    uint32_t optional_length,
    uint32_t total_length,
    uintptr_t context
);

int32_t WFWinHttpQueryHeaders(
    void *request,
    uint32_t info_level,
    const uint16_t *name,
    void *buffer,
    uint32_t *buffer_length,
    uint32_t *index
);
#endif

#endif
