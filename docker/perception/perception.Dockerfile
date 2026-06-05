ARG BASE_IMAGE=ghcr.io/watonomous/robot_base/base:humble-ubuntu22.04

################################ SOURCE ################################
FROM ${BASE_IMAGE} AS source

WORKDIR ${AMENT_WS}/src

COPY autonomy/perception perception
COPY autonomy/wato_msgs/common_msgs wato_msgs/common_msgs
COPY autonomy/perception/perception/TrackNetV3-fork /opt/TrackNetV3

################################ DEPENDENCIES ################################
FROM ${BASE_IMAGE} AS dependencies

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git cmake ninja-build curl ca-certificates \
    python3 python3-pip python3-dev python3-setuptools \
    python3.8 python3.8-venv python3.8-dev \
    libgl1-mesa-glx libglib2.0-0 \
    libbz2-dev libreadline-dev libsqlite3-dev \
    libssl-dev zlib1g-dev libffi-dev liblzma-dev \
    libncursesw5-dev xz-utils tk-dev wget llvm \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-$ROS_DISTRO-librealsense2* \
    ros-$ROS_DISTRO-realsense2-camera* \
    && rm -rf /var/lib/apt/lists/*

################################ ROS PYTHON FIXES ################################
RUN python3 -m pip install --upgrade pip
RUN python3 -m pip install empy==3.3.4

################################ TRACKNET VENV (CLEAN) ################################

# Create isolated Python 3.8 environment
RUN python3.8 -m venv /opt/tracknet_env

RUN /opt/tracknet_env/bin/pip install --upgrade pip setuptools wheel

# PyTorch (IMPORTANT: adjust CUDA if needed)
RUN /opt/tracknet_env/bin/pip install \
    torch==1.10.0 torchvision==0.11.1 \
    -f https://download.pytorch.org/whl/torch_stable.html || true

# Base ML deps
RUN /opt/tracknet_env/bin/pip install \
    numpy==1.24.4 opencv-python tqdm

################################ TRACKNET INSTALL ################################
COPY autonomy/perception/perception/TrackNetV3-fork /opt/TrackNetV3

RUN if [ -f /opt/TrackNetV3/requirements.txt ]; then \
        /opt/tracknet_env/bin/pip install -r /opt/TrackNetV3/requirements.txt || true; \
    fi

################################ BUILD ################################
FROM dependencies AS build

COPY --from=source ${AMENT_WS}/src ${AMENT_WS}/src

WORKDIR ${AMENT_WS}

# Ensure ROS uses system python ONLY
ENV PYTHONPATH=/usr/lib/python3/dist-packages
ENV PATH=/usr/bin:$PATH

RUN . /opt/ros/$ROS_DISTRO/setup.sh && \
    colcon build \
    --cmake-args -DCMAKE_BUILD_TYPE=Release \
    --install-base ${WATONOMOUS_INSTALL}

################################ ENTRYPOINT ################################
COPY docker/wato_ros_entrypoint.sh ${AMENT_WS}/wato_ros_entrypoint.sh
ENTRYPOINT ["./wato_ros_entrypoint.sh"]