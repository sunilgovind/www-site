# Dockerfile to build the www-site with Pelican.
# Inspired from https://github.com/boonto/docker-pelican
# (which is MIT licensed) for the Pelican-specific bits.
#
# To use this, build the container image with
#
#     docker build -t www-site .
#
# And run with
#
#   docker run -it -p8000:8000 -v $PWD:/site -v $PWD/site-generated/:/site-generated www-site
#
# from a folder that contains your pelicanconf.py file and ./content folder.
#
# That should build the site, make it available at http://localhost:8000 and rebuild
# if you make changes to the content.
#
# To run a different command you can override the entrypoint, like for example:
#
#    docker run -it -p8000:8000 -v $PWD:/site --entrypoint "pelican-quickstart" www-site
#

# Build CMark
FROM python:3.9.5-slim-buster as cmark

ARG INFRA_PELICAN_COMMIT=5712b2a

RUN apt update && apt upgrade -y
RUN apt install git curl cmake build-essential -y

WORKDIR /tmp/build-cmark
RUN git clone https://github.com/apache/infrastructure-pelican.git
WORKDIR /tmp/build-cmark/infrastructure-pelican
RUN git checkout ${INFRA_PELICAN_COMMIT}
WORKDIR /tmp/build-cmark
RUN ./infrastructure-pelican/bin/build-cmark.sh | grep LIBCMARKDIR > LIBCMARKDIR.sh
RUN chmod +x LIBCMARKDIR.sh

# Standard Pelican stuff
FROM python:3.9.5-slim-buster

ARG PELICAN_VERSION=4.6.0
ARG SOURCE_SANS_VERSION=3.028R
ARG MATPLOTLIB_VERSION=3.4.1

RUN apt update && apt upgrade -y
RUN apt install wget unzip fontconfig -y
RUN pip install bs4 requests pyyaml ezt markdown pelican-sitemap BeautifulSoup4
RUN pip install pelican==${PELICAN_VERSION}
RUN pip install matplotlib==${MATPLOTLIB_VERSION}

# Copy cmark here
WORKDIR /tmp/build-cmark
COPY --from=cmark /tmp/build-cmark .

# Pelican setup
WORKDIR /site

# Slightly hacky pelican-gfm plugin install, for now
RUN mkdir pelican-gfm
RUN cp /tmp/build-cmark/infrastructure-pelican/gfm.py pelican-gfm/
RUN ( echo "#!/usr/bin/environment python -B" ; echo "from .gfm import *" ) > pelican-gfm/__init__.py

# Run Pelican
RUN mkdir -p /site-generated
ENTRYPOINT [ "/bin/bash", "-c", "source /tmp/build-cmark/LIBCMARKDIR.sh && pelican -Dr -o /site-generated -b 0.0.0.0 -l" ]