case "$OCAML_VERSION,$OPAM_VERSION" in
3.12.1,1.1.0) ppa=avsm/ocaml312+opam11 ;;
4.00.1,1.1.0) ppa=avsm/ocaml40+opam11 ;;
4.01.0,1.1.0) ppa=avsm/ocaml41+opam11 ;;
*) echo Unknown $OCAML_VERSION,$OPAM_VERSION; exit 1 ;;
esac

echo "yes" | sudo add-apt-repository ppa:$ppa
sudo apt-get update -qq
sudo apt-get install -qq ocaml ocaml-native-compilers camlp4-extra opam
sudo apt-get install blktap-dev # for libvhd.h
sudo apt-get install uuid-dev # missing dependency of blktap-dev
export OPAMYES=1
export OPAMVERBOSE=1

opam init git://github.com/ocaml/opam-repository >/dev/null 2>&1
opam remote add xapi-project git://github.com/xapi-project/opam-repo-dev
opam install xcp re rpc cmdliner cohttp vhdlib tapctl
eval `opam config env`
make
make test
