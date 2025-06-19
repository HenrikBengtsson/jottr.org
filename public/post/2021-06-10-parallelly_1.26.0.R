library(progressr)
handlers(global = TRUE)

handlers(handler_progress(
  format = ":spin :current/:total (:message) [:bar] :percent in :elapsed ETA: :eta",
  width = 120L
))

library(parallel)
library(parallelly)
max_ncores <- availableCores()
stopifnot(max_ncores > 1)
ncores <- 2^(0:log2(max_ncores))
B <- 5L

## Inject midway benchmark points
ncores <- unique(sort(c(ncores, ncores - c(0, 0, diff(diff(ncores))))))

## The maximum number of workers we can use is limited by the number
## of connections can open.
reserveConnections <- 4L  ## AD HOC: Need to reserve a few more
maxConnections <- freeConnections() - reserveConnections
ncores[ncores >= maxConnections] <- maxConnections
ncores <- unique(ncores)
max_ncores <- max(ncores)
message("Number of cores benchmarked: ", paste(ncores, collapse = ", "))

tags <- c(ncores=max_ncores, B=B, hostname=Sys.info()[["nodename"]])
tags <- sprintf("%s=%s", names(tags), tags)
tags <- paste(tags, collapse = "_")
name <- sprintf("stats_%s", tags)

fcns <- list(
  makeClusterPSOCK = makeClusterPSOCK,
  makePSOCKcluster = makePSOCKcluster
)
fcns <- fcns[c("makeClusterPSOCK")]

with_progress({
p <- progressor(B * length(fcns) * length(ncores) * 2L)
stats <- list()
for (bb in 1:B) {
  for (ii in seq_along(ncores)) {
    n <- ncores[ii]
    for (setup_strategy in c("sequential", "parallel")) {
      for (method in names(fcns)) {
        fcn <- fcns[[method]]
        dt <- system.time({
          cl <- fcn(n, rscript_args = "--vanilla", setup_strategy = setup_strategy)
        })[["elapsed"]]
        parallel::stopCluster(cl)
        stats_t <- data.frame(cores = n, method = method, setup_strategy = setup_strategy, time = dt)
        stats <- c(stats, list(stats_t))
        p(sprintf("n=%d, method = %s, %s, iteration=%d", n, method, setup_strategy, bb))
        gc()
      } ## for (method ...)
    }
  }
}
})

stats <- do.call(rbind, stats)
stats$setup_strategy <- factor(stats$setup_strategy, levels = c("sequential", "parallel"))
stats <- tibble::as.tibble(stats)
saveRDS(stats, file = sprintf("%s.rds", name))
print(stats, n = 10e3)

library(ggplot2)
gg <- ggplot(stats, aes(x=cores, y=time, color=setup_strategy))
gg <- gg + geom_smooth(size = 2, method = "loess", formula = y ~ x)
gg <- gg + xlab("Number of parallel workers")
gg <- gg + ylab("Total setup time (s)")
gg <- gg + labs(color = "Setup strategy")
ggsave(gg, filename = sprintf("%s.png", name), width = 7, height = 7/1.3)
print(gg)


strategies <- levels(stats$setup_strategy)
coeffs <- lapply(strategies, FUN = function(strategy) {
  stats_t <- subset(stats, setup_strategy == strategy)
  fit <- lm(time ~ cores, data = stats_t)
  coefficients(fit)
})
names(coeffs) <- strategies
print(coeffs)
## $sequential
## (Intercept)       cores 
## -0.07208812  0.42562891
## 
## $parallel
## (Intercept)       cores 
##  0.39637113  0.00594509

print(by(stats$time, INDICES = stats$setup_strategy, FUN = max))
## stats$setup_strategy: sequential
## [1] 51.971
## ------------------------------------------------------------ 
## stats$setup_strategy: parallel
## [1] 1.157
