.PHONY : build install

build :
	dub build -b release --parallel --compiler=ldc2

./ath :
	$(MAKE) build

install : ./ath
	mkdir -p /usr/local/bin
	cp -v ./ath /usr/local/bin
