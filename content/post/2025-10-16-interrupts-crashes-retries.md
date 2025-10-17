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
2025. I got a bit stalled over the holidays and while attending the
fantastic useR! 2025 conference, but, as promised, here is the fourth
in a series of blog posts highlighting recent improvements to the
**[futureverse]** ecosystem.


## TL;DR

In the past, futures that were interrupted or abruptly terminated
were likely putting the future ecosystem in a corrupt state, where you
had to manually restart the future backend. This is no longer needed;

1. Futures now handle evaluation interrupts

2. Futures now handle abrupt parallel worker terminations ("crashes")

3. Crashed workers are automatically restarted



## Interrupts 🛑

Below is a future that emulates an R expression being interrupted
mid-evaluation:

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

Having R interrupt itself like this is uncommon, but it can happen if
`plan(sequential)` is used and the user presses <kbd>Ctrl-C</kbd>
(common) or sends `kill -SIGINT <worker-pid>` (less common).

There are other ways to interrupt a future - more on that in a future
post.


## Crashed workers 💥

Below is a future that emulates a parallel worker abruptly terminating
("crashing") during evaluation:

```r
library(future)
plan(multisession)

f <- future({ a <- 42; tools::pskill(Sys.getpid()); 2 * a })
```

Here `tools::pskill(Sys.getpid())` kills the R worker process
evaluating the call.  In practice, a worker might crash for various
reasons. For instance,

* The R process may run out of memory and be killed by the OS ("OOM
  killer")

* In an HPC environment, the job scheduler might terminate the worker
  if it exceeds memory or runtime limits

* The user might manually kill the worker (e.g., `kill -SIGQUIT
  <worker-pid>`) or cancel the HPC job (`scancel <job-id>` or `qdel
  <job-id>`)

Regardless how the parallel worker is terminated, requesting the value
yields:

```r
v <- value(f)
#> Error: Future (<unnamed-4>) of class MultisessionFuture interrupted,
#> while running on 'localhost' (pid 538181)
```

Technically, this error also inherits `FutureInterruptError`, just
like when there is a user interrupt. This behavior is consistent
across all backends, though some provide more detailed error messages.

Crashed workers are automatically restarted by the future backend,
meaning that you no longer have to manually restart the backend to
achieve the same.

Note that only the worker is restarted - the future itself is _not_.


## Retrying an interrupted future 🔁

Regardless of why a future was interrupted, you can restart it by
first calling `reset()`, then triggering re-evaluation via
`resolved()` or `value()`.

For example, consider a problematic function that crashes the worker
about 50% of the time:

```r
problematic_fcn <- function(x) {
  if (proc.time()[3] %% 1 < 0.5)
    tools::pskill(Sys.getpid())
  sqrt(x)
}
```

If called in a parallel worker, we could retry, say, up to ten times,
before giving up:

```r
library(future)
plan(multisession)

f <- future({ problematic_fcn(9) })

for (kk in 10:1) 
  tryCatch({
    v <- value(f)
    break
  }, FutureInterruptError = function(e) {
    if (kk == 1) stop(e)
    message("future interrupted, retrying ...") 
    f <- reset(f)
  })
}

message("value: ", v)
```

This might result in:

```
future interrupted, retrying ...
future interrupted, retrying ...
future interrupted, retrying ...
value: 3
```

It is a fun excercise to write a help function `future_retry()` to
simplify this as:

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
