# 0.2.0

## Breaking Changes

* Object#try core-ext removed

* rules pass downcased body to regexp by default now, use downcase option if you don't want that


## Changes

* rule synopsis changed

    * rule now accepts one or two arguments, body_condition/proc-description and deprecated crosscheck boolean
    * passing a boolean argument is deprecated, use crosscheck: true/false
    * rule now accepts new keyword arguments
        * `crosscheck: true` whether crosscheck is required
        * `on: :body` should the condition be checked against :subject or :body
        * `body: CONDITION` sets on: :body and condition
        * `subject: CONDITION` sets on: :subject and condition

* new config options

    * Rule benchmarking
        * `set :benchmark_rules, true` record stats for rules (matching realtime, invocations, hits, misses)
        * `set :print_rules_benchmark, true` print these stats at the end (sorted by realtime asc)
        * `set :csv_rules_benchmark, "data/rule_benchmark.csv"` write stats to csv file

* performance improvements by better caching


## Deprecations

* rule synopsis changed
    `(condition, crosscheck = true, opts = {})` => `(*args, **opts)`
    whereas `crosscheck: true` is now an keyword option
    and args can be 0-2 arguments (see synopsis changes above)
