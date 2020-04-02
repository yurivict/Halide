#ifndef HALIDE_PARAM_MAP_H
#define HALIDE_PARAM_MAP_H

/** \file
 * Defines a collection of parameters to be passed as formal arguments
 * to a JIT invocation.
 */
#include <map>
#include <memory>

// #include "Buffer.h"
// #include "Parameter.h"
#include "runtime/HalideRuntime.h"

namespace Halide {

namespace Internal {
    class Parameter;
}

template<typename T> class Buffer;
template<typename T> class Param;
class ImageParam;

namespace Internal {
struct ParamMapContents;
}

class ParamMap {
public:
    struct ParamMapping {
        const Internal::Parameter *parameter = nullptr;
        const ImageParam *image_param = nullptr;
        halide_scalar_value_t value;
        Buffer<void> &buf;
        Buffer<void> *buf_out_param = nullptr;

        template<typename T>
        ParamMapping(const Param<T> &p, const T &val)
            : parameter(&p.parameter()) {
            *((T *)&value) = val;
        }

        template<typename T>
        ParamMapping(const ImageParam &p, Buffer<T> &buf)
            : image_param(&p), buf(buf), buf_out_param(nullptr) {
        }

        template<typename T>
        ParamMapping(const ImageParam &p, Buffer<T> *buf_ptr)
            : image_param(&p), buf_out_param((Buffer<void> *)buf_ptr) {
        }
    };

private:
    std::unique_ptr<Internal::ParamMapContents> contents;

    void set(const ImageParam &p, Buffer<void> &buf, Buffer<void> *buf_out_param);
    void set(const Internal::Parameter &p_orig, const Internal::Parameter &p_mapped);

public:
    ParamMap();
    ParamMap(const std::initializer_list<ParamMapping> &init);

    template<typename T>
    void set(const Param<T> &p, T val) {
        Internal::Parameter v(p.type(), false, 0, p.name());
        v.set_scalar<T>(val);
        set(p.parameter(), v);
    };

    void set(const ImageParam &p, Buffer<void> &buf) {
        set(p, buf, nullptr);
    }

    template<typename T>
    void set(const ImageParam &p, Buffer<T> &buf) {
        Buffer<void> temp = buf;
        set(p, temp, nullptr);
    }

    size_t size() const;

    /** If there is an entry in the ParamMap for this Parameter, return it.
     * Otherwise return the parameter itself. */
    // @{
    const Internal::Parameter &map(const Internal::Parameter &p, Buffer<void> *&buf_out_param) const;

    Internal::Parameter &map(Internal::Parameter &p, Buffer<void> *&buf_out_param) const;
    // @}

    /** A const ref to an empty ParamMap. Useful for default function
     * arguments, which would otherwise require a copy constructor
     * (with llvm in c++98 mode) */
    static const ParamMap &empty_map();
};

}  // namespace Halide

#endif
