FROM ubuntu:18.04 as base
# set non-interactive frontend
ENV DEBIAN_FRONTEND=noninteractive
# set working directory to /opt
WORKDIR /opt
# install dependencies
RUN apt-get update && apt-get install -y build-essential gpg wget m4 libglu1-mesa libncursesw5-dev libgdbm-dev \
    gfortran python python-pip libz-dev libreadline-dev libbz2-dev libopenblas-dev liblapack-dev libhdf5-dev \
    libfftw3-dev git graphviz patchelf libssl-dev libsqlite3-dev uuid-dev git-lfs curl bc dc libgl1-mesa-dev \
    unzip libgomp1 libxmu6 libxt6 tcsh libffi-dev lzma-dev liblzma-dev tk-dev libdb-dev && \
    # install cmake
    wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null \
    | gpg --dearmor - | tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null && \
    echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ bionic main' \
    | tee /etc/apt/sources.list.d/kitware.list >/dev/null && \
    apt-get update && rm /usr/share/keyrings/kitware-archive-keyring.gpg && \
    apt-get install -y kitware-archive-keyring cmake && \
    # install python3.10
    curl -O https://www.python.org/ftp/python/3.10.16/Python-3.10.16.tgz && tar xvf Python-3.10.16.tgz && \
    rm Python-3.10.16.tgz && cd Python-3.10.16 && ./configure --enable-optimizations && make altinstall && \
    cd .. && rm -rf Python-3.10.16

# Make perl version 5.20.3
RUN echo "Downloading perl ..." && \
    curl -sSL --retry 5 http://www.cpan.org/src/5.0/perl-5.20.3.tar.gz | tar zx -C /opt && \
    mkdir -p /opt/perl && cd /opt/perl-5.20.3 && ./Configure -des -Dprefix=/opt/perl && make && make install
######################################################################################################################


# copy dependencies from other images
RUN mkdir -p /opt/ANTs
COPY --from=dcanumn/external-software-nhp-synth:v1.0.0 /opt /opt

# install freesurfer
# Make libnetcdf
RUN echo "Downloading libnetcdf ..." && \
    curl -sSL --retry 5 https://github.com/Unidata/netcdf-c/archive/v4.6.1.tar.gz | tar zx -C /opt && \
    cd /opt/netcdf-c-4.6.1/ && \
    LDFLAGS=-L/usr/local/lib && CPPFLAGS=-I/usr/local/include && ./configure --disable-netcdf-4 --disable-dap \
    --enable-shared --prefix=/usr/local && \
    make && make install && \
    rm -rf /opt/netcdf-c-4.6.1/ && ldconfig

# Install FreeSurfer v5.3.0-HCP
RUN echo "Downloading FreeSurfer ..." && \
    curl -sSL --retry 5 https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/5.3.0-HCP/freesurfer-Linux-centos6_x86_64-stable-pub-v5.3.0-HCP.tar.gz \
    | tar xz -C /opt \
    --exclude='freesurfer/average/mult-comp-cor' \
    --exclude='freesurfer/lib/cuda' \
    --exclude='freesurfer/lib/qt' \
    --exclude='freesurfer/subjects/V1_average' \
    --exclude='freesurfer/subjects/bert' \
    --exclude='freesurfer/subjects/cvs_avg35' \
    --exclude='freesurfer/subjects/cvs_avg35_inMNI152' \
    --exclude='freesurfer/subjects/fsaverage3' \
    --exclude='freesurfer/subjects/fsaverage4' \
    --exclude='freesurfer/subjects/fsaverage5' \
    --exclude='freesurfer/subjects/fsaverage6' \
    --exclude='freesurfer/subjects/fsaverage_sym' \
    --exclude='freesurfer/trctrain'

# install afni
RUN echo "Downloading AFNI ..." && \
    mkdir -p /opt/afni && cd /opt/afni && \
    curl -O https://afni.nimh.nih.gov/pub/dist/tgz/linux_ubuntu_16_64.tgz && \
    tar xvf linux_ubuntu_16_64.tgz && rm linux_ubuntu_16_64.tgz

# install connectome workbench
RUN echo "Downloading Connectome Workbench" && \
    curl -O https://www.humanconnectome.org/storage/app/media/workbench/workbench-linux64-v1.5.0.zip && \
    unzip workbench-linux64-v1.5.0.zip && rm workbench-linux64-v1.5.0.zip

# install convert3d
RUN echo "Downloading Convert3d ..." && \
    mkdir /opt/c3d && \
    curl -sSL --retry 5 https://sourceforge.net/projects/c3d/files/c3d/1.0.0/c3d-1.0.0-Linux-x86_64.tar.gz/download \
    | tar -xzC /opt/c3d --strip-components=1

# Install MSM Binaries
RUN echo "Downloading msm ..." && \
    mkdir /opt/msm && \
    curl -ksSL --retry 5 https://www.doc.ic.ac.uk/~ecr05/MSM_HOCR_v2/MSM_HOCR_v2-download.tgz | tar zx -C /opt && \
    mv /opt/homes/ecr05/MSM_HOCR_v2/* /opt/msm/ && \
    rm -rf /opt/homes /opt/msm/MacOSX /opt/msm/Centos

# DCAN tools
RUN mkdir /opt/dcan-tools && cd /opt/dcan-tools && \
    # dcan executive summary
    git clone -b v2.2.10 --single-branch --depth 1 https://github.com/DCAN-Labs/ExecutiveSummary.git executivesummary && \
    gunzip /opt/dcan-tools/executivesummary/templates/parasagittal_Tx_169_template.scene.gz && \
    # dcan custom clean
    git clone -b v2.0.3 --single-branch --depth 1 https://github.com/DCAN-Labs/CustomClean.git customclean && \
    # dcan file mapper
    git clone -b v1.3.0 --single-branch --depth 1 https://github.com/DCAN-Labs/file-mapper.git filemapper && \
    printf "{\n  \"VERSION\": \"development\"\n}\n" > /opt/dcan-tools/version.json
# dcan bold processing
COPY ["scripts/dcan_bold_processing", "/opt/dcan-tools/dcan_bold_proc"]

# alias python3.10 to python3
RUN ln -s /usr/local/bin/python3.10 /usr/bin/python3

# install python2 stuff
RUN pip2 install pyyaml numpy pillow

# adjust libnetcdf copy so that it is a symlink and patch mris_make_surfaces to use a non-specific version of netcdf
RUN rm -rf /usr/local/lib/libnetcdf.so.13 && ln -s /usr/local/lib/libnetcdf.so /usr/local/lib/libnetcdf.so.13 && \
    patchelf --replace-needed libnetcdf.so.6 libnetcdf.so.13 /opt/freesurfer/bin/mris_make_surfaces && ldconfig

# set perl to to /opt version
RUN rm /usr/bin/perl && ln -s /opt/perl/bin/perl /usr/bin/perl

# Set Connectome Workbench Binary Directory
RUN ln -s /opt/workbench/bin_linux64/wb_command /opt/workbench/wb_command && \
    mkdir -p /root/.config/brainvis.wustl.edu /.config/brainvis.wustl.edu /opt/workbench/brainvis.wustl.edu && \
    printf "[General]\nloggingLevel=INFO\nvolumeAxesCrosshairs=false\nvolumeAxesLabels=false\n" > \
    /opt/workbench/brainvis.wustl.edu/Caret7.conf && \
    printf "[General]\nloggingLevel=INFO\nvolumeAxesCrosshairs=false\nvolumeAxesLabels=false\n" > \
    /root/.config/brainvis.wustl.edu/Caret7.conf && \
    printf "[General]\nloggingLevel=INFO\nvolumeAxesCrosshairs=false\nvolumeAxesLabels=false\n" > \
    /.config/brainvis.wustl.edu/Caret7.conf && \
    chmod -R 775 /root/.config /.config

# setup environment variables
ENV ANTSPATH=/opt/ANTs/bin PATH=${PATH}:/opt/ANTs/bin
ENV FSLDIR=/opt/fsl PATH=${PATH}:/opt/fsl/bin
ENV PATH=${PATH}:/opt/afni/linux_ubuntu_16_64
ENV PATH=${PATH}:/opt/workbench/bin_linux64
ENV WORKBENCHDIR=/opt/workbench \
    CARET7DIR=/opt/workbench/bin_linux64 \
    CARET7CONFDIR=/opt/workbench/brainvis.wustl.edu
ENV C3DPATH=/opt/c3d/bin PATH=/opt/c3d/bin:$PATH
# FreeSurfer uses matlab and tries to write the startup.m to the HOME dir.
# Therefore, HOME needs to be a writable dir.
ENV FREESURFER_HOME=/opt/freesurfer HOME=/opt SUBJECTS_DIR=/opt/freesurfer/subjects
ENV MSMBINDIR=/opt/msm/Ubuntu
ENV OMP_NUM_THREADS=8 SCRATCHDIR=/tmp/scratch ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=8 TMPDIR=/tmp

# Fix libstdc++6 error
RUN ln -sf /usr/lib/x86_64-linux-gnu/libstdc++.so.6.0.25 /opt/mcr/v96/sys/os/glnxa64/libstdc++.so.6

# install omni
RUN python3.10 -m pip install -vvv omnineuro==2022.8.1

# copy DCAN pipeline
COPY ["scripts/dcan_macaque_pipeline", "/opt/pipeline"]

# copy over repo (without root scripts dir)
RUN mkdir -p /opt/nhp-abcd-bids-pipeline
COPY ["nhp_abcd", "/opt/nhp-abcd-bids-pipeline/nhp_abcd"]
COPY ["pyproject.toml", "README.md", "LICENSE", "MANIFEST.in", \
    "setup.cfg", "setup.py", "requirements.txt", "/opt/nhp-abcd-bids-pipeline/"]

# install this repo
RUN cd /opt/nhp-abcd-bids-pipeline && \
    python3.10 -m pip install -vvv .

# make some directories
RUN mkdir /bids_input /output /atlases

# setup ENTRYPOINT
COPY ["scripts/entrypoint.sh", "/entrypoint.sh"]
COPY ["scripts/SetupEnv.sh", "/SetupEnv.sh"]
ENTRYPOINT ["/entrypoint.sh"]
WORKDIR /
CMD ["--help"]
