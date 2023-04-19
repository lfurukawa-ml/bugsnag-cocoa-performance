//
//  Sampler.mm
//  BugsnagPerformance
//
//  Created by Nick Dowell on 26/10/2022.
//

#import "Sampler.h"
#import "BugsnagPerformanceConfiguration+Private.h"

using namespace bugsnag;

static NSString *kUserDefaultsKey = @"BugsnagPerformanceSampler";
static NSString *kProbabilityKey = @"p";

static double loadProbabilityOrDefault(double defaultProbability) {
    NSDictionary *dict = [[NSUserDefaults standardUserDefaults]
                          dictionaryForKey:kUserDefaultsKey];

    if (dict != nil) {
        id p = dict[kProbabilityKey];
        if ([p isKindOfClass:[NSNumber class]]) {
            return [p doubleValue];
        }
    }
    return defaultProbability;
}

static void storeProbability(double probability) {
    [[NSUserDefaults standardUserDefaults]
     setObject:@{
            kProbabilityKey: @(probability),
        }
     forKey:kUserDefaultsKey];
}

void Sampler::configure(BugsnagPerformanceConfiguration *config) noexcept {
    if (config.internal.forceSamplingProbability) {
        setProbability(config.samplingProbability);
    } else {
        probability_ = loadProbabilityOrDefault(config.samplingProbability);
    }
}

double
Sampler::getProbability() noexcept {
        return probability_;
}

void
Sampler::setProbability(double probability) noexcept {
    probability_ = probability;
    storeProbability(probability);
}

bool Sampler::sampled(SpanData &span) noexcept {
    auto p = getProbability();
    uint64_t idUpperBound;
    if (p <= 0.0) {
        idUpperBound = 0;
    } else if (p >= 1.0) {
        idUpperBound = UINT64_MAX;
    } else {
        idUpperBound = uint64_t(p * double(UINT64_MAX));
    }
    bool isSampled = span.traceId.hi <= idUpperBound;
    if (isSampled) {
        span.updateSamplingProbability(p);
    }

    return isSampled;

}

std::unique_ptr<std::vector<std::shared_ptr<SpanData>>>
Sampler::sampled(std::unique_ptr<std::vector<std::shared_ptr<SpanData>>> spans) noexcept {
    auto sampledSpans = std::make_unique<std::vector<std::shared_ptr<SpanData>>>();
    for (size_t i = 0; i < spans->size(); i++) {
        if (sampled(*(*spans)[i])) {
            sampledSpans->push_back((*spans)[i]);
        }
    }
    return sampledSpans;
}
