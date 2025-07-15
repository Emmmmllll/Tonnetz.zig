{
  pkgs ? import <nixpkgs> { },
}:

pkgs.mkShell {
  packages = with pkgs; with xorg; [
    wayland-protocols
    wayland
    wayland-scanner
    pkg-config
    libGL
    libX11
    libXcursor
    libXext
    libXfixes
    libXi
    libXinerama
    libXrandr
    libXrender
    libxkbcommon
    libpulseaudio
  ];
}