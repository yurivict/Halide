#include "Param.h"

#include "IR.h"

namespace Halide {
namespace Internal {

ParamBase::ParamBase(const Parameter &p)
    : param(p) {
}

ParamBase::ParamBase(Type t, bool is_buffer, int dimensions, const std::string &name)
    : param(t, is_buffer, dimensions, name) {
}

void ParamBase::check_name() const {
    user_assert(param.name() != "__user_context")
        << "Param<void*>(\"__user_context\") "
        << "is no longer used to control whether Halide functions take explicit "
        << "user_context arguments. Use set_custom_user_context() when jitting, "
        << "or add Target::UserContext to the Target feature set when compiling ahead of time.";
}

const std::string &ParamBase::name() const {
    return param.name();
}

ParamBase::operator Expr() const {
    return Variable::make(param.type(), name(), param);
}

ParamBase::operator ExternFuncArgument() const {
    return Expr(*this);
}

ParamBase::operator Argument() const {
    return Argument(name(), Argument::InputScalar, type(), 0,
                    param.get_argument_estimates());
}

const Parameter &ParamBase::parameter() const {
    return param;
}

Parameter &ParamBase::parameter() {
    return param;
}

/** Get the halide type of the Param */
Type ParamBase::type() const {
    return param.type();
}

void ParamBase::set_range(const Expr &min, const Expr &max) {
    set_min_value(min);
    set_max_value(max);
}

void ParamBase::set_min_value(Expr min) {
    if (min.defined() && min.type() != param.type()) {
        min = Cast::make(param.type(), min);
    }
    param.set_min_value(min);
}

void ParamBase::set_max_value(Expr max) {
    if (max.defined() && max.type() != param.type()) {
        max = Cast::make(param.type(), max);
    }
    param.set_max_value(max);
}

Expr ParamBase::min_value() const {
    return param.min_value();
}

Expr ParamBase::max_value() const {
    return param.max_value();
}

}  // namespace Internal

Expr user_context_value() {
    return Internal::Variable::make(Handle(), "__user_context",
                                    Internal::Parameter(Handle(), false, 0, "__user_context"));
}

}  // namespace Halide
