// AUTOGENERATED FILE - DO NOT MODIFY!
// This file generated by Djinni from auto_config.djinni

#pragma once

#include <cstdint>

namespace zego {

class InitSdkCompletionCallback {
public:
    virtual ~InitSdkCompletionCallback() {}

    virtual void on_init_sdk(int32_t error_code) = 0;
};

}  // namespace zego