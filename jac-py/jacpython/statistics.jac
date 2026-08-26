# Product-path facade for the _statistics accelerator module.
# Semantics mirror CPython 3.14 ``Modules/_statisticsmodule.c`` byte-for-byte
# at the algorithm level: Wichura's Algorithm AS241 rational approximation of
# the inverse normal CDF, with the identical coefficient tables and identical
# ValueError("inv_cdf undefined for these parameters") domain discipline.
# The C module exports exactly one function; every branch below is a direct
# lift of ``_statistics__normal_dist_inv_cdf_impl``.

import math as host_math;

def _p2_normal_dist_inv_cdf(p: float, mu: float, sigma: float) -> float {
    # There is no closed-form solution to the inverse CDF for the normal
    # distribution, so we use a rational approximation instead:
    # Wichura, M.J. (1988). "Algorithm AS241: The Percentage Points of the
    # Normal Distribution".  Applied Statistics. 37 (3): 477-484.
    if p <= 0.0 or p >= 1.0 {
        raise ValueError("inv_cdf undefined for these parameters");
    }
    q = p - 0.5;
    if abs(q) <= 0.425 {
        r = 0.180625 - q * q;
        # Hash sum-55.8831928806149014439
        num = (((((((2.5090809287301226727e+3 * r +
                     3.3430575583588128105e+4) * r +
                     6.7265770927008700853e+4) * r +
                     4.5921953931549871457e+4) * r +
                     1.3731693765509461125e+4) * r +
                     1.9715909503065514427e+3) * r +
                     1.3314166789178437745e+2) * r +
                     3.3871328727963666080e+0) * q;
        den = (((((((5.2264952788528545610e+3 * r +
                     2.8729085735721942674e+4) * r +
                     3.9307895800092710610e+4) * r +
                     2.1213794301586595867e+4) * r +
                     5.3941960214247511077e+3) * r +
                     6.8718700749205790830e+2) * r +
                     4.2313330701600911252e+1) * r +
                     1.0);
        if den == 0.0 {
            raise ValueError("inv_cdf undefined for these parameters");
        }
        x = num / den;
        return mu + x * sigma;
    }
    r = p if q <= 0.0 else 1.0 - p;
    if r <= 0.0 or r >= 1.0 {
        raise ValueError("inv_cdf undefined for these parameters");
    }
    r = host_math.sqrt(-host_math.log(r));
    if r <= 5.0 {
        r = r - 1.6;
        # Hash sum-49.33206503301610289036
        num = (((((((7.74545014278341407640e-4 * r +
                     2.27238449892691845833e-2) * r +
                     2.41780725177450611770e-1) * r +
                     1.27045825245236838258e+0) * r +
                     3.64784832476320460504e+0) * r +
                     5.76949722146069140550e+0) * r +
                     4.63033784615654529590e+0) * r +
                     1.42343711074968357734e+0);
        den = (((((((1.05075007164441684324e-9 * r +
                     5.47593808499534494600e-4) * r +
                     1.51986665636164571966e-2) * r +
                     1.48103976427480074590e-1) * r +
                     6.89767334985100004550e-1) * r +
                     1.67638483018380384940e+0) * r +
                     2.05319162663775882187e+0) * r +
                     1.0);
    } else {
        r = r - 5.0;
        # Hash sum-47.52583317549289671629
        num = (((((((2.01033439929228813265e-7 * r +
                     2.71155556874348757815e-5) * r +
                     1.24266094738807843860e-3) * r +
                     2.65321895265761230930e-2) * r +
                     2.96560571828504891230e-1) * r +
                     1.78482653991729133580e+0) * r +
                     5.46378491116411436990e+0) * r +
                     6.65790464350110377720e+0);
        den = (((((((2.04426310338993978564e-15 * r +
                     1.42151175831644588870e-7) * r +
                     1.84631831751005468180e-5) * r +
                     7.86869131145613259100e-4) * r +
                     1.48753612908506148525e-2) * r +
                     1.36929880922735805310e-1) * r +
                     5.99832206555887937690e-1) * r +
                     1.0);
    }
    if den == 0.0 {
        raise ValueError("inv_cdf undefined for these parameters");
    }
    x = num / den;
    if q < 0.0 {
        x = -x;
    }
    return mu + x * sigma;
}
