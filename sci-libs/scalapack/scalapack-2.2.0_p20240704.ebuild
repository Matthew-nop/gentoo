# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake flag-o-matic fortran-2 toolchain-funcs

# 2024/07/04 master branch containing 45 commits on top of 2.2.0
COMMIT_HASH="0234af94c6578c53ac4c19f2925eb6e5c4ad6f0f"

DESCRIPTION="Subset of LAPACK routines redesigned for heterogenous (MPI) computing"
HOMEPAGE="https://www.netlib.org/scalapack/"
SRC_URI="https://github.com/Reference-ScaLAPACK/${PN}//archive/${COMMIT_HASH}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/${PN}-${COMMIT_HASH}"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~riscv ~x86 ~amd64-linux ~x86-linux"
IUSE="static-libs test"
RESTRICT="!test? ( test )"

BDEPEND="virtual/pkgconfig"
RDEPEND="
	virtual/lapack
	virtual/mpi[fortran]
"
DEPEND="${RDEPEND}"

PATCHES=( )

src_prepare() {
	cmake_src_prepare

	if use static-libs; then
		mkdir "${WORKDIR}/${PN}_static" || die
	fi
	# mpi does not have a pc file
	sed -i -e 's/mpi//' scalapack.pc.in || die
}

src_configure() {
	# -Werror=strict-aliasing
	# https://bugs.gentoo.org/862924
	# https://github.com/Reference-ScaLAPACK/scalapack/issues/95
	#
	# Do not trust it for LTO either.
	append-flags -fno-strict-aliasing
	filter-lto

	# https://github.com/Reference-ScaLAPACK/scalapack/issues/31
	append-cflags -std=gnu89

	scalapack_configure() {
		local mycmakeargs=(
			-DUSE_OPTIMIZED_LAPACK_BLAS=ON
			-DBLAS_LIBRARIES="$($(tc-getPKG_CONFIG) --libs blas)"
			-DLAPACK_LIBRARIES="$($(tc-getPKG_CONFIG) --libs lapack)"
			-DBUILD_TESTING=$(usex test)
			$@
		)
		cmake_src_configure
	}

	scalapack_configure -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=OFF
	use static-libs && \
		CMAKE_BUILD_DIR="${WORKDIR}/${PN}_static" scalapack_configure \
		-DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON
}

src_compile() {
	cmake_src_compile
	use static-libs && \
		CMAKE_BUILD_DIR="${WORKDIR}/${PN}_static" cmake_src_compile
}

src_install() {
	cmake_src_install
	use static-libs && \
		CMAKE_BUILD_DIR="${WORKDIR}/${PN}_static" cmake_src_install

	insinto /usr/include/blacs
	doins BLACS/SRC/*.h

	insinto /usr/include/scalapack
	doins PBLAS/SRC/*.h
}
