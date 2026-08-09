WEBSITE=https://www.jottr.org

start: hugo_version
	Rscript -e "cat(paste0('\nBlogdown PID: ',Sys.getpid(),'\n'))" -e "blogdown::serve_site(port = print(port4me::port4me('jottr.org')))" &

stop:
	pkill hugo

restart: stop start

hugo_version:
	@Rscript -e "cat(paste0(blogdown::hugo_version(),'\n'))"

check_links:
	wget --spider -o wget.log -e robots=off -w 1 -r -p $(WEBSITE)/index.html
	grep -B 2 '404' wget.log

install:
	Rscript -e 'for (pkg in c("blogdown", "port4me")) if (!requireNamespace(pkg)) install.packages(pkgs)'
