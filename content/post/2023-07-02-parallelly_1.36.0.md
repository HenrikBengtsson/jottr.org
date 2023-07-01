---
title: "parallelly: Querying, Killing and Cloning Parallel Workers Running Locally or Remotely"
slug: "parallelly-managing-workers"
date: 2023-07-01 18:00:00 +0200
categories:
 - R
tags:
 - R
 - package
 - parallel
 - parallelly
 - parallel processing
 - compute clusters
 - hpc
---

<div style="padding: 2ex; float: right;"/>
 <center>
   <img src="/post/parallelly-logo.png" alt="The 'parallelly' hexlogo"/>
 </center>
</div>

**[parallelly]** 1.36.0 is on CRAN since May 2023. The **parallelly**
package is part of the [Futureverse] and enhances the **parallel**
package of base R, e.g. it adds several features you'd otherwise
expect to see in **parallel**.  The **parallelly** package is one of
the internal work horses for the **[future]** package, but it can also
be used outside of the future ecosystem.

In this most recent release, **parallelly** gained several new skills
in how cluster nodes (a.k.a. parallel workers) can be managed.  Most
notably,

* the [`isNodeAlive()`] function can now also query parallel workers
  running on remote machines.  Previously, this was only possible to
  workers running on the same machine.

* the [`killNode()`] function gained the power to terminate parallel
  workers running also on remotes machines.

* the new function [`cloneNode()`] can be used to "restart" a cluster
  node, e.g. if a node was determined to no longer be alive by
  `isNodeAlive()`, then `cloneNode()` can be called to launch an new
  parallel worker on the same machine as the previous worker.

* The `print()` functions for PSOCK clusters and PSOCK nodes reports
  on the status of the parallel workers.


## Examples

Assume we're running a PSOCK cluster of two parallel workers - one
running on the local machine and the other on a remote machine that we
connect to over SSH.  Here is how we can set up such a cluster using
**parallelly**:

```r
library(parallelly)

cl <- makeClusterPSOCK(c("localhost", "server.remote.org"))
print(cl)
# Socket cluster with 2 nodes where 1 node is on host 'server.remote.org' (R
# version 4.3.1 (2023-06-16), platform x86_64-pc-linux-gnu), 1 node is on host
# 'localhost' (R version 4.3.1 (2023-06-16), platform x86_64-pc-linux-gnu)
```


We can check if these two parallel workers are running.  We can check
this even if they are busy processing parallel tasks.  The way
`isNodeAlive()` works is that it checks of the _process_ is running on
worker's machine, which is something that can be done even when the
worker is busy. For example, let's check the first worker process that
run on the current machine:

```r
print(cl[[1]])
## RichSOCKnode of a socket cluster on local host 'localhost' with pid 2457339
## (R version 4.3.1 (2023-06-16), x86_64-pc-linux-gnu) using socket connection
## #3 ('<-localhost:11436')

isNodeAlive(cl[[1]])
## [1] TRUE
```

In **parallelly** (>= 1.36.0), we can now also query the remote machine:

```r
print(cl[[2]])
## RichSOCKnode of a socket cluster on remote host 'server.remove.org' with
## pid 7731 (R version 4.3.1 (2023-06-16), x86_64-pc-linux-gnu) using socket
## connection #4 ('<-localhost:11436')

isNodeAlive(cl[[2]])
## [1] TRUE
```

We can also query _all_ parallel workers of the cluster at once, e.g.

```r
isNodeAlive(cl)
## [1] TRUE TRUE
```


Now, imagine if, say, the remote parallel process terminates for some
unknown reasons.  For example, the code running in parallel called
some code that causes the parallel R process to crash and terminate.
Although this "should not" happen, we all experience it once in a
while.  Another example is that the machine is running out of memory,
for instance due to other misbehaving processes on the same machine.
When that happens, the operating system might start killing processes
in order not to completely crash the machine.

When one of our parallel workers has crashed, it will obviously not
respond to requests for processing our R tasks.  Instead, we will get
obscure errors like:

```r
y <- parallel::parLapply(cl, X = X, fun = slow_fcn)
## Error in summary.connection(connection) : invalid connection
```

We can see that the second parallel worker in our cluster is no longer
alive by:

```r
isNodeAlive(cl)
## [1] TRUE FALSE
```

We can also see that there is something wrong with the one of our
workers if we call `print()` on our `RichSOCKcluster` and
`RichSOCKnode` objects, e.g.

```r
print(cl)
## Socket cluster with 2 nodes where 1 node is on host 'server.remote.org'
## (R version 4.3.1 (2023-06-16), platform x86_64-pc-linux-gnu), 1 node is
## on host 'localhost' (R version 4.3.1 (2023-06-16), platform
## x86_64-pc-linux-gnu). 1 node (#2) has a broken connection (ERROR:
## invalid connection)
```

and

```r
print(cl[[1]])
## RichSOCKnode of a socket cluster on local host 'localhost' with pid
## 2457339 (R version 4.3.1 (2023-06-16), x86_64-pc-linux-gnu) using
## socket connection #3 ('<-localhost:11436')

print(cl[[2]])
## RichSOCKnode of a socket cluster on remote host 'server.remote.org'
## with pid 7731 (R version 4.3.1 (2023-06-16), x86_64-pc-linux-gnu)
## using socket connection #4 ('ERROR: invalid connection')
```

If we end up with a broken parallel worker like this, we can since
**parallelly** 1.36.0 use `cloneNode()` to re-create the original
worker.  In our example, we can do:

```r
cl[[2]] <- cloneNode(cl[[2]])
print(cl[[2]])
## RichSOCKnode of a socket cluster on remote host 'server.remote.org'
## with pid 19808 (R version 4.3.1 (2023-06-16), x86_64-pc-linux-gnu)
## using socket connection #4 ('<-localhost:11436')
```

to get a working parallel cluster, e.g.

```r
isNodeAlive(cl)
## [1] TRUE TRUE
```

and

```r
y <- parallel::parLapply(cl, X = X, fun = slow_fcn)
str(y)
## List of 8
##  $ : num 1
##  $ : num 1.41
##  $ : num 1.73
```

We can also use `cloneNode()` to launch _additional_ workers of the
same kind. For example, say we want to launch two more local workers
and one more remote worker, and append them to the current cluster.
One way to achieve that is:

```r
cl <- c(cl, cloneNode(cl[c(1,1,2)]))
print(cl)
## Socket cluster with 5 nodes where 3 nodes are on host 'localhost'
## (R version 4.3.1 (2023-06-16), platform x86_64-pc-linux-gnu), 2
## nodes are on host 'server.remote.org' (R version 4.3.1 (2023-06-16),
## platform x86_64-pc-linux-gnu)
```

Now, consider we launching many heavy parallel tasks, where some of
them run on remote machines.  However, after some time, we realize
that we have launched tasks that will take much longer to resolve than
we first anticipated.  If we don't want to wait for this to resolve by
itself, we can choose to terminate some or all of the workers using
`killNode()`.  For example,

```r
killNode(cl)
## [1] TRUE TRUE TRUE TRUE TRUE
```

will kill all parallel workers in our cluster, even if they are busy
running tasks.  We can confirm that these worker processes are no
longer alive by calling:

```r
isNodeAlive(cl)
## [1] FALSE FALSE FALSE FALSE FALSE
```

If we would attempt to use the cluster, we'd get the "Error in
unserialize(node$con) : error reading from connection" as we saw
previously.  After having killed our cluster, we can re-launch it
using `cloneNode()`, e.g.

```r
cl <- cloneNode(cl)
isNodeAlive(cl)
## [1] TRUE TRUE TRUE TRUE TRUE
```


## The new cluster managing skills enhances the future ecosystem

When we use the [`cluster`] and [`multisession`] parallel backends of
the **future** package, we rely on the **parallelly** package
internally.  Thanks to these new abilities, the Futureverse can now
give more informative error message whenever we fail to launch a
future or when we fail to retrieve the results of one.  For example,
if a parallel worker has terminated, we might get:

```r
f <- future(slow_fcn(42))
## Error: ClusterFuture (<none>) failed to call grmall() on cluster
## RichSOCKnode #1 (PID 29701 on 'server.remote.org'). The reason reported
## was 'error reading from connection'. Post-mortem diagnostic: No process
## exists with this PID on the remote host, i.e. the remote worker is no
## longer alive
```

That post-mortem diagnostic is often enough to realize something quite
exceptional has happened. It also gives us enough information to
troubleshooting the problem further, e.g. if we keep seeing the same
problem occurring over and over for a particular machine, it might
suggest that there is an issue on that machine and we want to exclude
it from further processing.

We could imagine that the **future** package would not only give us
information on why things went wrong, but it could theoretically also
try to fix the problem automatically.  For instance, it could
automatically re-create the crashed worker using `cloneNode()`, and
re-launch the future.  It is on the roadmap to add such robustness to
the future ecosystem later on. However, there are several things to
consider when doing so.  For instance, what should happen if it was
not a glitch, but that there is one parallel task that keeps crashing
the parallel workers over and over?  Most certainly, we want to only
retry a fixed number of times, before giving up, otherwise we might
get stuck in a never ending procedure.  But even so, what if the
problematic parallel code brings down the machine where it runs?  If
we have automatic restart of workers and parallel tasks, we might end
up bringing down multiple machines before we notice the problem.  So,
although it appears fairly straightforward to handle crashed workers
automatically, we need to come up with a robust, well-behaving
strategy for doing so before we can implement it.

I hope you find this useful. If you have questions or comments on
**parallelly**, or the Futureverse in general, please use the
[Futureverse Discussion forum].

Henrik


## Links

* **parallelly** package: [CRAN](https://cran.r-project.org/package=parallelly), [GitHub](https://github.com/HenrikBengtsson/parallelly), [pkgdown](https://parallelly.futureverse.org)
* **future** package: [CRAN](https://cran.r-project.org/package=future), [GitHub](https://github.com/HenrikBengtsson/future), [pkgdown](https://future.futureverse.org)
* **Futureverse**: <https://www.futureverse.org>

[future]: https://future.futureverse.org
[parallelly]: https://parallelly.futureverse.org
[Futureverse]: https://www.futureverse.org
[Futureverse Discussion forum]: https://github.com/HenrikBengtsson/future/discussions/
[`cloneNode()`]: https://parallelly.futureverse.org/reference/cloneNode.html
[`killNode()`]: https://parallelly.futureverse.org/reference/killNode.html
[`isNodeAlive()`]: https://parallelly.futureverse.org/reference/isNodeAlive.html
[`cluster`]: https://future.futureverse.org/reference/cluster.html
[`multisession`]: https://future.futureverse.org/reference/multisession.html
