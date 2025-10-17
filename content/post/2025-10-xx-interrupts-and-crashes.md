---
title: "Futures: Interrupts, Crashes, and Retries"
date: 2025-10-16
slug: interrupts-crashes-retries
categories:
 - R
tags:
 - R
 - futureverse
 - future
 - interrupts
 - crashes
 - termination
 - parallel
 - parallel processing
 - future ten years
---

<!--
<div style="font-weight: bold; font-size: 200%; padding: 5ex">
Interrupts 🛑<br><br>
Crashes 💥<br><br>
Retries 🔁
</div>
-->
<img src="/post/interrupts-crashes-retries.png" alt="Interrupts 🛑, Crashes 💥, Retries 🔁" style="width: 30%; padding: 2ex; border: 1px solid; margin-left: 3ex; float: right;"/>

The **future** package [celebrates ten years on CRAN] as of June 19,
2025. I got a bit stalled over the holidays and going to the fantastic
useR! 2025 conference, but, as promised, here is the third in a series
of blog posts highlighting recent improvements to the
**[futureverse]** ecosystem.


## TL;DR

In the past, futures that were interrupted and abruptly terminated
were likely putting the future ecosystem in a corrupt state, where you
had to manually restart the future backends. This is no longer needed;

1. futures now handle when the evaluation is interrupted,

2. futures now handle when the parallel workers terminates abruptly
   ("crashes"), and

3. crashed workers are restarted automatically



## Interrupts 🛑

Here is a future that emulates how the evaluation of the R expression
is interrupted in the middle of the evaluation:

```r
library(future)

f <- future({ a <- 42; rlang::interrupt(); 2 * a })
```

If we attempt to retrieve the value of this future, we get:

```r
v <- value(f)
#> Error: A future (<unnamed-1>) of class SequentialFuture was interrupted
#> at 2025-10-15T15:37:09, while running on 'localhost' (pid 530375)
```

This works the same across all future backends, e.g.

```r
plan(future.mirai::mirai_multisession)
f <- future({ a <- 42; rlang::interrupt(); 2 * a })
v <- value(f)
#> Error: A future (<unnamed-2>) of class MiraiMultisessionFuture was
#> interrupted at 2025-10-15T15:39:17, while running on 'localhost' (pid 531734)
```

That R code produces an interrupt on itself like in the above example
is less common, but it might happen if `plan(sequential)` is used and
the user presses <kbd>Ctrl-C</kbd> (common), or uses another future
backend and sends `kill -SIGINT <worker-pid>` (less common).

There are also other ways to interrupt a future, but more on that in a
future blog post.


## Crashed workers 💥

Here is a future that emulates how the parallel worker abruptly
terminates ("crashes") while the R expression is evaluated:

```r
library(future)
plan(multisession)

f <- future({ a <- 42; tools::pskill(Sys.getpid()); 2 * a })
```

Here `tools::pskill(Sys.getpid())` results in the parallel R worker
process that evaluates that call to be killed. I reality, when a
parallel worker crashes, it may do so for various reasons. For
instance, the R process might run out of memory and gets killed by the
operating system (e.g. "OOM kill"). If running in a high-performance
compute (HPC) environment, the job scheduler might terminate the
parallel worker if the job uses more memory than requested, or it runs
for longer than the requested run-time.  The user might also choose to
kill the worker process manually (e.g. `kill -SIGQUIT <worker-pid>`),
or cancel an HPC job (e.g. `scancel <job-id>` and `qdel
<job-id>`). Regardless how the parallel worker is terminated, we will
get an error if we request the value of the corresponding future, e.g.

```r
v <- value(f)
#> Error: Future (<unnamed-4>) of class MultisessionFuture interrupted,
#> while running on 'localhost' (pid 538181)
```

Technically, this error also inherits `FutureInterruptError` just like
when there is a simple user interrupt as in previous section. This
works the same across all future backends, but the exact error message
might differ between the future-backend types, where some might
provide more information on what caused the problem.

Crashed workers are automatically restarted by the future backend,
meaning that we no longer have to manually restart our future backend,
if one of the workers crashed. Note that it is only the parallel
worker that is restart - the future itself is _not_ restarted.


## Retry an interrupted future 🔁

Regardless of why a future was interrupted, we can restart a future by
first resetting it with `reset()`, and then trigger it to be
restarted, e.g. calling `resolved()` or `value()` on it.

For example, consider a problematic R function that, for unknown
reasons, crashes the parallel worker 50% of the time it is called;

```r
problematic_fcn <- function(x) {
  if (proc.time()[3] %% 1 < 0.5) tools::pskill(Sys.getpid())
  sqrt(x)
}
```

If called in a parallel worker, we could retry, say, up to ten times,
before giving up. This could be achieved by sometime like:

```r
library(future)
plan(multisession)

f <- future({ problematic_fcn(9) })

for (kk in 10:1) {
  v <- tryCatch(value(f), FutureInterruptError = identity)
  if (!inherits(v, "FutureInterruptError")) break
  if (kk == 1) stop(v)
  message("retrying, because ", conditionMessage(v))
  f <- reset(f)
}
message("value: ", v)
```

This might result in something like:

```
retrying, because Future (<unnamed-159>) of class MultisessionFuture interrupted,
  while running on 'localhost' (pid 552212)
retrying, because Future (<unnamed-160>) of class MultisessionFuture interrupted,
  while running on 'localhost' (pid 552788)
retrying, because Future (<unnamed-161>) of class MultisessionFuture interrupted,
  while running on 'localhost' (pid 552831)
value: 3
```

It is a fun excercise to write a `future_retry()` function that would
simplify the above example to:

```r
f <- future_retry({ problematic_fcn(9) }, times = 10)
message("value: ", v)
```


_May the future be with you!_

Henrik


[celebrates ten years on CRAN]: /2025/06/19/futureverse-10-years/
[future]: https://future.futureverse.org
[futureverse]: https://www.futureverse.org
[H. Bengtsson (2021)]: https://journal.r-project.org/archive/2021/RJ-2021-048/index.html
