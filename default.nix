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
    rev = "d89bcb8e364c2390acb2ebfa215514e328d5ec93";
    sha256 = "0zymdnhilaz5pc9brr2bjf42wv4821k2r08k6yl0m3966py1jwma";
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
