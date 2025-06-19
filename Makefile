preview:
	quarto preview

render:
	quarto render --output-dir=docs

publish: render
	git commit -am "refresh"
	git push
