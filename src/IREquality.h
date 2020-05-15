#ifndef HALIDE_IR_EQUALITY_H
#define HALIDE_IR_EQUALITY_H

/** \file
 * Methods to test Exprs and Stmts for equality of value
 */

#include "Expr.h"

namespace Halide {
namespace Internal {

/** A compare struct suitable for use in std::map and std::set that
 * computes a lexical ordering on IR nodes. */
struct IRDeepCompare {
    bool operator()(const Expr &a, const Expr &b) const;
    bool operator()(const Stmt &a, const Stmt &b) const;
};

#define HALIDE_IR_COMPARE_CACHE_DEBUG 0

/** Lossily track known equal exprs with a cache. On collision, the
 * old pair is evicted. Used below by ExprWithCompareCache. */
class IRCompareCache {
private:
    struct Entry {
        Expr a, b;
    };

    const int bits = 0;

    uint32_t hash(const Expr &a, const Expr &b) const;

    std::vector<Entry> entries;

public:
#if HALIDE_IR_COMPARE_CACHE_DEBUG
    int insertions = 0;
    int collisions = 0;
    int verbose = 0;
#endif

    void insert(const Expr &a, const Expr &b) {
        uint32_t h = hash(a, b);
        Entry &e = entries[h];
#if HALIDE_IR_COMPARE_CACHE_DEBUG
        insertions++;
        if ((e.a.defined() && e.a.get() != a.get()) || (e.b.defined() && e.b.get() != b.get())) {
            if (verbose >= 2) {
              debug(0) << "  hash(" << (void*)a.get() << "," << (void*)b.get() << ") -> " << h << "\n";
              debug(0) << "  existing(" << (void*)e.a.get() << "," << (void*)e.b.get() << ") -> " << hash(e.a, e.b) << "\n";
            }
            collisions++;
        }
#endif
        e.a = a;
        e.b = b;
    }

    bool contains(const Expr &a, const Expr &b) const {
        uint32_t h = hash(a, b);
        const Entry &e = entries[h];
        return ((a.same_as(e.a) && b.same_as(e.b)) ||
                (a.same_as(e.b) && b.same_as(e.a)));
    }

    void clear() {
        for (size_t i = 0; i < entries.size(); i++) {
            entries[i].a = Expr();
            entries[i].b = Expr();
        }
    }

    IRCompareCache() = default;
    IRCompareCache(int b)
        : bits(b), entries(static_cast<size_t>(1) << bits) {
    }

#if HALIDE_IR_COMPARE_CACHE_DEBUG
    ~IRCompareCache() {
        if (insertions > 0) {
          if (verbose >= 1) {
            debug(0) << "IRCompareCache bits=" << bits
                     << " insertions=" << insertions
                     << " collisions=" << collisions
                     << " evict%=" << 100.0 * collisions / insertions
                     << "\n";
          }
        }
    }
#endif
};

/** A wrapper about Exprs so that they can be deeply compared with a
 * cache for known-equal subexpressions. Useful for unsanitized Exprs
 * coming in from the front-end, which may be horrible graphs with
 * sub-expressions that are equal by value but not by identity. This
 * isn't a comparison object like IRDeepCompare above, because libc++
 * requires that comparison objects be stateless (and constructs a new
 * one for each comparison!), so they can't have a cache associated
 * with them. However, by sneakily making the cache a mutable member
 * of the objects being compared, we can dodge this issue.
 *
 * Clunky example usage:
 *
\code
Expr a, b, c, query;
std::set<ExprWithCompareCache> s;
IRCompareCache cache(8);
s.insert(ExprWithCompareCache(a, &cache));
s.insert(ExprWithCompareCache(b, &cache));
s.insert(ExprWithCompareCache(c, &cache));
if (m.contains(ExprWithCompareCache(query, &cache))) {...}
\endcode
 *
 */
struct ExprWithCompareCache {
    Expr expr;
    mutable IRCompareCache *cache;

    ExprWithCompareCache()
        : cache(nullptr) {
    }
    ExprWithCompareCache(const Expr &e, IRCompareCache *c)
        : expr(e), cache(c) {
    }

    /** The comparison uses (and updates) the cache */
    bool operator<(const ExprWithCompareCache &other) const;
};

/** Compare IR nodes for equality of value. Traverses entire IR
 * tree. For equality of reference, use Expr::same_as. If you're
 * comparing non-CSE'd Exprs, use graph_equal, which is safe for nasty
 * graphs of IR nodes. */
// @{
bool equal(const Expr &a, const Expr &b);
bool equal(const Stmt &a, const Stmt &b);
bool graph_equal(const Expr &a, const Expr &b);
bool graph_equal(const Stmt &a, const Stmt &b);
// @}

void ir_equality_test();

}  // namespace Internal
}  // namespace Halide

#endif
