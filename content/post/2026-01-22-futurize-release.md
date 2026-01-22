---
title: "futurize: Parallelize Common Functions via a \"Magic\" Touch 🪄"
slug: "futurize-0.1.0"
date: 2026-01-22
categories:
 - R
tags:
 - R
 - package
 - future
 - futurize
 - parallel processing
 - concurrency
 - map-reduce
 - apply
 - purrr
 - foreach
image: "/post/futurize-workflow.png"
---

<img src="/post/futurize-logo.png" alt="The 'futurize' hexlogo with a dark, starry background and a light blue border. The word 'FUTURIZE' appears in bold, orange gradient lettering across the center, with three diagonal orange bars above it. Below, the text reads 'MAGIC TOUCH PARALLELIZATION,' flanked by two small magic wands with sparkles, suggesting effortless parallel computing." style="width: 20%; float: right; margin-left: 1em;"/>

I am incredibly excited to announce the release of the **[futurize]** package. This launch marks a major milestone in the decade-long journey of the [Futureverse] project.

Since the inception of the **[future]** ecosystem, I (and others) have envisioned a tool that would make concurrent execution as simple as possible with minimal change to your existing code -- no refactoring, no new function names to memorize -- it should just work and work the same everywhere. I'm proud to say that with **futurize** this is now possible - take your map-reduce call of choice and pipe it into `futurize()`, e.g.

```r
y <- lapply(x, fcn) |> futurize()
```

That's it -- a "magic" touch by one function! Easy! 

(\*) _Yeah, there's no magic going on here -- it's just the beauty of R in action._


## Unifying the ecosystem

<img src="/post/futurize-workflow.png" alt="Diagram illustrating how sequential R map-reduce code can be parallelized with |> futurize(). On the left, sequential functions such as lapply(...), purrr::map(...), foreach(...) %do%, plyr::llply(...), and others flow into a central box labeled |> futurize() with magic-wand icons, indicating automatic transformation. On the right, the transformed code fans out to multiple parallel workers (Worker 1, Worker 2, Worker 3, ...), whose outputs are combined into a single 'Results' node." style="width: 100%; margin: 2em 0; border: 1px solid #eee; padding: 1em;"/>

One of the biggest hurdles in concurrent R programming has been the fragmentation of APIs and behavior. Packages such **[future.apply]**, **[furrr]**, and **[doFuture]** have partly addressed this. While they have simplified it for developers and users, they all require us to use slightly different function names and different parallelization arguments for controlling standard output, messages, warnings, and random number generation (RNG). `futurize()` changes this by providing **one unified interface** for all of them. It currently supports:

*   **base**: `lapply()`, `sapply()`, `apply()`, `replicate()`, etc.
*   **[purrr]**: `map()`, `map2()`, `pmap()`, and variants
*   **[foreach]**: `foreach() %do% { }`
*   **Others:** **[plyr]**, **[crossmap]**, and **[BiocParallel]**

Here is how it looks in practice. Notice how the map-reduce logic (e.g. `lapply()`) is identical regardless of the style you prefer:

``` r
# Base R
ys <- lapply(xs, fcn) |> futurize()

# purrr
ys <- map(xs, fcn) |> futurize()
ys <- xs |> map(fcn) |> futurize()

# foreach
ys <- foreach(x = xs) %do% { fcn(x) } |> futurize()
```

## The "magic" of one function

The `futurize()` function works as a _transpiler_.  The term "transpilation" describes the process of transforming source code from one form into another, a.k.a. source-to-source translation. It captures the original expression without evaluating it, then converts it into the concurrent equivalent, and finally executes the transpiled expression. It basically changes `lapply()` to `future.apply::future_lapply()` and `map()` to `furrr::future_map()` on the fly and it handles options on how to parallelize in a unifying way, and sometimes automatically. This allows you to write parallel code without blurring the underlying logic of your code.


## Domain-specific skills

The **futurize** package includes support also for a growing set of domain-specific packages, including **[boot]**, **[caret]**, **[glmnet]**, **[lme4]**, **[mgcv]**, and **[tm]**. These packages offer their own built-in, often complex, parallelization arguments. **futurize** abstracts all of that away. For example, instead of having to specify arguments such as `parallel = "snow", ncpus = 4, cl = cl`, with `cl <- parallel::makeCluster(4)` when using `boot()`, you can just do:

``` r
# Bootstrap with 'boot'
b <- boot(data, statistic, R = 999) |> futurize()

# Cross-validation with 'caret'
m <- train(Species ~ ., data = iris, method = "rf") |> futurize()
```





## Why I think you should use it

The **futurize** package follows the core design philosophy of the Futureverse: **separate "what" to execute concurrently from "how" to parallelize.** 

*   **Familiar code:** You write standard R code. If you remove `|> futurize()`, it runs the same.
*   **Familiar behavior:** Standard output, messages, warnings, and errors propagate as expected and as-is.
*   **Unified interface:** Future options work the same for `lapply()`, `map()`, and `foreach()` and so on, e.g. `futurize(stdout = FALSE)`.
*   **Backend independence:** Because it's built on the future ecosystem, your code can parallelize on any of the **[supported future backends]**. It scales up on your notebook, a remote server, or a massive high-performance compute (HPC) cluster with a single change of settings, e.g. `plan(future.mirai::mirai_multisession)`, `plan(future.batchtools::batchtools_slurm)`, and even `plan(future.p2p::cluster, cluster = "alice/friends")`.

Another way to put it, with **futurize**, you can forget about **future.apply**, **furrr**, and **doFuture** -- those packages are now working behind the scenes for you, but you don't really need to think about them.


## Installation

You can install the package from [CRAN](https://cran.r-project.org/package=futurize):

```r
install.packages("futurize")
```


## Outro

I hope that **[futurize]** makes your R coding life easier by removing technical details on parallel execution, allowing you to stay focused on the logic you want to achieve. I love to hear how you'll be using **futurize** in your R code. For questions, feedback, and feature requests, please reach out on the [Futureverse Discussions] forum.

_May the future be with you!_

Henrik


[Futureverse]: https://www.futureverse.org
[future]: https://future.futureverse.org
[futurize]: https://futurize.futureverse.org
[full documentation]: https://futurize.futureverse.org
[future.apply]: https://future.apply.futureverse.org
[furrr]: https://furrr.futureverse.org
[doFuture]: https://doFuture.futureverse.org
[crossmap]: https://cran.r-project.org/package=crossmap
[foreach]: https://cran.r-project.org/package=foreach
[plyr]: https://cran.r-project.org/package=plyr
[purrr]: https://cran.r-project.org/package=purrr
[BiocParallel]: https://www.bioconductor.org/packages/BiocParallel/
[boot]: https://cran.r-project.org/package=boot
[lme4]: https://cran.r-project.org/package=lme4
[mgcv]: https://cran.r-project.org/package=mgcv
[caret]: https://cran.r-project.org/package=caret
[glmnet]: https://cran.r-project.org/package=glmnet
[tm]: https://cran.r-project.org/package=tm
[supported future backends]: https://www.futureverse.org/backends.html
[Futureverse Discussions]: https://github.com/orgs/futureverse/discussions
