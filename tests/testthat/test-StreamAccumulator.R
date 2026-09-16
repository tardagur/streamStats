# ============================================================
# Unit tests for StreamAccumulator (Rcpp Module)
# ============================================================

test_that("empty accumulator (n=0) returns NA for all statistics", {
  acc <- new_stream_accumulator()

  expect_equal(acc$getN(), 0)
  expect_true(is.na(acc$getMean()))
  expect_true(is.na(acc$getVariance()))
  expect_true(is.na(acc$getSD()))
  expect_true(is.na(acc$getMin()))
  expect_true(is.na(acc$getMax()))
  expect_length(acc$getSample(), 0)
})

test_that("single observation (n=1) gives defined mean/min/max but NA variance/sd", {
  acc <- new_stream_accumulator()
  acc$update(7.5)

  expect_equal(acc$getN(), 1)
  expect_equal(acc$getMean(), 7.5)
  expect_equal(acc$getMin(), 7.5)
  expect_equal(acc$getMax(), 7.5)

  # Variance/SD are mathematically undefined for n=1 (n-1 = 0 denominator)
  expect_true(is.na(acc$getVariance()))
  expect_true(is.na(acc$getSD()))
})

test_that("two observations produce a correct, non-NA variance", {
  acc <- new_stream_accumulator()
  acc$update(2)
  acc$update(4)

  expect_equal(acc$getN(), 2)
  expect_equal(acc$getMean(), 3)
  expect_equal(acc$getVariance(), var(c(2, 4)))  # should be 2
  expect_equal(acc$getSD(), sd(c(2, 4)))
})

test_that("batch update_vec() matches base R exactly on random data", {
  set.seed(123)
  x <- rnorm(500, mean = 10, sd = 3)

  acc <- new_stream_accumulator(reservoir_size = 500)
  acc$update_vec(x)

  expect_equal(acc$getMean(), mean(x), tolerance = 1e-8)
  expect_equal(acc$getVariance(), var(x), tolerance = 1e-8)
  expect_equal(acc$getSD(), sd(x), tolerance = 1e-8)
  expect_equal(acc$getMin(), min(x))
  expect_equal(acc$getMax(), max(x))
  expect_equal(acc$getN(), length(x))
})

test_that("INVARIANT: one-at-a-time update() matches update_vec() batch loading", {
  set.seed(456)
  x <- rnorm(200)

  acc_batch <- new_stream_accumulator(reservoir_size = 200)
  acc_batch$update_vec(x)

  acc_loop <- new_stream_accumulator(reservoir_size = 200)
  for (val in x) acc_loop$update(val)

  expect_equal(acc_loop$getN(), acc_batch$getN())
  expect_equal(acc_loop$getMean(), acc_batch$getMean(), tolerance = 1e-10)
  expect_equal(acc_loop$getVariance(), acc_batch$getVariance(), tolerance = 1e-10)
  expect_equal(acc_loop$getMin(), acc_batch$getMin())
  expect_equal(acc_loop$getMax(), acc_batch$getMax())
})

test_that("negative numbers and zero are handled correctly", {
  x <- c(-10, -5, 0, 5, 10)
  acc <- new_stream_accumulator()
  acc$update_vec(x)

  expect_equal(acc$getMean(), mean(x))
  expect_equal(acc$getVariance(), var(x))
  expect_equal(acc$getMin(), -10)
  expect_equal(acc$getMax(), 10)
})

test_that("all-identical values produce zero variance (not NaN/negative)", {
  acc <- new_stream_accumulator()
  acc$update_vec(rep(5, 50))

  expect_equal(acc$getMean(), 5)
  expect_equal(acc$getVariance(), 0)
  expect_equal(acc$getSD(), 0)
  expect_false(is.nan(acc$getVariance()))
})

test_that("reservoir sample never exceeds reservoir_size, even with more data", {
  acc <- new_stream_accumulator(reservoir_size = 10)
  acc$update_vec(1:1000)

  expect_equal(acc$getN(), 1000)
  expect_length(acc$getSample(), 10)
  expect_true(all(acc$getSample() >= 1 & acc$getSample() <= 1000))
})

test_that("reservoir sample is fully populated once n <= reservoir_size", {
  acc <- new_stream_accumulator(reservoir_size = 50)
  acc$update_vec(1:20)

  expect_equal(acc$getN(), 20)
  expect_length(acc$getSample(), 20)  # not yet full, so sample == all data
  expect_equal(sort(acc$getSample()), as.numeric(1:20))
})

test_that("reset() restores the accumulator to its initial empty state", {
  acc <- new_stream_accumulator()
  acc$update_vec(rnorm(30))
  expect_gt(acc$getN(), 0)

  acc$reset()

  expect_equal(acc$getN(), 0)
  expect_true(is.na(acc$getMean()))
  expect_length(acc$getSample(), 0)
})

test_that("summary() returns a correctly named list matching individual getters", {
  acc <- new_stream_accumulator()
  acc$update_vec(c(1, 2, 3, 4, 5))
  s <- acc$summary()

  expect_named(s, c("n", "mean", "variance", "sd", "min", "max"))
  expect_equal(s$n, acc$getN())
  expect_equal(s$mean, acc$getMean())
  expect_equal(s$variance, acc$getVariance())
  expect_equal(s$sd, acc$getSD())
  expect_equal(s$min, acc$getMin())
  expect_equal(s$max, acc$getMax())
})

test_that("S3 summary() and print() methods dispatch correctly on the OO object", {
  acc <- new_stream_accumulator()
  acc$update_vec(c(10, 20, 30))

  # Rcpp Modules create S4 objects under the hood, not S3
  expect_s4_class(acc, "Rcpp_StreamAccumulator")

  df <- summary(acc)
  expect_s3_class(df, "data.frame")
  expect_equal(df$mean, 20)

  expect_output(print(acc), "StreamAccumulator")
})


test_that("new_stream_accumulator() validates reservoir_size input", {
  expect_error(new_stream_accumulator(reservoir_size = -5))
  expect_error(new_stream_accumulator(reservoir_size = 0))
  expect_error(new_stream_accumulator(reservoir_size = c(1, 2)))
})

test_that("Welford's algorithm remains numerically stable under a large mean offset", {
  set.seed(789)
  x <- rnorm(5000, mean = 1e8, sd = 1)

  acc <- new_stream_accumulator()
  acc$update_vec(x)

  # True variance should be close to 1 (sd=1 was used to generate x)
  expect_equal(acc$getVariance(), var(x), tolerance = 1e-4)
  expect_true(acc$getVariance() > 0 && acc$getVariance() < 5)
})
