# streamStats

An R package implementing a streaming (online) statistics accumulator
using Welford's algorithm, exposed as an Object-Oriented class via
**Rcpp Modules**. The accumulator ingests numeric data incrementally
--- one value or one vector at a time --- and maintains a running mean,
variance, standard deviation, min, max, and a fixed-size reservoir
sample, without ever storing the full dataset in memory.

## Requirements

- R >= 4.0
- A working C++ compiler (Rtools on Windows, Xcode Command Line Tools
  on macOS, `build-essential` on Linux) -- required because this
  package compiles C++ source via Rcpp on installation.
- R packages: `Rcpp`, `remotes`

## Installation

```r
install.packages("remotes")  # if not already installed
remotes::install_github("tardagur/streamStats")
```

If you'd like to also build the vignette/documentation locally:

```r
remotes::install_github("tardagur/streamStats", build_vignettes = TRUE)
```

## Quick Start

```r
library(streamStats)

# Create a new accumulator (default reservoir size = 100)
acc <- new_stream_accumulator()

# Feed it data incrementally, or all at once
acc$update(5)
acc$update_vec(c(1, 2, 3, 4, 5))

# Query running statistics
acc$getMean()
acc$getVariance()
acc$getSD()
acc$summary()

# S3-style convenience methods also work
summary(acc)
print(acc)
```

## Verifying the Installation

See `VERIFY.R` in this repository, or the snippet below, for a
self-contained script that checks the package installed correctly and
that its core numerical guarantees hold.

## Package Structure

- `src/StreamAccumulator.cpp` -- Rcpp Module defining the C++ class
- `R/StreamAccumulator.R` -- R-facing constructor and S3 methods
- `tests/testthat/` -- automated unit tests (`devtools::test()`)
- `inst/scripts/benchmark_verification.R` -- exploratory benchmark
  script comparing results against base R
- `REPORT.md` -- written report on testing methodology and results

## License

MIT
