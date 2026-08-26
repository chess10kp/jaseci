# Product-path facade for the _statistics accelerator module.
# Semantics mirror CPython 3.14 ``Modules/_statisticsmodule.c`` byte-for-byte
# at the algorithm level: the module's entire surface is one function,
# ``_normal_dist_inv_cdf(p, mu, sigma)``, the Wichura (1988) Algorithm AS241
# rational approximation of the standard normal inverse CDF. Every branch,
# guard, and coefficient below is a direct lift of
# ``_statistics__normal_dist_inv_cdf_impl``; the double-precision arithmetic
# runs on jac floats so results are bit-identical to the C build.
#
# Error-channel convention matches the other facades (binasciimodule et al):
# the C ``goto error`` ladder becomes a returned ValueError with the exact
# string "inv_cdf undefined for these parameters", and the clinic ``double``
# argument coercion rejects non-reals with the canonical TypeError.

import math as host_math;

import from objects {
    PyObj,
    PyFloat,
    PyInt,
    PyBool,
    PyStr,
    PyModule,
    py_error,
    is_error,
}

def _p2_inv_cdf_domain_error -> PyObj {
    return py_error("ValueError", "inv_cdf undefined for these parameters");
}

# clinic ``double`` converter: int/bool promote exactly like PyFloat_AsDouble;
# everything else fails with CPython's real-number TypeError.
def _p2_as_double(v: PyObj) -> PyObj {
    if isinstance(v, PyFloat) {
        return v;
    }
    if isinstance(v, PyBool) {
        return PyFloat(t="float", val=1.0 if (v as PyBool).val else 0.0);
    }
    if isinstance(v, PyInt) {
        return PyFloat(t="float", val=float((v as PyInt).val));
    }
    return py_error("TypeError", "must be real number, not " + v.tp_type_name());
}

# Wichura, M.J. (1988). "Algorithm AS241: The Percentage Points of the Normal
# Distribution". Applied Statistics 37(3): 477-484.
def _p2_normal_dist_inv_cdf(p: float, mu: float, sigma: float) -> PyObj {
    if p <= 0.0 or p >= 1.0 {
        return _p2_inv_cdf_domain_error();
    }

    q: float = p - 0.5;
    if q <= 0.425 and q >= -0.425 {
        r: float = 0.180625 - q * q;
        # Hash sum-55.8831928806149014439
        num: float = (((((((2.5090809287301226727e+3 * r +
                     3.3430575583588128105e+4) * r +
                     6.7265770927008700853e+4) * r +
                     4.5921953931549871457e+4) * r +
                     1.3731693765509461125e+4) * r +
                     1.9715909503065514427e+3) * r +
                     1.3314166789178437745e+2) * r +
                     3.3871328727963666080e+0) * q;
        den: float = (((((((5.2264952788528545610e+3 * r +
                     2.8729085735721942674e+4) * r +
                     3.9307895800092710610e+4) * r +
                     2.1213794301586595867e+4) * r +
                     5.3941960214247511077e+3) * r +
                     6.8718700749205790830e+2) * r +
                     4.2313330701600911252e+1) * r +
                     1.0);
        if den == 0.0 {
            return _p2_inv_cdf_domain_error();
        }
        return PyFloat(t="float", val=mu + ((num / den) * sigma));
    }

    r2: float = p if q <= 0.0 else 1.0 - p;
    if r2 <= 0.0 or r2 >= 1.0 {
        return _p2_inv_cdf_domain_error();
    }
    rr: float = host_math.sqrt(-host_math.log(r2));
    if rr <= 5.0 {
        rr = rr - 1.6;
        # Hash sum-49.33206503301610289036
        num2: float = (((((((7.74545014278341407640e-4 * rr +
                     2.27238449892691845833e-2) * rr +
                     2.41780725177450611770e-1) * rr +
                     1.27045825245236838258e+0) * rr +
                     3.64784832476320460504e+0) * rr +
                     5.76949722146069140550e+0) * rr +
                     4.63033784615654529590e+0) * rr +
                     1.42343711074968357734e+0);
        den2: float = (((((((1.05075007164441684324e-9 * rr +
                     5.47593808499534494600e-4) * rr +
                     1.51986665636164571966e-2) * rr +
                     1.48103976427480074590e-1) * rr +
                     6.89767334985100004550e-1) * rr +
                     1.67638483018380384940e+0) * rr +
                     2.05319162663775882187e+0) * rr +
                     1.0);
    } else {
        rr = rr - 5.0;
        # Hash sum-47.52583317549289671629
        num2 = (((((((2.01033439929228813265e-7 * rr +
                     2.71155556874348757815e-5) * rr +
                     1.24266094738807843860e-3) * rr +
                     2.65321895265761230930e-2) * rr +
                     2.96560571828504891230e-1) * rr +
                     1.78482653991729133580e+0) * rr +
                     5.46378491116411436990e+0) * rr +
                     6.65790464350110377720e+0);
        den2 = (((((((2.04426310338993978564e-15 * rr +
                     1.42151175831644588870e-7) * rr +
                     1.84631831751005468180e-5) * rr +
                     7.86869131145613259100e-4) * rr +
                     1.48753612908506148525e-2) * rr +
                     1.36929880922735805310e-1) * rr +
                     5.99832206555887937690e-1) * rr +
                     1.0);
    }
    if den2 == 0.0 {
        return _p2_inv_cdf_domain_error();
    }
    x: float = num2 / den2;
    if q < 0.0 {
        x = -x;
    }
    return PyFloat(t="float", val=mu + (x * sigma));
}

# METH_FASTCALL positional-only binding (clinic ``/``): exactly three
# arguments, no keywords.
obj PyStatisticsInvCdfFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error(
                "TypeError", "_normal_dist_inv_cdf() takes no keyword arguments"
            );
        }
        if len(args) != 3 {
            return py_error(
                "TypeError",
                "_normal_dist_inv_cdf() takes exactly 3 arguments ("
                    + str(len(args)) + " given)"
            );
        }
        p = _p2_as_double(args[0]);
        if is_error(p) {
            return p;
        }
        mu = _p2_as_double(args[1]);
        if is_error(mu) {
            return mu;
        }
        sigma = _p2_as_double(args[2]);
        if is_error(sigma) {
            return sigma;
        }
        return _p2_normal_dist_inv_cdf(
            (p as PyFloat).val, (mu as PyFloat).val, (sigma as PyFloat).val
        );
    }
}

# Module surface (statistics_methods[] + PyInit__statistics docstring).
def build_statistics_module -> PyObj {
    attrs: dict[str, PyObj] = {
        "_normal_dist_inv_cdf": PyStatisticsInvCdfFn(t="function"),
        "__doc__": PyStr(t="str", val="Accelerators for the statistics module.\n"),
    };
    return PyModule(t="module", name="_statistics", attrs=attrs);
}
