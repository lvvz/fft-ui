FROM debian:testing-slim

# sbcl

ENV SBCL_HOME "/opt/lib/sbcl"
ENV ASDF_OUTPUT_TRANSLATIONS "/:"
ENV PATH "/opt/bin:${PATH}"

RUN echo ">>= Configure SBCL ..." \
 && SBCL_VER=1.3.20 \
 && SBCL_ARCH=x86-64 \
 && SBCL_PLAT=linux \
 && SBCL_FULLVER=sbcl-${SBCL_VER}-${SBCL_ARCH}-${SBCL_PLAT} \
 && SBCL_BIN=${SBCL_FULLVER}-binary \
 && SBCL_FILE=${SBCL_BIN}.tar.bz2 \
 && SBCL_URL=https://prdownloads.sourceforge.net/sbcl/${SBCL_FILE} \
 && echo ">>= Set environment variables ..." \
 && INSTALL_ROOT=/opt \
 && TMP_DIR=$(mktemp -d) \
 && echo ">>= Install packages ..." \
 && export DEBIAN_FRONTEND=noninteractive \
 && apt-get -y update \
 && apt-get -y upgrade \
 && apt-get -y install --no-install-recommends --no-install-suggests \
     sudo openssl curl make bzip2 ca-certificates \
 && echo ">>= Create temporary directories ..." \
 && mkdir ${TMP_DIR}/pkgs \
 && curl -L -o "${TMP_DIR}/pkgs/${SBCL_FILE}" \
        "${SBCL_URL}" \
 && mkdir ${TMP_DIR}/sbcl \
 && bzip2 -cd "${TMP_DIR}/pkgs/${SBCL_FILE}" | tar xf - -C "${TMP_DIR}" \
 && cd ${TMP_DIR}/${SBCL_FULLVER} \
 && SBCL_HOME="${SBCL_HOME}" INSTALL_ROOT="${INSTALL_ROOT}" \
        sh "install.sh" \
 && echo ">>= Remove temporary directories ..." \
 && rm -rf ${TMP_DIR} \
 && rm -rf /var/lib/apt/lists/* \
 && echo ">>= Add a standard user ..." \
 && addgroup --gid 1000 stdusr \
 && useradd --create-home --shell /bin/bash --uid 1000 --gid 1000 stdusr \
 && echo ">>= Grant privileges to the standard user ..." \
 && echo "stdusr ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/custom \
 && chmod 400 /etc/sudoers.d/custom

USER stdusr
WORKDIR /mnt/work
ENTRYPOINT ["sbcl"]


# quicklisp
RUN echo ">>= Install packages ..." \
 && export DEBIAN_FRONTEND=noninteractive \
 && sudo apt-get -y update \
 && sudo apt-get -y upgrade \
 && sudo apt-get -y install --no-install-recommends --no-install-suggests \
        openssl curl ca-certificates gnupg \
	git \
 && echo ">>= Set environment variables ..." \
 && INSTALL_DIR=${HOME}/quicklisp \
 && TMP_DIR=$(mktemp -d) \
 && export GNUPGHOME="$(mktemp -d)" \
 && echo ">>= Download Quicklisp ..." \
 && curl "https://beta.quicklisp.org/quicklisp.lisp" > ${TMP_DIR}/quicklisp.lisp \
 && curl "https://beta.quicklisp.org/quicklisp.lisp.asc" > ${TMP_DIR}/quicklisp.lisp.asc \
 && curl "https://beta.quicklisp.org/release-key.txt" > ${TMP_DIR}/release-key.txt \
 && gpg --import ${TMP_DIR}/release-key.txt \
 && gpg --verify ${TMP_DIR}/quicklisp.lisp.asc ${TMP_DIR}/quicklisp.lisp \
 && echo ">>= Install Quicklisp ..." \
 && sbcl --noinform --noprint --non-interactive \
        --load ${TMP_DIR}/quicklisp.lisp \
        --eval \
            "(quicklisp-quickstart:install :path \"${INSTALL_DIR}\")" \
        --eval "(ql-util:without-prompting (ql:add-to-init-file))" \
 && echo ">>= Updating Lisp Packages ..." \
 && sbcl --noinform --noprint --non-interactive \
        --eval "(ql:update-client)" \
        --eval "(ql-util:without-prompting (ql:update-all-dists))" \
 && echo ">>= Remove temporary directories and files ..." \
 && rm -rf ${TMP_DIR} ${GNUPGHOME} \
 && find "${INSTALL_DIR}/" -name "*.fasl" -exec rm {} \;

RUN (cd ${HOME}/quicklisp/local-projects/ ; \
	git clone https://github.com/lvvz/fft-ui.git ; \
	cd fft-ui/ ; \
	git checkout 53fa4bbb0d84d3fae33333a4e2339ce97ee1d6f7 )

RUN rm -rf ${HOME}/quicklisp/local-projects/fft-ui/.git/

RUN echo "fft-ui/fft-ui.asd" > ${HOME}/quicklisp/local-projects/system-index.txt

RUN sbcl --noinform --noprint --non-interactive --eval "(ql:quickload :fft-ui)"

# run a web server
CMD rlwrap sbcl --interactive --eval "(progn (ql:quickload :fft-ui) (fft-ui:start-server))"
