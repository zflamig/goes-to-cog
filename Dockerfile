FROM public.ecr.aws/lambda/python:3.8

# Basic utils for downloading and decompressing
RUN yum install -y \
    bzip2 \
    gzip \
    sqlite-devel \
    libcurl-devel \
    zlib-devel \
    libdeflate-devel \
    libtiff \
    libtiff-devel \
    sqlite \
    tar \
    wget \
    && yum clean all \
    && rm -rf /var/cache/yum

# Required to compile geos libraries
# Maybe just make, gcc, and autoconf?
RUN yum groupinstall -y "Development Tools" \
    && yum clean all \
    && rm -rf /var/cache/yum

RUN pip install numpy

# szip
RUN cd /tmp \
	&& wget https://support.hdfgroup.org/ftp/lib-external/szip/2.1.1/src/szip-2.1.1.tar.gz \
        && tar xf szip-2.1.1.tar.gz \
        && cd szip-2.1.1 \
        && ./configure --prefix=/usr \
        && make -j8 \
        && make install \
        && cd .. \
        && rm -rf szip-2.1.1 szip-2.1.1.tar.gz

# HDF5 Installation
RUN cd /tmp \
	&& wget https://hdf-wordpress-1.s3.amazonaws.com/wp-content/uploads/manual/HDF5/HDF5_1_12_0/source/hdf5-1.12.0.tar.gz \
        && tar xf hdf5-1.12.0.tar.gz \
        && cd hdf5-1.12.0 \
        && ./configure --prefix=/usr --enable-cxx --with-zlib=/usr/include,/usr/lib/x86_64-linux-gnu \
        && make -j8 \
        && make install \
        && cd .. \
        && rm -rf hdf5-1.12.0 \
        && rm -rf hdf5-1.12.0.tar.gz \
	&& export HDF5_DIR=/usr

# NetCDF Installation
RUN cd /tmp \
	&& wget https://github.com/Unidata/netcdf-c/archive/v4.7.4.tar.gz \
        && tar xf v4.7.4.tar.gz \
        && cd netcdf-c-4.7.4 \
        && ./configure --prefix=/usr \
        && make -j8 \
        && make install \
        && cd .. \
        && rm -rf netcdf-c-4.7.4 \
        && rm -rf v4.7.4.tar.gz

# Install GEOS
RUN cd /tmp \
    && wget http://download.osgeo.org/geos/geos-3.9.1.tar.bz2 \
    && tar xf geos-3.9.1.tar.bz2 \
    && cd geos-3.9.1 \
    && ./configure --prefix=/usr \
    && make -j4 \
    && make install \
    && /sbin/ldconfig \
    && cd .. \
    && rm -rf geos-3.9.1 \
    && rm -rf geos-3.9.1.tar.bz2

# Install Proj
RUN cd /tmp \
    && wget http://download.osgeo.org/proj/proj-7.2.0.tar.gz \
    && tar xf proj-7.2.0.tar.gz \
    && cd proj-7.2.0 \	
    && ./configure --prefix=/usr SQLITE3_CFLAGS=-I/usr/include SQLITE3_LIBS="-L/usr/lib -lsqlite3" TIFF_LIBS="-L/usr/lib64 -ltiff" --without-curl \
    && make -j4 \
    && make install \
    && cd .. \
    && rm -rf proj-7.2.0 proj-7.2.0.tar.gz

# libgeotiff
RUN cd /tmp \
	&& wget http://download.osgeo.org/geotiff/libgeotiff/libgeotiff-1.6.0.tar.gz \
	&& tar xf libgeotiff-1.6.0.tar.gz \
	&& cd libgeotiff-1.6.0 \
	&& ./configure --prefix=/usr --with-zlib=/usr/include,/usr/lib/x86_64-linux-gnu \
        && make -j8 \
        && make install \
        && cd .. \
        && rm -rf libgeotiff-1.6.0.tar.gz libgeotiff-1.6.0

# GDAL
RUN cd /tmp \
	&& wget https://github.com/OSGeo/gdal/releases/download/v3.2.0/gdal-3.2.0.tar.gz \
        && tar xf gdal-3.2.0.tar.gz \
        && ls -al \
        && cd gdal-3.2.0 \
        && ./configure --prefix=/usr --with-python --with-curl \
        && make -j8 \
        && make install \
        && cd swig/python \
	&& python setup.py install \
        && cd ../../.. \
        && rm -rf gdal-3.2.0.tar.gz gdal-3.2.0

RUN /sbin/ldconfig

COPY lambda.py ./

CMD [ "lambda.lambdaHandler" ]
