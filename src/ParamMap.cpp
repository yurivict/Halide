#include "ParamMap.h"

#include "Buffer.h"
#include "Parameter.h"
#include "ImageParam.h"

namespace Halide {

namespace Internal {

namespace {
    struct ParamArg {
        Internal::Parameter mapped_param;
        Buffer<void> *buf_out_param = nullptr;

        ParamArg() = default;
        explicit ParamArg(const ParamMapping &pm)
            : mapped_param(pm.parameter->type(), false, 0, pm.parameter->name()),
              buf_out_param(nullptr) {
            mapped_param.set_scalar(pm.parameter->type(), pm.value);
        }
    };
}

struct ParamMapContents {
    std::map<const Internal::Parameter, ParamArg> mapping;
};

}  // namespace Internal

ParamMap::ParamMap() : contents(new ParamMapContents) {
}

ParamMap::ParamMap(const std::initializer_list<ParamMapping> &init) : contents(new ParamMapContents) {
    for (const auto &pm : init) {
        if (pm.parameter != nullptr) {
            contents->mapping[*pm.parameter] = ParamArg(pm);
        } else if (pm.buf_out_param == nullptr) {
            // TODO: there has to be a way to do this without the const_cast.
            set(*pm.image_param, *const_cast<Buffer<> *>(&pm.buf), nullptr);
        } else {
            Buffer<> temp_undefined;
            set(*pm.image_param, temp_undefined, pm.buf_out_param);
        }
    }
}

void ParamMap::set(const ImageParam &p, Buffer<> &buf, Buffer<> *buf_out_param) {
    Internal::Parameter v(p.type(), true, p.dimensions(), p.name());
    v.set_buffer(buf);
    ParamArg pa;
    pa.mapped_param = v;
    pa.buf_out_param = buf_out_param;
    contents->mapping[p.parameter()] = pa;
};

void ParamMap::set(const Internal::Parameter &p_orig, const Internal::Parameter &p_mapped) {
    ParamArg pa;
    pa.mapped_param = p_mapped;
    pa.buf_out_param = nullptr;
    contents->mapping[p_orig] = pa;
};

size_t ParamMap::size() const {
    return contents->mapping.size();
}

const Internal::Parameter &ParamMap::map(const Internal::Parameter &p, Buffer<> *&buf_out_param) const {
    auto iter = contents->mapping.find(p);
    if (iter != contents->mapping.end()) {
        buf_out_param = iter->second.buf_out_param;
        return iter->second.mapped_param;
    } else {
        buf_out_param = nullptr;
        return p;
    }
}

Internal::Parameter &ParamMap::map(Internal::Parameter &p, Buffer<> *&buf_out_param) const {
    auto iter = contents->mapping.find(p);
    if (iter != contents->mapping.end()) {
        buf_out_param = iter->second.buf_out_param;
        return iter->second.mapped_param;
    } else {
        buf_out_param = nullptr;
        return p;
    }
}

const ParamMap &ParamMap::empty_map() {
    static ParamMap empty_param_map;
    return empty_param_map;
}

}  // namespace Halide
