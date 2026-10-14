#import "LaMaRuntime.h"
#import <onnxruntime/onnxruntime_c_api.h>
#import <os/proc.h>
#include <memory>
#include <stdexcept>
#include <string>

namespace {
struct Context {
    const OrtApi *api=OrtGetApiBase()->GetApi(ORT_API_VERSION);
    OrtEnv *env=nullptr;OrtSession *session=nullptr;OrtMemoryInfo *memory=nullptr;
    ~Context(){if(session)api->ReleaseSession(session);if(memory)api->ReleaseMemoryInfo(memory);if(env)api->ReleaseEnv(env);}
    void check(OrtStatus *status){if(status){std::string message=api->GetErrorMessage(status);api->ReleaseStatus(status);throw std::runtime_error(message);}}
};
}
uint64_t CookiesLaMaAvailableMemory(void){return os_proc_available_memory();}
NSDictionary<NSString *,id> *CookiesLaMaOpen(NSString *path){
    try{
        auto context=std::make_unique<Context>();auto api=context->api;
        context->check(api->CreateEnv(ORT_LOGGING_LEVEL_ERROR,"CookiesLaMa",&context->env));
        OrtSessionOptions *options=nullptr;context->check(api->CreateSessionOptions(&options));
        struct OptionsGuard{const OrtApi *api;OrtSessionOptions *value;~OptionsGuard(){api->ReleaseSessionOptions(value);}} guard{api,options};
        context->check(api->SetIntraOpNumThreads(options,2));context->check(api->SetInterOpNumThreads(options,1));
        context->check(api->SetSessionExecutionMode(options,ORT_SEQUENTIAL));
        context->check(api->SetSessionGraphOptimizationLevel(options,ORT_ENABLE_ALL));
        // Match the measured low-memory CPU path. No Core ML/NPU provider is
        // appended: unsupported ML Program operations cannot enter this path.
        context->check(api->DisableCpuMemArena(options));context->check(api->DisableMemPattern(options));
        context->check(api->CreateSession(context->env,path.fileSystemRepresentation,options,&context->session));
        context->check(api->CreateCpuMemoryInfo(OrtArenaAllocator,OrtMemTypeDefault,&context->memory));
        return @{@"context":[NSValue valueWithPointer:context.release()]};
    }catch(const std::exception &error){return @{@"error":[NSString stringWithUTF8String:error.what()] ?: @"ONNX session failure"};}
}
NSDictionary<NSString *,id> *CookiesLaMaPredict(void *pointer,NSData *image,NSData *mask){
    auto context=static_cast<Context *>(pointer);if(!context)return @{@"error":@"Missing ONNX session"};
    constexpr size_t plane=512*512;
    if(image.length!=plane*3*sizeof(float)||mask.length!=plane*sizeof(float))return @{@"error":@"Invalid ONNX input dimensions"};
    OrtValue *values[3]={nullptr,nullptr,nullptr};auto api=context->api;
    struct ValuesGuard{const OrtApi *api;OrtValue **values;~ValuesGuard(){for(int i=0;i<3;i++)if(values[i])api->ReleaseValue(values[i]);}} guard{api,values};
    try{
        const int64_t colorShape[]={1,3,512,512},maskShape[]={1,1,512,512};
        NSMutableData *output=[NSMutableData dataWithLength:plane*3*sizeof(float)];
        context->check(api->CreateTensorWithDataAsOrtValue(context->memory,const_cast<void *>(image.bytes),image.length,colorShape,4,ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,&values[0]));
        context->check(api->CreateTensorWithDataAsOrtValue(context->memory,const_cast<void *>(mask.bytes),mask.length,maskShape,4,ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,&values[1]));
        context->check(api->CreateTensorWithDataAsOrtValue(context->memory,output.mutableBytes,output.length,colorShape,4,ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,&values[2]));
        const char *inputs[]={"image","mask"},*outputs[]={"output"};
        const OrtValue *inputValues[]={values[0],values[1]};
        context->check(api->Run(context->session,nullptr,inputs,inputValues,2,outputs,1,&values[2]));
        return @{@"output":output};
    }catch(const std::exception &error){return @{@"error":[NSString stringWithUTF8String:error.what()] ?: @"ONNX inference failure"};}
}
void CookiesLaMaClose(void *context){delete static_cast<Context *>(context);}
