# ============================================================
# VERIFY.R
# Standalone verification script for the streamStats package.
# Run this after installing via remotes::install_github() to
# confirm the package works correctly end-to-end.
# ============================================================

cat("Loading streamStats...\n")
library(streamStats)
cat("Loaded successfully.\n\n")

set.seed(2024)
all_passed <- TRUE

check <- function(label, condition) {
  status <- if (isTRUE(condition)) "PASS" else "FAIL"
  if (!isTRUE(condition)) all_passed <<- FALSE
  cat(sprintf("[%s] %s\n", status, label))
}

# --- 1. Object creation and class check ---
acc <- new_stream_accumulator(reservoir_size = 50)
check("Object is of class Rcpp_StreamAccumulator", is(acc, "Rcpp_StreamAccumulator"))

# --- 2. Empty-state edge case ---
check("Empty accumulator: n == 0", acc$getN() == 0)
check("Empty accumulator: mean is NA", is.na(acc$getMean()))

# --- 3. Correctness vs base R ---
x <- rnorm(2000, mean = 50, sd = 5)
acc$update_vec(x)

check("Mean matches base R (tol 1e-8)",
      isTRUE(all.equal(acc$getMean(), mean(x), tolerance = 1e-8)))
check("Variance matches base R (tol 1e-8)",
      isTRUE(all.equal(acc$getVariance(), var(x), tolerance = 1e-8)))
check("Min/Max match base R",
      acc$getMin() == min(x) && acc$getMax() == max(x))

# --- 4. Batch vs incremental invariant ---
acc_loop <- new_stream_accumulator(reservoir_size = 50)
for (v in x) acc_loop$update(v)

check("Batch update_vec() matches one-at-a-time update() (mean)",
      isTRUE(all.equal(acc$getMean(), acc_loop$getMean(), tolerance = 1e-10)))
check("Batch update_vec() matches one-at-a-time update() (variance)",
      isTRUE(all.equal(acc$getVariance(), acc_loop$getVariance(), tolerance = 1e-10)))

# --- 5. Numerical stability (Welford vs naive formula) ---
x_shift <- rnorm(2000, mean = 1e8, sd = 1)
acc_shift <- new_stream_accumulator()
acc_shift$update_vec(x_shift)

naive_var <- (sum(x_shift^2) - length(x_shift) * mean(x_shift)^2) / (length(x_shift) - 1)

check("Welford variance stays accurate under large mean offset",
      isTRUE(all.equal(acc_shift$getVariance(), var(x_shift), tolerance = 1e-3)))
check("Naive formula demonstrably degrades (sanity check on the comparison itself)",
      abs(naive_var - var(x_shift)) > abs(acc_shift$getVariance() - var(x_shift)))

# --- 6. Reservoir sampling capacity ---
acc_res <- new_stream_accumulator(reservoir_size = 10)
acc_res$update_vec(1:500)
check("Reservoir sample never exceeds its fixed size",
      length(acc_res$getSample()) == 10)

# --- 7. reset() ---
acc_res$reset()
check("reset() restores empty state", acc_res$getN() == 0)

# --- Final summary ---
cat("\n============================================================\n")
if (all_passed) {
  cat("ALL CHECKS PASSED -- package installed and functioning correctly.\n")
} else {
  cat("ONE OR MORE CHECKS FAILED -- see output above.\n")
}
cat("============================================================\n")
