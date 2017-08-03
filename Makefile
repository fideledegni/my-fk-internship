texfigsources := $(shell find ./rawfigs/src/ -maxdepth 1 -name '*.tex')
vectorsources := $(shell find rawfigs/  -name '*.dia' -o -name '*.eps' -o -name '*.m' -o -name '*.pdf' -o -name '*.ps' -o -name '*.py' -o -name '*.svg' 2>/dev/null)
rastersources := $(shell find rawfigs/  -name '*.gif' 2>/dev/null)
readysources  := $(shell find rawfigs/  -name '*.jpg' -o -name '*.png' -o -name '*.pdf' -o -name '*mpg' -o -name '*.mpeg' 2>/dev/null)
texsource := $(wildcard abstract.tex main.tex paper.tex poster.tex proposal.tex report.tex talk.tex)

texfigs := $(shell echo ' ' $(texfigsources) ' ' | sed -e 's> \(./\)*raw> >g' -e 's/src\///g' -e 's/\.[^. ]* /.pdf /g')
vectorfigs := $(shell echo ' ' $(patsubst %_fm.eps,%.eps,$(vectorsources)) ' ' | sed -e 's> \(../common/\)*raw> >g' -e 's/\.[^. ]* /.pdf /g')
rasterfigs := $(shell echo ' ' $(rastersources) ' ' | sed -e 's> \(../common/\)*raw> >g' -e 's/\.[^. ]* /.jpg /g')
readyfigs := $(shell echo ' ' $(readysources) ' ' | sed -e 's> \(../common/\)*raw> >g')
figsources := $(vectorsources) $(rastersources) $(readysources)
figures := $(vectorfigs) $(rasterfigs) $(readyfigs) $(texfigs)
dirname  := $(shell basename $(shell pwd))

texfinal = compta.pdf
texroot = main

bibfiles := $(wildcard *.bib)
styfiles := $(wildcard *.sty ../common/*.sty)
clsfiles := $(wildcard *.cls ../common/*.cls)

alldeps := *.tex $(bibfiles) $(figures) $(figsources) $(clsfiles) $(styfiles)

BIBTEX     ?= bibtex
PDFLATEX   ?= pdflatex
LATEX      ?= latex
PYTHON     ?= python
OCTAVE     ?= octave
INKSCAPE   ?= inkscape
FRAGMASTER ?= fragmaster
XINDY      ?= xindy
MAKEINDEX  ?= makeindex

MYPDFLATEX   = TEXINPUTS=$(abspath ../common):$$TEXINPUTS $(PDFLATEX) -halt-on-error -interaction=nonstopmode
MYLATEX      = TEXINPUTS=$(abspath ../common):$$TEXINPUTS $(LATEX) -halt-on-error -interaction=nonstopmode
MYFRAGMASTER = TEXINPUTS=$(abspath ../common):$$TEXINPUTS $(FRAGMASTER)

.PHONY: all figures clean cleanlatex cleanfigs

all: $(texfinal)

texfigs: $(texfigs) cleantexfigs

cleantexfigs:
	@rm -f ./figs/*.{aux,bbl,blg,log,dvi,nav,out,snm,toc,vrb,lof,lot,gnuplot,table}

figures: $(figures)

continuous: all
	while true; do \
	  inotifywait -e close_write -e delete_self -e move $(alldeps) || break; \
          $(MAKE) all; \
        done

$(texfinal): $(alldeps)
	if ls *.bib 2>&1; then $(MYPDFLATEX) -draftmode $(call texroot,$@); fi
	if (ls *.bib 2>&1 && ls $(call texroot,$@).aux 2>&1); then $(BIBTEX) $(call texroot,$@); fi
	$(MYPDFLATEX) -draftmode $(call texroot,$@)
	if (ls *.xdy 2>&1 && ls $(call texroot,$@).aux 2>&1); then $(XINDY) -L french -C utf8 -I $(XINDY) -M $(call texroot,$@) -t $(call texroot,$@).glg -o $(call texroot,$@).gls $(call texroot,$@).glo; fi
	if (ls *.ist 2>&1 && ls $(call texroot,$@).aux 2>&1); then $(MAKEINDEX) -l -s $(call texroot,$@).ist -o $(call texroot,$@).gls $(call texroot,$@).glo; fi
	$(MYPDFLATEX) -draftmode $(call texroot,$@) && $(MYPDFLATEX) -draftmode $(call texroot,$@) && $(MYPDFLATEX) $(call texroot,$@)
	if [ "$@" != "$(call texroot,$@).pdf" ]; then mv "$(call texroot,$@).pdf" "$@"; fi

clean: cleanlatex cleanfigs

cleanlatex:
	rm -f $(patsubst %.tex, %.aux, $(wildcard *.tex))
	rm -f $(foreach ext,.bbl .blg .log .dvi .nav .nlo .out .pdf .snm .spl .toc .vrb .glo .ist .xdy .gls .glg .ilg,$(patsubst %.tex,%$(ext),$(texsource)))
	rm -f $(texfinal)

cleanfigs:
	rm -rf figs/

figs/%.pdf: rawfigs/%.dia
	@mkdir -p $(dir $@)
	dia -t eps-builtin -e $?_roytemp.eps $? && epstopdf $?_roytemp.eps -o=$@
	@rm -f $?_roytemp.eps

figs/%.pdf: rawfigs/%.eps
	@mkdir -p $(dir $@)
	epstopdf $? -o=$@ || (rm $@; exit 1)

figs/%.pdf: rawfigs/%_fm rawfigs/%_fm.eps  # fragmaster(1) with optional control file
	@mkdir -p $(dir $@)
	@(test -f rawfigs/fragmaster.dfm && (cd $(dir $@) && ln -sf -t . ../rawfigs/fragmaster.dfm) || true)
	@(cd $(dir $@) && ln -sf -t . $(addprefix ../,$+) && $(MYFRAGMASTER))

figs/%.pdf: rawfigs/%.m
	@mkdir -p $(dir $@)
	@cd $(dir $?) && $(OCTAVE) $(notdir $?)
	@(test -f $(dir $?)/$*.eps && (epstopdf $(dir $?)/$*.eps -o=$@; rm -f $(dir $?)/$*.eps) || true)
	@(test -f $(dir $?)/$*.pdf && mv $(dir $?)/$*.pdf $@ || true)

figs/%.pdf: rawfigs/%.py
	@mkdir -p $(dir $@)
	@cd $(dir $?) && $(PYTHON) $(notdir $?)
	@(test -f $(dir $?)/$*.eps && (epstopdf $(dir $?)/$*.eps -o=$@; rm -f $(dir $?)/$*.eps) || true)
	@(test -f $(dir $?)/$*.pdf && mv $(dir $?)/$*.pdf $@ || true)

figs/%.pdf: rawfigs/%.ps
	@mkdir -p $(dir $@)
	ps2pdf $? $@

figs/%.pdf: rawfigs/%.svg
	@mkdir -p $(dir $@)
	$(INKSCAPE) --file=$? --export-area-drawing -z --export-pdf=$@

figs/%.png: rawfigs/%.png
	@mkdir -p $(dir $@)
	@reldir=`echo $(dir $@) | sed -e 's>[^/]*/*>../>g'`; ln -sf $${reldir}$? $@

figs/%.jpg: rawfigs/%.gif
	@mkdir -p $(dir $@)
	convert $? $@

figs/%.mpeg: rawfigs/%.mpeg
	@mkdir -p $(dir $@)
	@reldir=`echo $(dir $@) | sed -e 's>[^/]*/*>../>g'`; ln -sf $${reldir}$? $@

figs/%.mpg: rawfigs/%.mpg
	@mkdir -p $(dir $@)
	@reldir=`echo $(dir $@) | sed -e 's>[^/]*/*>../>g'`; ln -sf $${reldir}$? $@

figs/%.pdf: rawfigs/%.pdf
	@mkdir -p $(dir $@)
	@reldir=`echo $(dir $@) | sed -e 's>[^/]*/*>../>g'`; ln -sf $${reldir}$? $@

figs/%.jpg: rawfigs/%.jpg
	@mkdir -p $(dir $@)
	@reldir=`echo $(dir $@) | sed -e 's>[^/]*/*>../>g'`; ln -sf $${reldir}$? $@

figs/%.pdf: rawfigs/src/%.tex
	@mkdir -p $(dir $@)
	lualatex -output-directory $(dir $@) -halt-on-error -shell-escape $? && lualatex -output-directory $(dir $@) -halt-on-error -shell-escape $?
	@rm -f $(shell find $(dir $@) -name '*.aux' -o -name '*.log')
