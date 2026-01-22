---
title: "foreach: Making All %dopar% Behave Like %dofuture% Everywhere"
date: 2025-10-08
slug: dofuture-everywhere
categories:
 - R
tags:
 - R
 - futureverse
 - future
 - doFuture
 - foreach
 - "%dopar%"
 - "%dofuture%"
 - parallel
 - parallel processing
 - future ten years
---

<a href="/2025/06/19/futureverse-10-years/"><img src="/post/future-logo-balloons.png" alt="The 'future' hexlogo balloon wall" style="width: 20%; padding-left: 2ex; padding-bottom: 2ex; float: right;"/></a>

The **future** package [celebrates ten years on CRAN] as of June 19,
2025. I got a bit stalled over the holidays and going to the fantastic
useR! 2025 conference, but, as promised, here is the third in a series
of blog posts highlighting recent improvements to the
**[futureverse]** ecosystem.

**[doFuture]** 1.10.0 is on CRAN as of May 2025 followed by two
  bug-fix releases in June and July. It comes with several
  improvements, but here I would like to focus on two new features:

 1. `registerDoFuture("%dofuture%")`, and

 2. `with(doFuture::registerDoFuture("%dofuture%"), local = TRUE)`


## Turn all %dopar% into %dofuture%

By registering

```r
doFuture::registerDoFuture("%dofuture%")
```

all existing code in scripts and packages that uses `%dopar%` of
**foreach** will behave as if `%dofuture%` was used instead. This can
be a step up from

```r
doFuture::registerDoFuture()
```

which indeed tells `%dopar%` to parallelize via the future framework,
but `%dofuture%` is even better - as I outline in my blog post
'[%dofuture% - a Better foreach() Parallelization Operator than
%dopar%].' For example, using an explicit `%dofuture%`, or forcing it
via `doFuture::registerDoFuture("%dofuture%")`, results in:

 * Messages, warnings, and other types of conditions generated in
   parallel are relayed as-is regardless of parallel backend. This is
   also true for standard output produced by `print()`, `cat()`,
   `str()`, etc. When using foreach _without_ Futureverse
   (e.g. **doParallel**), such output is lost to the void. In
   contrast, when using **doFuture**, it just works. You can also use
   `capture.output()` and `withCallingHandlers()` as you would do when
   you run things sequentially
   
 * Errors generated in parallel are relayed _as-is_ without them being
   wrapped up in other error objects. With `%dofuture%` they behave as
   you would expect, it becomes easier to troubleshoot errors, and
   errors can be handled by `tryCatch()`. This can be particularly
   useful if you use code that uses `%dopar%` but that does not handle
   errors

 * If there are issues with parallel workers (e.g. they crash), more
   informative error messages will be given, which helps to
   troubleshoot the underlying problem. Futureverse may also attempt
   to relaunch crashed parallel workers so that you do not have to
   shut everything down and restart from scratch, which might be the
   case otherwise
 
 * Global variables and packages needed in the parallel tasks are
   identified automatically and consistently by Futureverse,
   regardless of which parallel backend is used
 
In addition, it is possible to make:
 
 * Parallel random number generation (RNG) be done consistently via
   Futureverse, also when `%dopar%` is used and the developer forgot
   to use `%dorng%`

 * Get near-live progress updates via the **[progressr]** package,
   also when `%dopar%` is used


## For package developers 

If you're a developer and call another package that uses `foreach()`
with `%dopar%` internally, but wish it was using `%dofuture%`, then
you can add

```r
with(doFuture::registerDoFuture("%dofuture%"), local = TRUE)
```

to the top of your function. This will temporarily make `%dopar%`
behave like `%dofuture%` while your function is used. As soon as your
function returns, the temporarily registered foreach adapter is
undone. Easy!


## When to use?

If you find that some **foreach** code that you cannot modify, or
package that uses it, fails, gives hard-to-troubleshoot errors, or
does not output expected messages and warnings, then try with

```r
doFuture::registerDoFuture("%dofuture%")
# code or functions that call foreach(...) %dopar% { ... }
```

or

```r
with(doFuture::registerDoFuture("%dofuture%"), {
  # code or functions that call foreach(...) %dopar% { ... }
})
```


It might solve your problems, or at least, help you narrow them down.

Also, this new **doFuture** feature lays part of the foundation for a
new Futureverse feature that I'm very excited about. But more about
that later ...

_May the future be with you!_

Henrik


[celebrates ten years on CRAN]: /2025/06/19/futureverse-10-years/
[%dofuture% - a Better foreach() Parallelization Operator than %dopar%]: https://www.jottr.org/2023/06/26/dofuture/
[doFuture: A Universal Foreach Adaptor Ready to be Used by 1,000+ Packages]: https://www.jottr.org/2017/03/18/dofuture/
[foreach]: https://cran.r-project.org/package=foreach
[doFuture]: https://doFuture.futureverse.org
[future]: https://future.futureverse.org
[progressr]: https://progressr.futureverse.org
[futureverse]: https://www.futureverse.org
[BiocParallel]: https://bioconductor.org/packages/BiocParallel/
[H. Bengtsson (2021)]: https://journal.r-project.org/archive/2021/RJ-2021-048/index.html
