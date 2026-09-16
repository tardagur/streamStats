#include <Rcpp.h>
using namespace Rcpp;

// StreamAccumulator
// Maintains running mean/variance (Welford's algorithm), min/max,
// and a fixed-size reservoir sample -- all updated incrementally,
// one point (or one batch) at a time, without storing the full dataset.
class StreamAccumulator {
public:

  // Constructor with explicit reservoir size
  StreamAccumulator(int reservoir_size_)
    : n(0), mean(0.0), M2(0.0),
      min_val(R_PosInf), max_val(R_NegInf),
      reservoir_size(reservoir_size_) {}

  // Default constructor (reservoir size 100), delegates to the one above
  StreamAccumulator() : StreamAccumulator(100) {}

  // Ingest a single value
  void update(double x) {
    n++;

    // Welford's online mean/variance update
    double delta = x - mean;
    mean += delta / n;
    double delta2 = x - mean;
    M2 += delta * delta2;

    if (x < min_val) min_val = x;
    if (x > max_val) max_val = x;

    // Reservoir sampling ("Algorithm R")
    if ((int)reservoir.size() < reservoir_size) {
      reservoir.push_back(x);
    } else {
      double r = unif_rand();          // uses R's RNG stream (respects set.seed)
      int j = (int)(r * n);            // random index in [0, n-1]
      if (j < reservoir_size) {
        reservoir[j] = x;
      }
    }
  }

  // Ingest a vector of values, one at a time
  void update_vec(NumericVector x) {
    for (int i = 0; i < x.size(); i++) {
      update(x[i]);
    }
  }

  int getN() const { return n; }

  double getMean() const {
    return n > 0 ? mean : NA_REAL;
  }

  double getVariance() const {
    // Sample variance (n-1 denominator), matches R's var()
    if (n < 2) return NA_REAL;
    return M2 / (n - 1);
  }

  double getSD() const {
    double v = getVariance();
    return R_IsNA(v) ? NA_REAL : std::sqrt(v);
  }

  double getMin() const { return n > 0 ? min_val : NA_REAL; }
  double getMax() const { return n > 0 ? max_val : NA_REAL; }

  NumericVector getSample() const {
    return wrap(reservoir);
  }

  List summary() const {
    return List::create(
      Named("n")        = getN(),
      Named("mean")     = getMean(),
      Named("variance") = getVariance(),
      Named("sd")       = getSD(),
      Named("min")      = getMin(),
      Named("max")      = getMax()
    );
  }

  // Reset the accumulator to its initial empty state
  void reset() {
    n = 0;
    mean = 0.0;
    M2 = 0.0;
    min_val = R_PosInf;
    max_val = R_NegInf;
    reservoir.clear();
  }

private:
  int n;
  double mean;
  double M2;
  double min_val;
  double max_val;
  int reservoir_size;
  std::vector<double> reservoir;
};

// Expose the class to R as a Reference Class via Rcpp Modules
RCPP_MODULE(streamstats_module) {
  class_<StreamAccumulator>("StreamAccumulator")

  .constructor()              // StreamAccumulator$new()
  .constructor<int>()         // StreamAccumulator$new(reservoir_size)

  .method("update",     &StreamAccumulator::update)
  .method("update_vec", &StreamAccumulator::update_vec)
  .method("getN",        &StreamAccumulator::getN)
  .method("getMean",     &StreamAccumulator::getMean)
  .method("getVariance", &StreamAccumulator::getVariance)
  .method("getSD",       &StreamAccumulator::getSD)
  .method("getMin",      &StreamAccumulator::getMin)
  .method("getMax",      &StreamAccumulator::getMax)
  .method("getSample",   &StreamAccumulator::getSample)
  .method("summary",     &StreamAccumulator::summary)
  .method("reset",       &StreamAccumulator::reset)
  ;
}
