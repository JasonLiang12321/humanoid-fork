ARG BASE_IMAGE=ghcr.io/watonomous/robot_base/base:humble-ubuntu22.04

################################ Source ################################
FROM ${BASE_IMAGE} AS source

WORKDIR ${AMENT_WS}/src

COPY autonomy/perception perception
COPY autonomy/wato_msgs/common_msgs wato_msgs/common_msgs
COPY autonomy/perception/perception/TrackNetV3-fork /opt/TrackNetV3

################################ Dependencies ################################
FROM ${BASE_IMAGE} AS dependencies

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git cmake ninja-build curl ca-certificates \
    python3 python3-pip python3-dev python3-setuptools \
    libgl1-mesa-glx libglib2.0-0 \
    libbz2-dev libreadline-dev libsqlite3-dev \
    libssl-dev zlib1g-dev libffi-dev liblzma-dev \
    libncursesw5-dev xz-utils tk-dev wget llvm \
    && rm -rf /var/lib/apt/lists/*

# ROS / GPU deps (keep your existing ones if needed)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-$ROS_DISTRO-librealsense2* \
    ros-$ROS_DISTRO-realsense2-camera* \
    && rm -rf /var/lib/apt/lists/*

################################ PYENV SETUP ################################
ENV PYENV_ROOT="/root/.pyenv"
ENV PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"

RUN curl https://pyenv.run | bash

# Install Python 3.8.7
RUN bash -lc "\
    export PYENV_ROOT=/root/.pyenv && \
    export PATH=$PYENV_ROOT/bin:$PATH && \
    eval \"\$(pyenv init -)\" || true && \
    pyenv install -s 3.8.7 && \
    pyenv global 3.8.7 && \
    python -V"

################################ TRACKNET VENV ################################

# Create isolated venv (IMPORTANT: NOT inside /opt mounted folder)
RUN bash -lc "\
    /root/.pyenv/versions/3.8.7/bin/python -m venv /root/tracknet_env && \
    /root/tracknet_env/bin/pip install --upgrade pip setuptools wheel"

# Install PyTorch CPU/GPU-safe fallback (edit if you need CUDA)
RUN /root/tracknet_env/bin/pip install \
    torch==1.10.0 torchvision==0.11.1 \
    -f https://download.pytorch.org/whl/torch_stable.html || true

# Install TrackNet requirements
RUN /root/tracknet_env/bin/pip install numpy opencv-python tqdm

COPY autonomy/perception/perception/TrackNetV3-fork /opt/TrackNetV3

RUN if [ -f /opt/TrackNetV3/requirements.txt ]; then \
        /root/tracknet_env/bin/pip install -r /opt/TrackNetV3/requirements.txt || true; \
    fi

################################ BUILD ################################
FROM dependencies AS build

COPY --from=source ${AMENT_WS}/src ${AMENT_WS}/src

WORKDIR ${AMENT_WS}

RUN . /opt/ros/$ROS_DISTRO/setup.sh && \
    colcon build \
    --cmake-args -DCMAKE_BUILD_TYPE=Release \
    --install-base ${WATONOMOUS_INSTALL}

################################ ENTRYPOINT ################################
COPY docker/wato_ros_entrypoint.sh ${AMENT_WS}/wato_ros_entrypoint.sh
ENTRYPOINT ["./wato_ros_entrypoint.sh"]