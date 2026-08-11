---
title: "The Resource Project: Tell R How Much Memory You Need"
date: 2026-08-11
slug: roadmap-resources-memory
categories:
 - R
tags:
 - R
 - futureverse
 - futurize
 - future
 - resources
 - roadmap
 - memory
---

{{< alert info >}}
This post describes experimental ideas and future plans for the Futureverse ecosystem. With one exception - 'futurize()', which is on CRAN today - the features shown here are not yet implemented.
{{< /alert >}}

Fit a cross-validated elastic net with `cv.glmnet(x, y)` on a design matrix that comfortably fits in memory, and the call can still fail. The reason is that the function needs several times the size of `x` while it runs, and nothing anywhere in your script says so. This post is about giving that requirement a home - a _memory specification_, written in R next to the code that knows it - first for a plain sequential call, then for the same call running in parallel.


## TL;DR

Write down what the call needs, as one annotation on otherwise ordinary code;

```r
fit <- cv.glmnet(x, y) |> resources(memory(4 * object.size(x)))
```

Better still, the memory specification need not stay at the call site. Once `cv.glmnet()` carries its own declaration, parallelization frameworks can make use of it, e.g.

```r
fits <- lapply(xs, FUN = cv.glmnet, y = y) |> futurize()
```

Either way, that one declaration is meant to do two jobs;

1. checked **before** the work starts - parallel or not - it fails fast instead of minutes or hours later, and
2. handed to a parallel framework, it also decides how many tasks can run in parallel.

The goal of the _[Resource Project]_ is to study, design, and implement these features in the [Futureverse]. Feedback and suggestions are welcome.


## Problem: We have no way of declaring memory needs

We check arguments all the time. A `stopifnot(is.matrix(x))` at the top of a function is second nature and in our muscle memory. It is useful because it helps functions fail fast when the wrong arguments are passed, and because we can give an informative error message. However, **we have nothing for checking whether the machine is actually capable of running the function**.

For example, you might not have enough memory available to perform a calculation. If you run out of memory, you might get:

```r
> fit <- cv.glmnet(x, y)
Error: cannot allocate vector of size 1.7 Gb
```

Worse is when the operating system steps in first and kills the R process outright. There is no R error to catch, no traceback, and no chance to shut down gracefully:

```sh
$ Rscript fit-model.R
Killed
$
```

Neither one tells you how much was needed, and both arrive after the work is already underway.

After you have identified the problem to be a memory issue, it often becomes a trial-and-error game, and it can take a while to figure out how much memory you need. The finding might then end up as a source-code comment in the script, or as a rarely-read sentence in a package help page. Either way, since the memory needs are not in the code, R cannot check it, cannot size the parallelization from it, and cannot give informative error messages when you run out of memory.


## Proposal: Check memory and fail fast

From rudimentary measurements and code inspections of **[glmnet]**, I found that `cv.glmnet(x, y)` needs roughly 3-4 times the memory of `object.size(x)` in addition to `x` itself. We can improve on this memory model[^model], but for simplicity, let's assume `cv.glmnet(x, y)` needs `4 * object.size(x)` _additional_ memory to be successful.

[^model]: A better memory model for `cv.glmnet()` has the form `a + b * object.size(x) + c * ncol(x)`: a fixed cost `a` that dominates while `x` is small, the `b * object.size(x)` term used above, and a `c * ncol(x)` term for per-column bookkeeping that only becomes visible on very wide matrices. Working out the coefficients, and how to measure them, is a project in itself. Once `x` is large, `b * object.size(x)` becomes the dominant term.

Let's take a numeric design matrix of 250,000 rows and 1,000 columns, which clocks in around 1.9 GiB of memory, as an example:

```r
x <- matrix(rnorm(250e3 * 1e3), nrow = 250e3, ncol = 1e3)
format(object.size(x), units = "GiB")
#> [1] "1.9 GiB"
```

Imagine a `freeMemory()` function for querying how much memory the current R process has available. With that, we could gatekeep our `fit <- cv.glmnet(x, y)` call as:

```r
stopifnot(freeMemory() >= 4 * object.size(x))
#> Error: freeMemory() >= 4 * object.size(x) is not TRUE
```

That fails _instantly_ and _before_ attempting the model fit, if there is not enough memory available. We could also imagine a richer vocabulary that provides us with more informative error messages, e.g.

```r
assert_resources(memory(4 * object.size(x)))
#> Error: UnmetResourceError: requires memory 7.5 GiB, available 3.1 GiB
```

In this project, we're proposing an `expr |> resources(...)` syntax for declaring and asserting resource needs, including memory requirements, next to the code where it applies. In our example, it would look like:

```r
fit <- cv.glmnet(x, y) |> resources(memory(4 * object.size(x)))
#> Error: UnmetResourceError: cv.glmnet(x, y) requires memory 7.5 GiB, available 3.1 GiB
```

This syntax preserves the original code and logic as-is, while allowing you to declare resource requirements that R can act on. In its most basic form, it effectively works like:

```r
fit <- {
  assert_resources(memory(4 * object.size(x)))
  cv.glmnet(x, y)
}
```

If you wonder whether this is worth the extra code, consider who pays when it is missing. Even an experienced user might spend hours locating the reason for a "cannot allocate vector" error or an "OOM-killed" message. A researcher new to high-performance compute (HPC) clusters might lose a day to it, file a support ticket, or quietly conclude that R cannot handle their data.

_The goal of this project is to not only reduce the amount of wasted compute resources, but also wasted human resources._


### Batch, still sequential

Now suppose we are not fitting one model but ten. Consider a study of patients with some clinical endpoint (`y`) profiled in several ways, including expression, copy number, miRNA, methylation, somatic mutation, chromatin accessibility, proteomics, phosphoproteomics, metabolomics, and lipidomics. Assume we want to know which of these omics datasets predict the outcome the best. We have one `y`, and ten `x` design matrices in a list:

```r
xs <- list(...)  # one design matrix per assay, ~8 GiB of them in total
```

Without memory protection, we would fit these models as:

```r
fits <- lapply(xs, function(assay) cv.glmnet(assay, y))
```

The resolution of the technologies varies greatly, so the different `x` matrices vary greatly in size. Methylation is often of the highest resolution. Let's assume its design matrix is 1.9 GiB in position `xs[[4]]`, and the smallest is a tenth of that. Similarly to before, we could protect against memory overuse by using:

```r
fits <- lapply(xs, function(assay) {
  cv.glmnet(assay, y) |> resources(memory(4 * object.size(assay)))
})
#> Error: UnmetResourceError: cv.glmnet(assay, y) requires memory 7.5 GiB, available 3.1 GiB
```

This tells you that one of the model fits would fail due to insufficient memory. Unfortunately, it does not fail instantly - it only fails when it tries to fit the too-large design matrix. Given that the largest matrix in this case happens to be in position four, you have already wasted efforts processing three cross-validation fits before failing. In the worst case, it could have processed nine out of the ten design matrices, before failing.

It would be better if the map-reduce call fails instantly, before attempting any model fits at all. We could make this happen if we move the declaration outside, so that the whole check happens prior to the model fits:

```r
fits <- lapply(xs, function(assay) cv.glmnet(assay, y)) |>
  resources(function(assay) memory(4 * object.size(assay)))
#> Error: UnmetResourceError: cv.glmnet(assay, y) requires memory 7.5 GiB for xs[[4]], available 3.1 GiB
```

What is new is that the specification is a _function_ rather than a fixed declaration. Somewhat simplified, this effectively checks the memory needs for all cross-validation fits first, before fitting them. Something like:

```r
fits <- {
  assert_resources(lapply(xs, function(assay) memory(4 * object.size(assay))))
  lapply(xs, function(assay) cv.glmnet(assay, y))
}
```

This is the argument from the top of this post applied to a batch rather than to a call, and it is where failing fast saves the most. You avoid wasting all calls, which means less wasted compute resources, faster troubleshooting, and quicker fixes.


### The declaration belongs on the function

In the above two examples, the _caller_ had to declare the memory needs. That is a bit backwards. In order to do this, I had to investigate what `cv.glmnet()` needs, and nobody should have to repeat that exercise for every modeling function they call. It would be better if the author of the function could specify that. One approach would be to attach a resource-specification function[^attr] to the function itself;

```r
resources(cv.glmnet) <- function(x, ...) memory(4 * object.size(x))
```

Technically, that sets `attr(cv.glmnet, "resources")` after having validated the function definition.

Next, we can have `resources()` look for such "resources" attributes and use them as the default, if found. So, if set, the memory-asserting call would become:

```r
fit <- cv.glmnet(x, y) |> resources()
#> Error: UnmetResourceError: cv.glmnet(x, y) requires memory 7.5 GiB, available 3.1 GiB
```

Note how the burden is no longer on the caller, but on the function maintainer, to declare resources.

The map-reduce call works the same way, once we tell it which function is used:

```r
fits <- lapply(xs, function(assay) cv.glmnet(assay, y)) |> resources(cv.glmnet)
#> Error: UnmetResourceError: cv.glmnet(assay, y) requires memory 7.5 GiB for xs[[4]], available 3.1 GiB
```

Handed a function that carries a declaration, `resources()` will use those declarations by default[^borrow].

[^attr]: The resource function arguments should match that of the function. Because of that, we could generate those automatically and simplify the setter to just be a quoted expression, e.g. `quote(resources(memory(4 * object.size(x))))`.

[^borrow]: It might be that static-code inspection can be used to avoid having to declare `resources(cv.glmnet)` and instead just use `fits <- lapply(xs, function(assay) cv.glmnet(assay, y)) |> resources()`.


### Functions guarding themselves

With a resource function attached to the function, the `cv.glmnet()` function could easily guard the resources upfront by using[^assert_resources]:

```r
cv.glmnet <- function(x, y, ...) {
  assert_resources()
  # ... the real work
}
```

This would remove the need for the caller to use `|> resources()`;

```r
fit <- cv.glmnet(x, y)
#> Error: UnmetResourceError: cv.glmnet(x, y) requires memory 7.5 GiB, available 3.1 GiB
```

[^assert_resources]: Called without arguments, `assert_resources()` queries `sys.function()` for the function currently being evaluated, takes its `"resources"` attribute, and calls it with the arguments of the call in progress.


### Attaching it to code you do not maintain

Even if a function does not carry a resource declaration, you can attach one yourself, e.g.

```r
cv.glmnet <- glmnet::cv.glmnet
resources(cv.glmnet) <- quote(memory(4 * object.size(x)))
```

That might be worth doing even for a single function in a single analysis script, preferably at the top of the script. It helps to gather such declarations in one place and avoids cluttering up the code, especially if the same function is used in multiple places.



## Parallel: the same memory specification decides how many tasks run at once

So far, we've only discussed resource specification in sequential processing. Another goal of this project is to make use of them also in parallel processing. For instance, already today we can use the **[futurize]** package and its `futurize()` function to parallelize `lapply()`, `purrr::map()`, `foreach()`, and friends through that single pipe. In our case, we could use:

```r
fits <- lapply(xs, function(assay) cv.glmnet(assay, y)) |>
  futurize()
```

Without memory protection, there is a great risk that you will run out of memory before you run out of CPU. Because of this, the goal is to support also:

```r
fits <- lapply(xs, function(assay) cv.glmnet(assay, y)) |>
  resources(function(assay) memory(4 * object.size(assay))) |>
  futurize()
```

Here the resource specifications would not only protect against memory overuse, but also be used for scheduling the parallel tasks, e.g. by limiting the number of memory-hungry parallel tasks running concurrently on the same machine.


### On a single machine

Consider using `plan(multisession)` where you have access to 32 GiB of memory and 16 CPU cores. That initiates 16 parallel workers. Each worker is a separate R process, and each task exports the matrix it is about to fit, so a task costs that matrix plus what fitting `cv.glmnet()` needs on top of that.

It is unlikely that you will be able to run 16 parallel model-fitting tasks with only 32 GiB. Even before turning to parallelization, you know that your design matrices in `xs` occupy 8 GiB of that memory, leaving you with at most 24 GiB for the parallel tasks. To fit the methylation assay, you need to export the 1.9 GiB matrix to the worker and then another 7.5 GiB to fit it, totaling 9.4 GiB. A task on one of the small assays costs a little under 4 GiB.

If you launched 16 parallel fits blindly, it's quite likely that you would run out of memory and the operating system's out-of-memory (OOM) killer may terminate your analysis. Given that none of this resource-specification framework exists today, the best you can do is to work the numbers yourself, and spin up only as many parallel workers as you can afford:

```r
## 32 GiB RAM, ~8 GiB for the R session holding 'xs', 9.4 GiB for the largest task
plan(multisession, workers = parallelly::availableCores(max = (32 - 8) / 9.4))
#> 2 workers
```

Two concurrent parallel tasks is the best guess you have. However, with the above resource specifications, `futurize()` could probably do better and fit additional cross-validation models concurrently, especially the smaller ones.


### On a compute cluster

On a high-performance compute (HPC) cluster, the _job scheduler_ (e.g. Slurm and SGE) decides which execution nodes your job lands on, based on the amount of memory it requests. For example, Slurm declaration `#SBATCH --mem=10G` tells the scheduler that this job requires 10 GiB of RAM to run.

By declaring such memory needs within R;

```r
plan(future.batchtools::batchtools_slurm)

fits <- lapply(xs, function(assay) cv.glmnet(assay, y)) |>
  resources(function(assay) memory(4 * object.size(assay))) |>
  futurize()
```

the **[future]** framework could work together with **[future.batchtools]** to translate each of the calculated resource needs into declarations understood by the job scheduler, which then can find appropriately sized slots on the cluster - all while maximizing the memory use but without ever running out of memory.


### Ideally, everything is hidden away

Just as with `resources()`, if `cv.glmnet()` declares its own resource needs, `futurize()` can also take advantage of that. That would close the circle such that code existing already today, e.g.

```r
fits <- lapply(xs, FUN = cv.glmnet, y = y) |> futurize()
```

would **become resource aware, protect against overuse, and optimize scheduling overnight - all without code changes**.


## Outro

Phew, that was quite long, and yet, I only got to cover a tiny bit of what the _[Resource Project]_ aims for. I discussed how we can manage _memory_ from within R, but there are many other compute resources that limit us. For example, we also want to manage walltime, scratch space, GPU cores, and GPU memory.

If you have other thoughts or ideas, we'd love to hear from you. Please reach out on the [Futureverse Discussions] forum.

_May the future be with you!_

Henrik


[Futureverse]: https://www.futureverse.org
[Resource Project]: https://www.futureverse.org/roadmap/resources.html
[glmnet]: https://glmnet.stanford.edu
[future]: https://future.futureverse.org
[futurize]: https://futurize.futureverse.org
[future.batchtools]: https://future.batchtools.futureverse.org/
[Futureverse Discussions]: https://github.com/orgs/futureverse/discussions
