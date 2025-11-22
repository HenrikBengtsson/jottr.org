---
title: "Canceling Futures"
date: 2025-11-21
slug: canceling-futures
categories:
 - R
tags:
 - R
 - futureverse
 - future
 - cancel
 - interrupts
 - termination
 - parallel
 - parallel processing
 - future ten years
---

<!--
<div style="font-weight: bold; font-size: 200%; text-align: center; padding: 5ex">
Cancel ❌<br><br>
🡇&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<br><br>
Interrupt 🛑<br><br>
</div>
-->
<img src="/post/cancel-does-interrupt.png" alt="Cancel triggers an Interrupt" style="width: 30%; padding: 2ex; border: 1px solid; margin-left: 3ex; float: right;"/>

The **future** package [celebrates ten years on CRAN] as of June 19,
2025. This is the fifth in a series of blog posts highlighting recent
improvements to the **[futureverse]** ecosystem.


## TL;DR

In the previous post titled '[Futures: Interrupts, Crashes, and
Retries]', I showed how the future ecosystem now handle when futures
are interrupted by the user interrupts or when worker processes are
terminated abruptly.  In this post, I will cover the new `cancel()`
function for canceling futures. By default, canceling a future
triggers an attempt to interrupt the evaluation of the future.

The ability to cancel a future is an important feature that has been
missing from the future ecosystem. It has been one of most frequently
requested features by the community since the early days. I'm very
happy to share that this is now available throughout the futureverse
and that "it just works."


## Canceling a future

All unresolved futures can be canceled using the `cancel()` method,
e.g.

```r
f <- future({ slow_fcn() })
f <- cancel(f)
```

When we cancel a future, we tell R that we are no longer interested in
the result of the future. If we call `value()` on a canceled future,
we get an error;

```r
v <- value(f)
Error: Future (<unnamed-2>) of class MultisessionFuture was canceled, while
running on 'localhost' (pid 4026391)
```

By default, a future is interrupted when it is canceled.


## Interrupting a future

As I show in the '[Futures: Interrupts, Crashes, and Retries]' blog
post, futures can be "interrupted" by external mechanisms, e.g. user
interrupts (e.g. `kill -SIGINT`), job scheduler interrupts
(e.g. Slurm's `scancel` and SGE's `qdel`), and abrupt terminations
(e.g. Out-of-Memory (OOM) kill). The new `cancel()` method complements
this by providing a way to interrupt futures programmatically in R.

When we talk about the active action of "interrupting a future", what
we really mean is that we wish to interrupt the evaluation of the
future expression to free up resources sooner. If we are no longer
interested in the results of the future, but cannot interrupt it,
calling `value()` on the future results in it blocking until it has
been resolved, which might take a long time. In contrast, interrupting
a future stops the processing of the future, returns the results
momentarily, and makes the parallel worker available for other tasks
sooner.

Being able to interrupt a future is also important if a future
evaluation runs rogue, e.g. a future ends up consuming all the memory
or a future getting stuck in a never-ending loop.

The only way to interrupt a future programatically is via `cancel()` -
there exist no `interrupt()` or `kill()` method for futures. This is
by design - futureverse let you focus on "what" to do and less so on
"how" to do it. Regardless of a future being interrupted by `cancel()`
or via external means, as we have seen previously, calling `value()`
on an _interrupted_ future always result in an error. This is also by
design.


## Canceling versus interrupting a future

One reason for distinguishing between "canceling" and "interrupting" a
future, is that _all future can be canceled, but not all futures can
interrupted_. More precisely, not all future backends support
interrupting workers, meaning futures running on such backends cannot
be interrupted, but they can still be canceled.

An example of a non-interruptable future backend is where the parallel
workers run in an air-gapped environment to which we have no direct
communication channel other than channels for submitting futures,
querying their state, and collecting their results. With such a setup,
there is no way to signaling an interrupt, or by other means reaching
into the remote system and interrupting the parallel worker.

Although it is currently a rare setup, your code might end up running
on such non-interruptable backends in the future (pun intended). This
is why support for interrupting futures has to be optional
behavior. Regardless of interrupts being supported or not, your R code
will remain the same. If you no longer need the results of a future,
call `cancel()` to invalidate the future which causes the future to
trigger an error when calling `value()` on it. That the future might
be interrupted only affects how long `value()` blocks.

One way to remember the difference between canceling a future and
interrupting the evaluation of it, is the difference in intent:

 1. _cancel_ means "please invalidate the future, because its value is
    no longer of interested," and

 2. _interrupt_ means "please return as soon as possible by stopping
    the evaluation."

If the interrupt does not take place, the only downside is that we
have to wait longer for it to return. The exception is when there is a
rogue future that never returns[^1].

[^1]: Futures running forever can be handled by register an timeout
      limit in R. That will technically trigger a timeout interrupt,
      which futureverse handles like other interrupts. I will return
      to run-time limits in another blog post.

Regardless of a future being interrupted by `cancel()` or via external
means, as we have seen previously, calling `value()` on an
_interrupted_ future always result in an error. This is by design. I
will return to why producing an error on canceled or interrupted
futures is useful in a future blog post (pun not intended).

As shown on the '[Parallel Backends]' page, all known future backends
support interrupts, including built-in **[future]** backends, and
backends implemented by **[future.batchtools]**, **[future.callr]**,
and **[future.mirai]**. However, there are reasons for why we might
not want a backend to support interrupts by default. For example, the
overhead of signaling an interrupt might be too large, e.g. connection
to a parallel worker running on a remote machine to interrupt it might
take a very long time.

As a matter of fact, I have, for now, chosen to disable interrupts for
the `cluster` backend, because interrupting _remote_ workers requires
a one-time SSH into their machines, which can come with a huge over
head. If this is not the case for your SSH-based PSOCK cluster, you
can re-enable it by:

```r
plan(cluster, workers = hostnames, interrupts = TRUE)
```

If you are want to observe the different in behavior with and without
support for interrupts, you can do so for any backend by specifying
`interrupts = FALSE`, e.g.

```r
plan(future.mirai::mirai_multisession, interrupts = FALSE)
```


## Programming with cancelation and interrupts

Regardless of the future backend supports interrupting the parallel
workers, canceling a future results in a `FutureInterruptError` error
being produced by `value()` later on. Recall that we also get a
`FutureInterruptError` when the future is interrupted by external
factors. This means we can handle cancelations and interrupts using
R's built-in condition handlers.

Here is low-level example illustrating how we can implement a run-time
limit using `cancel()`. The future will be invalidated by `cancel()`
if not resolved within five seconds. Depending on support for
interrupts by the backend, this may interrupt the future for an early
return.

```r
library(future)
plan(future.mirai::mirai_multisession)

## Launch a long-running future
f <- future({ Sys.sleep(30); 42L })

## Cancel future if not resolved within 5 seconds
t0 <- proc.time()[3]
while (!resolved(f)) {
  ## Time out or continue waiting?
  if (proc.time()[3] - t0 > 5) {
    f <- cancel(f)
  } else {
    Sys.sleep(0.1)
  }
}

message("The future was resolved after ", format(difftime(proc.time()[3], t0)))

y <- tryCatch({
  value(f)
}, FutureInterruptError = function(int) {
  message("The future was interrupted")
  NA_integer_
})
print(y)
```

This outputs:

```
The future was resolved after 5.083 secs
The future was interrupted
[1] NA
```

If we shorten the future duration from 30 to four seconds, we get:

```r
The future was resolved after 4.076 secs
[1] 42
```

If the future backend does not support interrupts, we would have to
wait for the future to be fully resolved, which outputs:

```r
The future was resolved after 30.135 secs
[1] NA
```

_May the future be with you!_

Henrik

[futureverse]: https://www.futureverse.org/
[future]: https://future.futureverse.org/
[future.batchtools]: https://future.batchtools.futureverse.org/
[future.callr]: https://future.callr.futureverse.org/
[future.mirai]: https://future.mirai.futureverse.org/
[Parallel Backends]: https://www.futureverse.org/backends.html
[Futures: Interrupts, Crashes, and Retries]: /2025/10/16/interrupts-crashes-retries/
[celebrates ten years on CRAN]: /2025/06/19/futureverse-10-years/
