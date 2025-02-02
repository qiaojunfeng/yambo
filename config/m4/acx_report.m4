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
AC_DEFUN([ACX_REPORT],
[
# 
# - GENERAL CONFIGURATIONS -
# 
DP_check="-"
if test "$enable_dp" = "yes" ; then DP_check="X"; fi
#
KEEP_OBJS_check="-"
if test "$enable_keep_objects" = "yes" ; then KEEP_OBJS_check="X"; fi
#
TIME_profile_check="-"
if test "$enable_time_profile" = "yes" ; then TIME_profile_check="X"; fi
#
MEM_profile_check="-"
if test "$enable_memory_profile" = "yes" ; then MEM_profile_check="X"; fi
# 
# - PARALLEL SUPPORT -
# 
MPI_check="-"
if test "$mpibuild" = "yes" ; then MPI_check="X" ; fi
#
OPENMP_check="-"
if test "$enable_open_mp" = "yes" ; then OPENMP_check="X"; fi

PARIO_check="$parallel_io"
#
# - LIBRARIES -
#
#
YAML_str=" - "
if test "$internal_yaml" = "yes" ; then
  if test "$compile_yaml" = "yes" ; then YAML_str=" Ic"; fi
  if test "$compile_yaml" = "no"  ; then YAML_str=" If"; fi
elif test "$enable_yaml" = "yes" ; then
  YAML_str=" E "
fi
#
FUTILE_str=" - "
if test "$internal_futile" = "yes" ; then
  if test "$compile_futile" = "yes" ; then FUTILE_str=" Ic"; fi
  if test "$compile_futile" = "no"  ; then FUTILE_str=" If"; fi
elif test "$enable_futile" = "yes" ; then
  FUTILE_str=" E "
fi
#
IOTK_str=" - "
if test "$compile_p2y" = "yes" ; then
  IOTK_str=" E "
  if test "$internal_iotk" = "yes" ; then
    if test "$compile_iotk" = "yes" ; then IOTK_str=" Ic"; fi
    if test "$compile_iotk" = "no"  ; then IOTK_str=" If"; fi
  fi
fi
#
ETSF_str=" - "
if test "$compile_e2y" = "yes" ; then
  ETSF_str=" E "
  if test "$internal_etsf" = "yes" ; then
    if test "$compile_etsf" = "yes" ; then ETSF_str=" Ic"; fi
    if test "$compile_etsf" = "no"  ; then ETSF_str=" If"; fi
  fi
fi
#
NETCDF_str=" - "
if test "$internal_netcdf" = "yes" ; then
  if test "$compile_netcdf" = "yes" ; then NETCDF_str=" Ic"; fi
  if test "$compile_netcdf" = "no"  ; then NETCDF_str=" If"; fi
else
  NETCDF_str=" E "
fi
NETCDF_info="(NETCDF with large files support)"
if test "$enable_netcdf_classic" = "yes"; then NETCDF_info="(NETCDF large files support disabled)"; fi
if test "$enable_netcdf_par_io" = "yes";  then
  NETCDF_info="(NETCDF with parallel I/O and large files support)";
  PARIO_info="(NETCDF)";
fi
#
HDF5_str=" - "
if test "$hdf5" = "yes" ; then
  if test "$internal_hdf5" = "yes" ; then
    if test "$compile_hdf5" = "yes" ; then HDF5_str=" Ic"; fi
    if test "$compile_hdf5" = "no"  ; then HDF5_str=" If"; fi
  else
    HDF5_str=" E "
  fi
  if test "$enable_netcdf_classic" = "yes"  ; then
    HDF5_info="(No HDF5-IO format)" ;
  else
    NETCDF_info="(NETCDF4:";
    HDF5_info="HDF5-IO format";
    if test "$enable_hdf5_par_io" = "no"; then
      HDF5_info="${HDF5_info}, serial IO"   ;
      if test "$IO_LIB_VER" = "parallel" ;     then HDF5_info="${HDF5_info}, parallel_lib  " ; fi
    else
      HDF5_info="${HDF5_info}, parallel IO"   ;
      PARIO_info="(HDF5)";
    fi
    if test "$enable_hdf5_compression" = "yes"; then
      HDF5_info="${HDF5_info}, with data compression)" ;
    else
      HDF5_info="${HDF5_info}, no data compression)" ;
    fi
  fi
fi
#

#
FFT_str=" E "
if test "$internal_fft" = "yes" ; then
  if test "$compile_fftw" = "yes" || test "$compile_fftqe" = "yes"; then FFT_str=" Ic"; fi
  if test "$compile_fftw" = "no"  && test "$compile_fftqe" = "no" ; then FFT_str=" If"; fi
else
  if test "$compile_fftqe" = "yes" ; then FFT_str="E+I"; fi
fi
#
BLAS_str=" E "
if test "$internal_blas" = "yes" ; then
  if test "$compile_blas" = "yes"; then BLAS_str=" Ic"; fi
  if test "$compile_blas" = "no" ; then BLAS_str=" If"; fi
fi
#
LAPACK_str=" E "
if test "$internal_lapack" = "yes" ; then
  if test "$compile_lapack" = "yes"; then LAPACK_str=" Ic"; fi
  if test "$compile_lapack" = "no" ; then LAPACK_str=" If"; fi
fi
#
SLK_str=" - "
if test "$enable_scalapack" = "yes" ; then SLK_str=" E "; fi
if test "$internal_slk" = "yes" ; then
  if test "$compile_slk" = "yes"; then SLK_str=" Ic"; fi
  if test "$compile_slk" = "no" ; then SLK_str=" If"; fi
fi
#
BLACS_str=" - "
if test "$enable_scalapack" = "yes" ; then BLACS_str=" E "; fi
if test "$internal_blacs" = "yes" ; then
  if test "$compile_blacs" = "yes"; then BLACS_str=" Ic"; fi
  if test "$compile_blacs" = "no" ; then BLACS_str=" If"; fi
fi
#
#
PETSC_str=" - "
if test "$internal_petsc" = "yes" ; then
  if test "$compile_petsc" = "yes" ; then PETSC_str=" Ic"; fi
  if test "$compile_petsc" = "no"  ; then PETSC_str=" If"; fi
elif test "$enable_petsc" = "yes" ; then
  PETSC_str=" E "
fi

#
SLEPC_str=" - "
if test "$internal_slepc" = "yes" ; then
  if test "$compile_slepc" = "yes" ; then SLEPC_str=" Ic"; fi
  if test "$compile_slepc" = "no"  ; then SLEPC_str=" If"; fi
elif test "$enable_slepc" = "yes" ; then
  SLEPC_str=" E "
fi

#
LIBXC_str=" E "
if test "$internal_libxc" = "yes" ; then
  if test "$compile_libxc" = "yes"; then LIBXC_str=" Ic"; fi
  if test "$compile_libxc" = "no" ; then LIBXC_str=" If"; fi
fi

#
YDB_str="-";
if test "$enable_ydb" = "yes" ; then YDB_str="X"; fi
YPY_str="-";
if test "$enable_yambopy" = "yes" ; then YPY_str="X"; fi

#
MPI_str=" - ";
MPI_info=""
if test "$mpibuild" = "yes" ; then
  if test "$MPI_LIBS" = "" ; then
    MPI_info="(system default detected)";
    MPI_str=" X ";
  else
    MPI_str=" E ";
  fi
fi
#
AC_SUBST(DP_check)
AC_SUBST(KEEP_OBJS_check)
AC_SUBST(TIME_profile_check)
AC_SUBST(MEM_profile_check)
#
AC_SUBST(MPI_check)
AC_SUBST(OPENMP_check)
AC_SUBST(PARIO_check)
#
AC_SUBST(YAML_str)
AC_SUBST(FUTILE_str)
AC_SUBST(IOTK_str)
AC_SUBST(ETSF_str)
AC_SUBST(NETCDF_str)
AC_SUBST(NETCDF_info)
AC_SUBST(HDF5_str)
AC_SUBST(HDF5_info)
AC_SUBST(PARIO_info)
#
AC_SUBST(FFT_str)
AC_SUBST(BLAS_str)
AC_SUBST(LAPACK_str)
AC_SUBST(BLACS_str)
AC_SUBST(SLK_str)
AC_SUBST(PETSC_str)
AC_SUBST(SLEPC_str)
#
AC_SUBST(YDB_str)
AC_SUBST(YPY_str)
#
AC_SUBST(LIBXC_str)
AC_SUBST(MPI_str)
AC_SUBST(MPI_info)
])
