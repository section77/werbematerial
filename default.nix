{ pkgs ? import <nixpkgs> {}, public-url ? "/" }:
with builtins;
let

  inkscape-export = pkgs.writeScript "inkscape-export" ''
    TYPE=$1
    SRC=$2
    ARGS=$3

    BASENAME=$(basename "$SRC")
    NAME_WITHOUT_EXT="''${BASENAME%%.*}"
    DST="$(dirname "$SRC")/$NAME_WITHOUT_EXT.$TYPE"

    if ! [ -f "$DST" ]; then
      echo "generate $DST"
      inkscape --export-$TYPE="$DST" $ARGS "$SRC"
    else
      echo "$DST exists - skipping"
    fi
  '';

  svgToPDF = pkgs.writeScript "svg-to-pdf" ''
    ${inkscape-export} "pdf" "$1"
  '';

  svgToPNG = pkgs.writeScript "svg-to-png" ''
    ${inkscape-export} "png" "$1" "--export-dpi=300"
  '';

  pdfToPNG = pkgs.writeScript "pdf-to-png" ''
    SRC=$1

    BASENAME=$(basename "$SRC")
    NAME_WITHOUT_EXT="''${BASENAME%%.*}"
    DST="$(dirname "$SRC")/$NAME_WITHOUT_EXT.png"

    if ! [ -f "$DST" ]; then
      echo "generate $DST"
      convert -density 300 "$SRC" -append "$DST"
    else
      echo "$DST exists - skipping"
    fi
  '';


  createPreviewImage = pkgs.writeScript "create-preview-image" ''
    SRC=$1

    NAME=$(basename "$SRC")
    DST="$(dirname "$SRC")/gh-pages-preview-$NAME"

    convert -resize 300 "$SRC" "$DST"
  '';

  #werbematerial-gh-pages = import ../werbematerial-gh-pages {};
  werbematerial-gh-pages = import (pkgs.fetchFromGitHub {
    owner = "section77";
    repo = "werbematerial-gh-pages";
    rev = "cc471b5d0d25b7b709125d4b49cbe9426f8b1d73";
    sha256 = "0af8s4q2ir9ggd03hjf303vc36nr6312bdjbkpk1n08iw224352y";
    }) { inherit public-url; };

in pkgs.stdenv.mkDerivation rec {
  src = pkgs.lib.cleanSource ./.;
  name = "werbematerial";

  buildInputs = with pkgs; [
    inkscape imagemagick ghostscript nodejs rsync
  ];

  buildPhase = ''
    export HOME=$TEMP

    find -name '*.svg' -exec ${svgToPDF} {} \;
    find -name '*.svg' -exec ${svgToPNG} {} \;
    find -name '*.pdf' -exec ${pdfToPNG} {} \;

    find -iregex '.*\(png\|jpg\|jpeg\|bmp\)$' -exec ${createPreviewImage} {} \;
  '';

  installPhase = ''
    mkdir -p $out

    rsync --times -r --exclude=default.nix --exclude=README.org --exclude=.travis.yml --exclude=.gitignore . $out

    node ${werbematerial-gh-pages.indexer}/indexer.js $out $out

    cp -va ${werbematerial-gh-pages.webapp}/* $out
  '';

}
