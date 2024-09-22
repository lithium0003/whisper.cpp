#if !__has_feature(objc_arc)
#error This file must be compiled with automatic reference counting enabled (-fobjc-arc)
#endif

#import "whisper-encoder.h"
#import "whisper-encoder-impl.h"

#import <CoreML/CoreML.h>

#include <stdlib.h>

#if defined(__x86_64__)
#include <immintrin.h>
#include <f16cintrin.h>
#elif defined(__aarch64__)
#include <arm_neon.h>
#endif

#if __cplusplus
extern "C" {
#endif

struct whisper_coreml_context {
    const void * data;
};

struct whisper_coreml_context * whisper_coreml_init(const char * path_model) {
    NSString * path_model_str = [[NSString alloc] initWithUTF8String:path_model];

    NSURL * url_model = [NSURL fileURLWithPath: path_model_str];

    // select which device to run the Core ML model on
    MLModelConfiguration *config = [[MLModelConfiguration alloc] init];
    // config.computeUnits = MLComputeUnitsCPUAndGPU;
    //config.computeUnits = MLComputeUnitsCPUAndNeuralEngine;
    config.computeUnits = MLComputeUnitsAll;

    const void * data = CFBridgingRetain([[whisper_encoder_impl alloc] initWithContentsOfURL:url_model configuration:config error:nil]);

    if (data == NULL) {
        return NULL;
    }

    whisper_coreml_context * ctx = new whisper_coreml_context;

    ctx->data = data;

    return ctx;
}

void whisper_coreml_free(struct whisper_coreml_context * ctx) {
    CFRelease(ctx->data);
    delete ctx;
}

void whisper_coreml_encode(
        const whisper_coreml_context * ctx,
                             int64_t   n_ctx,
                             int64_t   n_mel,
                               float * mel,
                               float * out) {
    MLMultiArray * inMultiArray = [
        [MLMultiArray alloc] initWithShape: @[@1, @(n_mel), @(n_ctx)]
                                  dataType: MLMultiArrayDataTypeFloat16
                                     error: nil
    ];

#if defined(__x86_64__)
    for(int i = 0; i < inMultiArray.count; i+=4) {
        __m128 input = _mm_load_ps(mel + i);
        __m128i output = _mm_cvtps_ph(input, 0);
        __m128i *dst16 = (__m128i *)((uint16_t *)inMultiArray.dataPointer + i);
        _mm_storel_epi64(dst16, output);
    }
#elif defined(__aarch64__)
    for(int i = 0; i < inMultiArray.count; i++) {
        ((float16_t *)inMultiArray.dataPointer)[i] = mel[i];
    }
#endif
    @autoreleasepool {
        whisper_encoder_implOutput * outCoreML = [(__bridge id) ctx->data predictionFromLogmel_data:inMultiArray error:nil];

#if defined(__x86_64__)
        for(int i = 0; i < outCoreML.output.count; i+=4) {
            const __m128i *src16 = (const __m128i *)((uint16_t *)outCoreML.output.dataPointer + i);
            __m128i input = _mm_loadl_epi64(src16);
            __m128 output = _mm_cvtph_ps(input);
            _mm_storeu_ps(out + i, output);
        }
#elif defined(__aarch64__)
        for(int i = 0; i < outCoreML.output.count; i++) {
            out[i] = ((float16_t *)outCoreML.output.dataPointer)[i];
        }
#endif
    }
}

#if __cplusplus
}
#endif
