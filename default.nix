with builtins;
let

  pkgs = import <nixpkgs> { };

  inkscape-export = pkgs.writeScript "inkscape-export" ''

    TYPE=$1
    SRC=$2
    ARGS=$3

    BASENAME=$(basename $SRC)
    NAME_WITHOUT_EXT="''${BASENAME%%.*}"
    DST="$(dirname $SRC)/$NAME_WITHOUT_EXT.$TYPE"

    if ! [ -f "$DST" ]; then
      echo "generate $DST"
      inkscape --export-$TYPE=$DST $ARGS $SRC
    else
      echo "$DST exists - skipping"
    fi
  '';

  svgToPDF = pkgs.writeScript "svg-to-pdf" ''
    ${inkscape-export} "pdf" $1
  '';

  svgToPNG = pkgs.writeScript "svg-to-png" ''
    ${inkscape-export} "png" $1 "--export-dpi=300"
  '';

  pdfToPNG = pkgs.writeScript "pdf-to-png" ''
    SRC=$1

    BASENAME=$(basename $SRC)
    NAME_WITHOUT_EXT="''${BASENAME%%.*}"
    DST="$(dirname $SRC)/$NAME_WITHOUT_EXT.png"

    if ! [ -f "$DST" ]; then
      echo "generate $DST"
      convert -density 300 $SRC $DST
    else
      echo "$DST exists - skipping"
    fi
  '';


  createPreviewImage = pkgs.writeScript "create-preview-image" ''
    SRC=$1

    NAME=$(basename $SRC)
    DST="$(dirname $SRC)/gh-pages-preview-$NAME"

    convert -resize 300 $SRC $DST
  '';

  werbematerial-gh-pages = import (pkgs.fetchFromGitHub {
    owner = "section77";
    repo = "werbematerial-gh-pages";
    rev = "92860c164602e665b784f56b1cffdf42551ef5d0";
    sha256 = "0clglspq2dazld9mxswld9jxwq9fa69wx547vzpm00bxak67bw6w";
    }) { inherit pkgs; public-url = "/werbematerial"; };

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

    rsync -r --exclude=default.nix --exclude=.gitignore . $out

    node ${werbematerial-gh-pages.indexer}/indexer.js $out $out

    cp -va ${werbematerial-gh-pages.webapp}/* $out
  '';

}
