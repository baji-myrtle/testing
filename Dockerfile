# Copyright (c) 2019-2020, NVIDIA CORPORATION. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ARG FROM_IMAGE_NAME=nvcr.io/nvidia/pytorch:23.03-py3
FROM ${FROM_IMAGE_NAME}

# pytorch version taken from here:
# https://docs.nvidia.com/deeplearning/frameworks/pytorch-release-notes/rel-23-03.html#rel-23-03
ENV PYTORCH_VERSION=2.0.0a0+1767026

# Added by rob@myrtle May 2022 to fix NVIDIA key rotation problem.
# See https://forums.developer.nvidia.com/t/notice-cuda-linux-repository-key-rotation/212771 for details.
RUN apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub

# need to set the tzdata time noninteractively
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata && \
    apt-get install -y libsndfile1 sox git cmake jq ffmpeg && \
    apt-get install -y --no-install-recommends numactl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace/rnnt

# Install libosmocore, a gapk dependency
RUN apt-get update && \
    apt-get install -y \
        autoconf \
        automake \
        build-essential \
        gcc \
        git-core \
        gnutls-dev \
        libmnl-dev \
        libpcsclite-dev \
        libsctp-dev \
        libtalloc-dev \
        libtool \
        libusb-1.0.0-dev \
        make \
        pkg-config \
        python2-minimal \
        shtool && \
    git clone https://gitea.osmocom.org/osmocom/libosmocore.git deps/libosmocore && \
    cd deps/libosmocore && \
    git checkout 19bd12e919ed5b87fa733ce860473aa6783bab6d && \
    autoreconf -i && \
    ./configure && \
    make && \
    make install && \
    ldconfig -i && \
    cd ../..


# Install gapk
RUN apt-get update && \
    apt-get install -y \
        libasound2-dev \
        libgsm1-dev \
        libopencore-amrnb-dev \
        python2.7 && \
    git clone https://gitea.osmocom.org/osmocom/gapk deps/gapk && \
    cd deps/gapk && \
    git checkout a2bd862707eba25233eba3b287266aa893995179 && \
    sed -i "s/python/python2/" libgsmhr/fetch_sources.py && \
    autoreconf -i && \
    ./configure --enable-gsmhr && \
    make && \
    make install && \
    ldconfig && \
    cd ../..

# Install ffmpeg with support for AMR
RUN apt-get update && \
    mkdir -p ~/ffmpeg_sources ~/bin && \
    apt-get install -y \
        autoconf \
        automake \
        build-essential \
        cmake \
        git-core \
        gnutls-bin \
        libao-dev \
        libass-dev \
        libfdk-aac-dev \
        libflac-dev \
        libfreetype6-dev \
        libgnutls28-dev \
        libid3tag0-dev \
        libltdl-dev \
        libmad0-dev \
        libmp3lame-dev \
        libnuma-dev \
        libopencore-amrnb-dev \
        libopencore-amrwb-dev \
        libopus-dev \
        libpng-dev \
        libsdl2-dev \
        libsndfile1-dev \
        libtool \
        libtwolame-dev \
        libunistring-dev \
        libva-dev \
        libvdpau-dev \
        libvo-amrwbenc-dev \
        libvorbis-dev \
        libvpx-dev \
        libwavpack-dev \
        libx264-dev \
        libx265-dev \
        libxcb-shm0-dev \
        libxcb-xfixes0-dev \
        libxcb1-dev \
        meson \
        nasm \
        ninja-build \
        pkg-config \
        texinfo \
        wget \
        yasm \
        zlib1g-dev && \
    cd ~/ffmpeg_sources && \
    git clone https://github.com/FFmpeg/FFmpeg.git ffmpeg && \
    cd ffmpeg && \
    git checkout 2f428de9ebdcd0770de37d874871b25325aebd73 && \
    PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure \
        --bindir="$HOME/bin" \
        --enable-gnutls \
        --enable-gpl \
        --enable-libass \
        --enable-libfdk-aac \
        --enable-libfreetype \
        --enable-libmp3lame \
        --enable-libopencore-amrnb \
        --enable-libopencore-amrwb \
        --enable-libopus \
        --enable-libvo-amrwbenc \
        --enable-libvorbis \
        --enable-libvpx \
        --enable-libx264 \
        --enable-libx265 \
        --enable-nonfree \
        --enable-version3 \
        --extra-cflags="-I$HOME/ffmpeg_build/include" \
        --extra-ldflags="-L$HOME/ffmpeg_build/lib" \
        --extra-libs="-lpthread -lm" \
        --ld="g++" \
        --pkg-config-flags="--static" \
        --prefix="$HOME/ffmpeg_build" && \
    PATH="$HOME/bin:$PATH" make && \
    make install && \
    hash -r && \
    cd /workspace/rnnt

# Upgrade git
# An upgraded git is needed to only download Earnings22 transcripts
# in make_hugging_face.py. Else we have to download
# 7 GB of Earnings21 audio as well
RUN apt-get update && \
    apt-get install software-properties-common -y && \
    add-apt-repository ppa:git-core/ppa -y && \
    apt-get update && \
    apt-get install git -y

# Install the latest (beta) version of package torchdata before development paused:
# https://github.com/pytorch/data/issues/1196
# This may change when new torchdata releases are available
RUN pip install --no-dependencies torchdata==0.6.1

COPY requirements.txt .
RUN pip install --no-cache --disable-pip-version-check -U -r requirements.txt

COPY . .
RUN python -m pip install -e .
