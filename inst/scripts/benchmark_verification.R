# ============================================================
# Benchmark Verification Script for StreamAccumulator
#
# Purpose: Compare the Rcpp/Welford-based StreamAccumulator
# against base R equivalents (mean, var, sd, min, max) to
# confirm correctness, and to compare performance against
# a naive R implementation of the same online algorithm.
#
# This script is NOT a formal test suite (see tests/testthat/
# for that) -- it is meant to be run interactively as a
# sanity-check / evidence report.
# ============================================================

library(streamStats)

set.seed(42)

# ------------------------------------------------------------
# 1. Correctness check: full-batch ingestion vs base R
# ------------------------------------------------------------
cat("=== Correctness: batch ingestion vs base R ===\n")

x <- rnorm(10000, mean = 5, sd = 2)

acc <- new_stream_accumulator(reservoir_size = 200)
acc$update_vec(x)

r_mean <- mean(x)
r_var  <- var(x)
r_sd   <- sd(x)
r_min  <- min(x)
r_max  <- max(x)

results <- data.frame(
  statistic = c("mean", "variance", "sd", "min", "max"),
  base_R    = c(r_mean, r_var, r_sd, r_min, r_max),
  streamStats = c(acc$getMean(), acc$getVariance(), acc$getSD(),
                  acc$getMin(), acc$getMax())
)
results$abs_diff <- abs(results$base_R - results$streamStats)
print(results)

stopifnot(all(results$abs_diff < 1e-8))
cat("PASS: all statistics match base R within 1e-8\n\n")

# ------------------------------------------------------------
# 2. Correctness check: one-at-a-time ingestion == batch ingestion
# ------------------------------------------------------------
cat("=== Correctness: one-at-a-time vs batch ingestion ===\n")

acc_loop <- new_stream_accumulator(reservoir_size = 200)
for (val in x) acc_loop$update(val)

cat("Mean match:", isTRUE(all.equal(acc_loop$getMean(), acc$getMean())), "\n")
cat("Var  match:", isTRUE(all.equal(acc_loop$getVariance(), acc$getVariance())), "\n\n")

# ------------------------------------------------------------
# 3. Numerical stability check: Welford vs naive two-pass formula
#    on data with a large mean offset (classic catastrophic
#    cancellation scenario for the naive sum-of-squares formula)
# ------------------------------------------------------------
cat("=== Numerical stability: Welford vs naive variance formula ===\n")

x_shifted <- rnorm(10000, mean = 1e8, sd = 1)

acc_shift <- new_stream_accumulator()
acc_shift$update_vec(x_shifted)

naive_var <- function(x) {
  n <- length(x)
  (sum(x^2) - n * mean(x)^2) / (n - 1)   # classic naive formula
}

cat("R's var()       :", var(x_shifted), "\n")
cat("Welford (Rcpp)  :", acc_shift$getVariance(), "\n")
cat("Naive formula   :", naive_var(x_shifted), "\n")
cat("(Naive formula may show visible error due to catastrophic",
    "cancellation; Welford should match var() closely)\n\n")

# ------------------------------------------------------------
# 4. Performance check: Rcpp StreamAccumulator vs a naive
#    pure-R online mean/variance implementation
# ------------------------------------------------------------
cat("=== Performance: Rcpp vs pure R online implementation ===\n")

r_online_stats <- function(x) {
  n <- 0; mean <- 0; M2 <- 0
  for (val in x) {
    n <- n + 1
    delta <- val - mean
    mean <- mean + delta / n
    delta2 <- val - mean
    M2 <- M2 + delta * delta2
  }
  list(mean = mean, variance = M2 / (n - 1))
}

x_big <- rnorm(50000)

t_rcpp <- system.time({
  acc_big <- new_stream_accumulator()
  acc_big$update_vec(x_big)
})

t_r <- system.time({
  r_online_stats(x_big)
})

cat("Rcpp implementation time (s):", t_rcpp["elapsed"], "\n")
cat("Pure R implementation time (s):", t_r["elapsed"], "\n")
cat("Speedup factor:", round(t_r["elapsed"] / t_rcpp["elapsed"], 1), "x\n\n")

cat("=== Benchmark verification complete ===\n")
