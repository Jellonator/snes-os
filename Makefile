OBJDIR   := obj
BINDIR   := bin
SRCDIR   := src
BINFILE  := snes-os.sfc
AC       := wla-65816
ALINK    := wlalink
AFLAGS   := -I include
ALDFLAGS := -S -v
PY       := python3

SOURCES  := fs/core.asm\
			fs/data.asm\
			fs/mem.asm\
			fs/path.asm\
			lib/lib.asm\
			shell/cat.asm\
			shell/cp.asm\
			shell/echo.asm\
			shell/mkdir.asm\
			shell/ps.asm\
			shell/rm.asm\
			shell/shell.asm\
			shell/touch.asm\
			system/init.asm\
			system/main.asm\
			system/memlayout.asm\
			system/memory.asm\
			system/printer.asm\
			system/process.asm\
			system/queue.asm\
			system/render.asm\
			system/sem.asm\
			test/prodcons.asm\
			test/test.asm

OBJECTS  := $(SOURCES:%.asm=$(OBJDIR)/%.obj)
PALETTES := $(wildcard assets/palettes/*.hex)
SPRITES  := $(wildcard assets/sprites/*.raw)
INCLUDES := $(wildcard ./include/*.inc) include/assets.inc include/staticdata.inc

Test.smc: Test.link $(OBJECTS)
	mkdir -p $(BINDIR)
	$(ALINK) $(ALDFLAGS) Test.link $(BINDIR)/$(BINFILE)

include/assets.inc: $(PALETTES) $(SPRITES) assets/palettes.json assets/sprites.json
	echo MAKING ASSET INC
	mkdir -p include/palettes/
	mkdir -p include/sprites/
	$(PY) scripts/assetimport.py

include/staticdata.inc: $(shell ls static/**/*)
	echo MAKING STATIC INC
	$(PY) scripts/staticfileimport.py

$(OBJDIR)/%.obj: $(SRCDIR)/%.asm $(INCLUDES)
	mkdir -p $(dir $@)
	$(AC) $(AFLAGS) -o $@ $<

.PHONY: clean
clean:
	rm -rf $(OBJDIR)
	rm -rf $(BINDIR)
	rm -rf include/palettes/
	rm -rf include/sprites/
	rm include/assets.inc
