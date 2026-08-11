#include "CWinFoundationCompat.h"

#if defined(_WIN32)
#include <windows.h>
#include <winhttp.h>

int32_t WFCoCreateGuid(WinFoundationGUID *guid) {
    return CoCreateGuid((GUID *)guid);
}

void *WFWinHttpOpenRequest(
    void *connection,
    const uint16_t *verb,
    const uint16_t *object_name,
    const uint16_t *version,
    const uint16_t *referrer,
    const uint16_t *const *accept_types,
    uint32_t flags
) {
    return WinHttpOpenRequest(
        (HINTERNET)connection,
        (LPCWSTR)verb,
        (LPCWSTR)object_name,
        (LPCWSTR)version,
        (LPCWSTR)referrer,
        (LPCWSTR *)accept_types,
        flags
    );
}

int32_t WFWinHttpSendRequest(
    void *request,
    const uint16_t *headers,
    uint32_t headers_length,
    void *optional_data,
    uint32_t optional_length,
    uint32_t total_length,
    uintptr_t context
) {
    return WinHttpSendRequest(
        (HINTERNET)request,
        (LPCWSTR)headers,
        headers_length,
        optional_data,
        optional_length,
        total_length,
        (DWORD_PTR)context
    );
}

int32_t WFWinHttpQueryHeaders(
    void *request,
    uint32_t info_level,
    const uint16_t *name,
    void *buffer,
    uint32_t *buffer_length,
    uint32_t *index
) {
    return WinHttpQueryHeaders(
        (HINTERNET)request,
        info_level,
        (LPCWSTR)name,
        buffer,
        (LPDWORD)buffer_length,
        (LPDWORD)index
    );
}
#endif
