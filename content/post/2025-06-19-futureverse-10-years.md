---
title: "Futureverse – Ten-Year Anniversary"
slug: "futureverse-10-years"
date: 2025-06-19
categories:
 - R
tags:
 - R
 - futureverse
 - future
 - parallel
 - parallel processing
 - distributed processing
 - future ten years
---

<figure style="margin-top: 3ex;">
<div style="padding: 2ex; float: right;"/>
 <center>
   <img src="/post/future-logo-balloons.png" alt="The 'future' hexlogo balloon wall" style="width: 80%;"/>
 </center>
</div>
<figcaption style="font-style: italic">

The future package turns ten on CRAN today – June 19, 2025.
<small>(Image credits: Dan LaBar for the future logo; Hadley Wickham
and Greg Swinehart for the ggplot2 logo and balloon wall; The future
balloon wall was inspired by ggplot2’s recent real-world version and
generated with ChatGPT.)</small>

</figcaption>
</figure>

The **[future]** package turns ten years old today. I released version
0.6.0 to CRAN on June 19, 2015, just days before I presented the
package and shared my visions at [useR! 2016]. I had no idea adoption
would snowball the way it has. It's been an exciting, fun journey, and
the best part has been you - the users and developers who shaped the
futureverse through questions, discussions, bug reports, and feature
requests. Thank you!

To celebrate, I’m kicking off a series of posts over the next few
weeks covering the latest improvements that make it easier than ever
to scale existing code up or out on a parallel or distributed backend
of your choice - and eventually in ways that are neater than what our
trusty workhorses **[future.apply]** and **[furrr]** offer.

These gains come from a slow, steady, multi-year process of
remodelling: internal redesigns, working with package maintainers to
retire use of deprecated functions, releasing, fixing regressions, and
repeating - all while end-users and most developers did not notice,
except for a few.  The first CRAN release where this work could be
noticed was **future** 1.40.0 (April 10), followed by regression fixes
and additional features in 1.49.0 (May 9), and lately 1.57.0 (June 5,
2025). More polishing and features are coming before we hit **future**
2.0.0 – in the near future (pun firmly intended).  Thanks for helping
make future a cornerstone of scalable R programming.

Posts in this series thus far:

* 2025-06-23: [Future Got Better at Finding Global Variables](/2025/06/23/future-got-better-at-finding-global-variables/)
* 2025-06-25: [Setting Future Plans in R Functions — and Why You Probably Shouldn't](/2025/06/25/with-plan/)


_Stay tuned and may the future be with you!_

Henrik

[future]: https://future.futureverse.org
[future.apply]: https://future.apply.futureverse.org
[furrr]: https://furrr.futureverse.org
[futureverse]: https://www.futureverse.org
[useR! 2016]: https://www.jottr.org/2016/07/02/future-user2016-slides/
