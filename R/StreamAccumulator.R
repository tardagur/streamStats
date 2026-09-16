#' @useDynLib streamStats, .registration = TRUE
#' @importFrom Rcpp evalCpp loadModule
#' @importFrom methods new
NULL

# Load the Rcpp module so its Reference Class is available in R.
Rcpp::loadModule("streamstats_module", TRUE)


#' Create a new Streaming Statistics Accumulator
#'
#' Constructs an object that ingests numeric data incrementally (one value
#' or one vector at a time) and maintains running mean, variance, standard
#' deviation, min, max, and a fixed-size reservoir sample -- all without
#' storing the full dataset in memory. Internally backed by an Rcpp Module
#' class implementing Welford's online algorithm for numerically stable
#' mean/variance updates.
#'
#' @param reservoir_size Integer. Maximum number of points to retain in the
#'   random reservoir sample. Default is 100.
#'
#' @return An object of class \code{StreamAccumulator} (an Rcpp Module /
#'   Reference Class instance) with the following methods:
#'   \describe{
#'     \item{\code{update(x)}}{Ingest a single numeric value.}
#'     \item{\code{update_vec(x)}}{Ingest a numeric vector, one element at a time.}
#'     \item{\code{getN()}}{Number of values ingested so far.}
#'     \item{\code{getMean()}}{Current running mean.}
#'     \item{\code{getVariance()}}{Current running sample variance (n-1 denominator).}
#'     \item{\code{getSD()}}{Current running sample standard deviation.}
#'     \item{\code{getMin()} / \code{getMax()}}{Running min/max.}
#'     \item{\code{getSample()}}{Current reservoir sample as a numeric vector.}
#'     \item{\code{summary()}}{Named list of n, mean, variance, sd, min, max.}
#'     \item{\code{reset()}}{Reset the accumulator to its empty initial state.}
#'   }
#'
#' @examples
#' acc <- new_stream_accumulator()
#' acc$update_vec(c(1, 2, 3, 4, 5))
#' acc$getMean()
#' acc$summary()
#'
#' @export
new_stream_accumulator <- function(reservoir_size = 100L) {
  reservoir_size <- as.integer(reservoir_size)
  if (length(reservoir_size) != 1 || is.na(reservoir_size) || reservoir_size < 1) {
    stop("`reservoir_size` must be a single positive integer.")
  }
  acc <- new(StreamAccumulator, reservoir_size)
  acc
}

#' Summarize a Streaming Accumulator
#'
#' S3 method so that \code{summary()} works naturally on a
#' \code{StreamAccumulator} object, printed as a tidy data frame.
#'
#' @param object A \code{StreamAccumulator} object created by
#'   \code{new_stream_accumulator()}.
#' @param ... Additional arguments (currently unused).
#'
#' @return A one-row data frame with n, mean, variance, sd, min, max.
#' @export
summary.Rcpp_StreamAccumulator <- function(object, ...) {
  s <- object$summary()
  as.data.frame(s)
}

#' Print a Streaming Accumulator
#'
#' @param x A \code{StreamAccumulator} object.
#' @param ... Additional arguments (currently unused).
#' @export
print.Rcpp_StreamAccumulator <- function(x, ...) {
  cat("<StreamAccumulator>\n")
  cat(" n        :", x$getN(), "\n")
  cat(" mean     :", x$getMean(), "\n")
  cat(" sd       :", x$getSD(), "\n")
  cat(" min/max  :", x$getMin(), "/", x$getMax(), "\n")
  invisible(x)
}
