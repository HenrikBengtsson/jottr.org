---
title: "Future got better at finding global variables"
date: 2025-06-23
categories:
 - R
tags:
 - R
 - futureverse
 - future
 - globals
 - parallel
 - parallel processing
 - distributed processing
 - future ten years
---

<a href="/2025/06/19/futureverse-10-years/"><img src="/post/future-logo-balloons.png" alt="The 'future' hexlogo balloon wall" style="width: 20%; padding-left: 2ex; padding-bottom: 2ex; float: right;"/></a>

The **future** package [celebrates ten years on CRAN] as of June 19,
2025. This is the first of a series of blog posts highlighting recent
improvements to the **[futureverse]** ecosystem.

The **[globals]** package is part of the futureverse and has had two
recent releases on 2025-04-15 and 2025-05-08. These updates address a
few corner cases that would otherwise lead to unexpected errors. They
also resulted in several long, outstanding issues reported on the
**[future]**, **[future.apply]**, **[furrr]**, and **[doFuture]**
package issue trackers, and elsewhere, could be closed.

The significant update is that [`findGlobals()`] gained argument
`method = "dfs"`, which finds globals in R expressions by walking its
abstract syntax tree (AST) using a _depth-first-search_
algorithm. **This new approach does a better job of emulating how the
R engine identifies global variables, which results in an even
smoother ride for anyone using futureverse for parallel and
distributed processing.** Previously, a tweaked search algorithm
adopted from `codetools::findGlobals()` was used. The **[codetools]**
search algorithm is mainly designed for `R CMD check` to detect
undefined variables being used in package code. To limit the number of
false positives reported by `R CMD check`, such algorithms tend to be
"conservative" by nature, so that we can trust what is reported. This
strategy is not always sufficient for automatically detecting globals
needed in parallel processing. As an example, in

```r
fcn <- function() { 
  a <- b
  b <- 1 
}
```

variable `b` is a global variable, but if we ask **codetools**, it
does not pick up `b` as a global;

```r
codetools::findGlobals(fun)
#> [1] "{"  "<-"
```

This false negative is alright for `R CMD check`, but, in contrast,
for parallel processing, we need to use a "liberal" search
algorithm. In parallel processing it is okay to pick up and export too
many variables to the parallel worker. If a variable is not used,
little harm is done, but if we fail to export a needed variable, we'll
end up with an object-not-found error. Futureverse has since the early
days (December 2015) used a modified version of the **codetools**
algorithm that is liberal, but not too liberal. It detects `b` as a
global variable;


```r
globals::findGlobals(fun)
#> [1] "{"  "<-" "b"
```

This liberal search strategy turns out to work surprisingly well for
detecting globals needed in parallel processing, but there were corner
cases where it failed. For example, **futureverse** struggled to
identify global variables in cases such as:

```r
library(future)
plan(multisession, workers = 2)

x <- 2

f <- future(local({
  h <- function(x) -x
  h(x)
}))
value(f)
```

which resulted in

```
Error in eval(quote({ : object 'x' not found
```

This is because there are several different variables named `x`, and
the one in the calling environment is "masked" by argument `x`, which
results in `x` never be picked up and exported to the parallel worker.

It might look as if this type of code was carefully curated to fail,
but would rarely, if at all, be spotted in real code. As a matter of
fact, this is a distilled version of a large real-world scenario
reported by at least one person. It's thanks to such feedback that we
together can make improvements to the **futureverse** ecosystem 🙏 I
cannot know for sure, but I'd suspect this has impacted several R
developers already - the **future** package is after all among the
0.6% most downloaded packages and there are [1,300 packages that
"need" it](https://r-universe.dev/search?q=needs%3Afuture) as of
May 2025.  The above problem was fixed in **globals** 0.18.0
(2025-05-08) and **future** 1.49.0 (2025-05-09), which now make use of
the new `findGlobals(..., method = "dfs")` search strategy
internally. After updating these packages, the above code snippet
gives us

```r
value(f)
#> [1] -2
```

as we'd expect.

Another corner-case bug fix, is where

```r
library(future)
library(magrittr)
x <- list()
f <- future ({ x %>% `$<-`("a", 42) })
```

would result in the rather obscure error

```r
Error in e[[4]] : subscript out of bounds
```

This is due to [a
bug](https://gitlab.com/luke-tierney/codetools/-/issues/16) in the
**codetools** package, which **globals** (>= 0.17.0) [2025-04-15]
works around. After updating, things work as expected;

```r
f <- future ({ x %>% `$<-`("a", 42) })
value(f)
#> $a
#> [1] 42
```

Yet another fix in **globals** (>= 0.17.0) is that previous versions
would throw an error if it ran into an S7 object. The S7 object class
was introduced in 2023.


_May the future be with you!_

Henrik

PS. Did you know that the **codetools** package is [written using
literate
programming](https://gitlab.com/luke-tierney/codetools/-/blob/master/noweb/codetools.nw?ref_type=heads)
following the vision of Donald Knuth? Neat, eh? And, it's almost like
it was vibe coded, but with the large-language model (LLM) part being
replaced by human knowledge and expertise 🤓

[celebrates ten years on CRAN]: /2025/06/19/futureverse-10-years/
[codetools]: https://cran.r-project.org/package=codetools
[doFuture]: https://doFuture.futureverse.org
[future]: https://future.futureverse.org
[future.apply]: https://future.apply.futureverse.org
[furrr]: https://furrr.futureverse.org
[futureverse]: https://www.futureverse.org
[globals]: https://globals.futureverse.org
[`findGlobals()`]: https://globals.futureverse.org/reference/globalsOf.html
