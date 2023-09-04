{ lib
, stdenv
, symlinkJoin
, makeWrapper
, wrapQtAppsHook
, addOpenGLRunpath

, prismlauncher-unwrapped

, qtbase  # needed for wrapQtAppsHook
, qtsvg
, qtwayland
, xorg
, libpulseaudio
, libGL
, glfw
, glfw-wayland-minecraft
, openal
, jdk8
, jdk17
, gamemode
, flite
, mesa-demos
, udev
, libusb1

, msaClientID ? null
, gamemodeSupport ? stdenv.isLinux
, textToSpeechSupport ? stdenv.isLinux
, controllerSupport ? stdenv.isLinux
, withWaylandGLFW ? false
, shellWrapper ? withWaylandGLFW

, jdks ? [ jdk17 jdk8 ]
, additionalLibs ? [ ]
, additionalPrograms ? [ ]
}:

assert lib.assertMsg (withWaylandGLFW -> stdenv.isLinux) "withWaylandGLFW is only available on Linux";
assert lib.assertMsg (withWaylandGLFW -> shellWrapper) "withWaylandGLFW requires shellWrapper";

let
  prismlauncherFinal = prismlauncher-unwrapped.override {
    inherit msaClientID gamemodeSupport;
  };
in
symlinkJoin {
  name = "prismlauncher-${prismlauncherFinal.version}";

  paths = [ prismlauncherFinal ];

  nativeBuildInputs = [
    wrapQtAppsHook
  ]
  ++ lib.optional shellWrapper makeWrapper;

  buildInputs = [
    qtbase
    qtsvg
  ]
  ++ lib.optional (lib.versionAtLeast qtbase.version "6" && stdenv.isLinux) qtwayland;

  waylandPreExec = ''
    if [ -n "$WAYLAND_DISPLAY" ]; then
      export LD_LIBRARY_PATH=${lib.getLib glfw-wayland-minecraft}/lib:"$LD_LIBRARY_PATH"
    fi
  '';

  postBuild = ''
    ${lib.optionalString withWaylandGLFW ''
      qtWrapperArgs+=(--run "$waylandPreExec")
    ''}

    wrapQtAppsHook
  '';

  qtWrapperArgs =
    let
      runtimeLibs = [
        xorg.libX11
        xorg.libXext
        xorg.libXcursor
        xorg.libXrandr
        xorg.libXxf86vm

        # lwjgl
        libpulseaudio
        libGL
        glfw
        openal
        stdenv.cc.cc.lib

        # oshi
        udev
      ]
      ++ lib.optional gamemodeSupport gamemode.lib
      ++ lib.optional textToSpeechSupport flite
      ++ lib.optional controllerSupport libusb1
      ++ additionalLibs;

      runtimePrograms = [
        xorg.xrandr
        mesa-demos # need glxinfo
      ]
      ++ additionalPrograms;

    in
    [ "--prefix PRISMLAUNCHER_JAVA_PATHS : ${lib.makeSearchPath "bin/java" jdks}" ]
    ++ lib.optionals stdenv.isLinux [
      "--set LD_LIBRARY_PATH ${addOpenGLRunpath.driverLink}/lib:${lib.makeLibraryPath runtimeLibs}"
      # xorg.xrandr needed for LWJGL [2.9.2, 3) https://github.com/LWJGL/lwjgl/issues/128
      "--prefix PATH : ${lib.makeBinPath runtimePrograms}"
    ];

  inherit (prismlauncherFinal) meta;
}
