#include "uv.h"
#include <stdlib.h>

void *ka_barrier_malloc() {
    return malloc(sizeof(uv_barrier_t));
}

void ka_barrier_free(void *barrier) {
    free(barrier);
}

int ka_barrier_init(uv_barrier_t *barrier, unsigned int n) {
    return uv_barrier_init(barrier, n);
}

void ka_barrier_destroy(uv_barrier_t *barrier) {
    uv_barrier_destroy(barrier);
}

int ka_barrier_wait(uv_barrier_t* barrier) {
    return uv_barrier_wait(barrier);
}

typedef struct { 
    uv_async_t *handle;
    uv_barrier_t *barrier;
} payload_t;

void ka_callback(payload_t *data) {
    uv_async_send(data->handle);
    if (ka_barrier_wait(data->barrier) > 0) {
        ka_barrier_destroy(data->barrier);
        ka_barrier_free(data->barrier);
    }
}
