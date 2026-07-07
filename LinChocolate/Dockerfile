# LinChocolate dev/test container — Ring 1 inner loop (Docs/LinChocolatePlan.md).
#
# Swift + GTK4 on Ubuntu. The image arch follows the host: on an Apple Silicon
# Mac this builds arm64/aarch64, which matches the Raspberry Pi — the fast loop
# and the primary hardware target share an ISA.
#
# Pinned toolchain (plan L2.1). Override with --build-arg SWIFT_TAG=... .
ARG SWIFT_TAG=6.0-noble
FROM swift:${SWIFT_TAG}

# GTK4 + pkg-config back the CGTK system-library target. The X11 client libs
# let windows render to XQuartz over the network X11 socket.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgtk-4-dev \
        pkg-config \
        libx11-6 \
        dbus-x11 \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# GTK4's GL/Vulkan renderer is unreliable over XQuartz's indirect GL, so the
# Ring 1 loop defaults to the Cairo software renderer and disables the GL probe
# (which otherwise spams libEGL/glx warnings). Real GL/Vulkan is exercised on
# Rings 2-3 (VMs, Pi). Both are overridable at run time.
ENV GSK_RENDERER=cairo
ENV GDK_DISABLE=gl
# No accessibility bus in the container; silence the a11y-bus probe warning.
ENV GTK_A11Y=none

WORKDIR /work

# Source is bind-mounted at run time (see run-linux.sh) for a fast edit loop,
# so no COPY here. Default to a shell for interactive use.
CMD ["bash"]
