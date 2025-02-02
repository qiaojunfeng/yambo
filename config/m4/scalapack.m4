#
#        Copyright (C) 2000-2021 the YAMBO team
#              http://www.yambo-code.org
#
# Authors (see AUTHORS file for details): AM
#
# This file is distributed under the terms of the GNU
# General Public License. You can redistribute it and/or
# modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation;
# either version 2, or (at your option) any later version.
#
# This program is distributed in the hope that it will
# be useful, but WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 59 Temple Place - Suite 330,Boston,
# MA 02111-1307, USA or visit http://www.gnu.org/copyleft/gpl.txt.
#
#
AC_DEFUN([AC_SLK_SETUP],[

AC_ARG_ENABLE(par_linalg,   AC_HELP_STRING([--enable-par-linalg],         [Use parallel linear algebra. Default is no]))
AC_ARG_WITH(blacs_libs,    [AC_HELP_STRING([--with-blacs-libs=(libs|mkl)],    [Use BLACS libraries <libs> or setup MKL],    [32])])
AC_ARG_WITH(scalapack_libs,[AC_HELP_STRING([--with-scalapack-libs=(libs|mkl)],[Use SCALAPACK libraries <libs> or setup MKL],[32])])

SCALAPACK_LIBS=""
BLACS_LIBS=""

reset_LIBS="$LIBS"

enable_scalapack="no"
enable_blacs="no"
internal_slk="no"
internal_blacs="no"
compile_slk="no"
compile_blacs="no"
#
# Set fortran linker names of BLACS/SCALAPACK functions to check for.
#
blacs_routine="blacs_set"
scalapack_routine="pcheev"
mpi_routine=MPI_Init
#
# Search for MKL-Scalapack
#
try_mkl_scalapack="no"
#
if test -d "${MKLROOT}" ; then
   #
   # Check for MPI libraries
   #
   mkl_libdir="${MKLROOT}/lib"
   #
   case "${MPIKIND}" in
   *Sgi* | *sgi* | *SGI* )
      lib_mkl_blacs="mkl_blacs_sgimpt_lp64" ;;
   *OpenMPI* | *Open* )
      lib_mkl_blacs="mkl_blacs_openmpi_lp64" ;;
   *)
      lib_mkl_blacs="mkl_blacs_intelmpi_lp64" ;;
   esac
   #
   # Check for compiler
   #
   case "${FCKIND}" in
   *intel* | *pgi* | *nvfortran* )
      try_mkl_scalapack="-L${mkl_libdir} -lmkl_scalapack_lp64 -lmkl_intel_lp64 -lmkl_intel_thread -lmkl_core -l${lib_mkl_blacs} -liomp5 -lpthread -lm -ldl"
      ;; 
   *gfortran* )
      try_mkl_scalapack="-L${mkl_libdir} -lmkl_scalapack_lp64 -lmkl_gf_lp64 -lmkl_core -l${lib_mkl_blacs} -lpthread -lm -ldl"
      ;;
   esac
fi
#
# Parse configure options
#
case $with_blacs_libs in
  yes) enable_blacs="internal" ;;
  no)  enable_blacs="no" ; enable_par_linalg="no" ;;
  mkl) 
    if test "$try_mkl_scalapack" = "no" ; then
       enable_blacs="no" ; enable_par_linalg="no" 
    else
       enable_blacs="check"; BLACS_LIBS="$try_mkl_scalapack" 
    fi
    ;;
  *) enable_blacs="check"; BLACS_LIBS="$with_blacs_libs" ;;
esac
#
case $with_scalapack_libs in
  yes) enable_scalapack="internal" ;;
  no) enable_scalapack="no" ; enable_par_linalg="no" ;;
  mkl) 
    if test "$try_mkl_scalapack" = "no" ; then
       enable_scalapack="no" ; enable_par_linalg="no" 
    else
       enable_scalapack="check"; SCALAPACK_LIBS="$try_mkl_scalapack" 
    fi
    ;; 
  *) enable_scalapack="check"; SCALAPACK_LIBS="$with_scalapack_libs" ;;
esac
#
if test "$mpibuild"  = "yes"; then
  #
  if test "$enable_blacs" = "check" ; then
    #
    acx_blacs_save_LIBS="$BLACS_LIBS"
    LIBS="$LIBS $FLIBS $LAPACK_LIBS $BLAS_LIBS"
    # First, check BLACS_LIBS environment variable
    if test "x$BLACS_LIBS" != x; then
      save_LIBS="$LIBS"; LIBS="$BLACS_LIBS $LIBS"
      AC_MSG_CHECKING([for $blacs_routine in $BLACS_LIBS])
      AC_TRY_LINK_FUNC($blacs_routine, [enable_blacs="yes"], [enable_blacs="internal"; BLACS_LIBS=""])
      AC_MSG_RESULT($enable_blacs)
      BLACS_LIBS="$acx_blacs_save_LIBS"
      LIBS="$save_LIBS"
    else
      enable_blacs="no";
    fi
    #
  fi
  #
  if test "$enable_scalapack" = "check" ; then
    acx_scalapack_save_LIBS="$SCALAPACK_LIBS"
    LIBS="$LIBS $FLIBS $LAPACK_LIBS $BLAS_LIBS $BLACS_LIBS"
    # First, check SCALAPACK_LIBS environment variable
    if test "x$SCALAPACK_LIBS" != x; then
      save_LIBS="$LIBS"; LIBS="$SCALAPACK_LIBS $LIBS"
      AC_MSG_CHECKING([for $scalapack_routine in $SCALAPACK_LIBS])
      AC_TRY_LINK_FUNC($scalapack_routine, [enable_scalapack="yes"], [enable_scalapack="internal"; SCALAPACK_LIBS=""])
      AC_MSG_RESULT($enable_scalapack)
      SCALAPACK_LIBS="$acx_scalapack_save_LIBS"
      LIBS="$save_LIBS"
    else
      enable_scalapack="no";
    fi
  fi
  #
  if test x"$enable_par_linalg" = "xyes"; then
    if test x"$enable_int_linalg" = "xyes"; then
      enable_blacs="internal";
      enable_scalapack="internal";
    else
      if test "$enable_blacs"     = "no"; then enable_blacs="internal"    ; fi
      if test "$enable_scalapack" = "no"; then enable_scalapack="internal"; fi
    fi
  fi
  #
  if test "$mpif_found" = "yes" && test "$enable_blacs" = "internal"; then
    enable_blacs="yes"
    internal_blacs="yes";
    BLACS_LIBS="${extlibs_path}/${FCKIND}/${FC}/lib/libblacs.a ${extlibs_path}/${FCKIND}/${FC}/lib/libblacs_C_init.a ${extlibs_path}/${FCKIND}/${FC}/lib/libblacs_init.a";
    if test -e "${extlibs_path}/${FCKIND}/${FC}/lib/libblacs.a" && test -e "${extlibs_path}/${FCKIND}/${FC}/lib/libblacs_init.a"; then
      compile_blacs="no"
    else
      compile_blacs="yes"
    fi
  fi
  #
  if test "$mpif_found" = "yes" && test "$enable_scalapack" = "internal"; then
    enable_scalapack="yes"
    internal_slk="yes"
    SCALAPACK_LIBS="${extlibs_path}/${FCKIND}/${FC}/lib/libscalapack.a"
    if test -e "${extlibs_path}/${FCKIND}/${FC}/lib/libscalapack.a"; then
      compile_slk="no"
    else
      compile_slk="yes"
    fi
  fi
  #
fi
#
if test "$enable_blacs" = "yes" && test "$enable_scalapack" = "yes" ; then
  def_scalapack="-D_SCALAPACK"
else
  enable_scalapack="no"
  enable_blacs="no"
  def_scalapack=""
  BLACS_LIBS=""
  SCALAPACK_LIBS=""
  compile_blacs="no"
  compile_slk="no"
  internal_blacs="no"
  internal_slk="no"
fi
#
LIBS="$reset_LIBS"
#
AC_SUBST(BLACS_LIBS)
AC_SUBST(SCALAPACK_LIBS)
AC_SUBST(enable_scalapack)
AC_SUBST(def_scalapack)
AC_SUBST(compile_slk)
AC_SUBST(internal_slk)
AC_SUBST(compile_blacs)
AC_SUBST(internal_blacs)

])
