preview:
	quarto preview

render:
	quarto render --output-dir=docs

deploy: render
	git commit -am "refresh"
	git push
