#include <string>

#include <jni.h>

#include "llama.h"

static llama_model* g_model = nullptr;

// Export symbol properly
extern "C" __attribute__((visibility("default")))
const char* sutra_version() {
    return "1.0.0";
}

// Export symbol properly
extern "C" __attribute__((visibility("default")))
int sutra_load_model(const char* path) {

    llama_backend_init();

    llama_model_params model_params =
            llama_model_default_params();

    g_model =
            llama_model_load_from_file(
                    path,
                    model_params
            );

    return g_model != nullptr ? 1 : 0;
}