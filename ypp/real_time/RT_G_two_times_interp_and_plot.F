!
!        Copyright (C) 2000-2019 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): DS
! 
! This file is distributed under the terms of the GNU 
! General Public License. You can redistribute it and/or 
! modify it under the terms of the GNU General Public 
! License as published by the Free Software Foundation; 
! either version 2, or (at your option) any later version.
!
! This program is distributed in the hope that it will 
! be useful, but WITHOUT ANY WARRANTY; without even the 
! implied warranty of MERCHANTABILITY or FITNESS FOR A 
! PARTICULAR PURPOSE.  See the GNU General Public License 
! for more details.
!
! You should have received a copy of the GNU General Public 
! License along with this program; if not, write to the Free 
! Software Foundation, Inc., 59 Temple Place - Suite 330,Boston, 
! MA 02111-1307, USA or visit http://www.gnu.org/copyleft/gpl.txt.
!
subroutine RT_G_two_times_interp_and_plot(en,kpt,qpt)
 !
 use pars,           ONLY:SP
 use com,            ONLY:of_open_close
 use YPP_interfaces, ONLY:k_special
 use YPPm,           ONLY:BANDS_path,BANDS_steps,CIRCUIT_k,USER_k
 use RT_control,     ONLY:RTibz_to_RT_k
 use real_time,      ONLY:RT_nk
 use YPP_real_time,  ONLY:RT_conf,GreenF_T_and_W,l_RT_G_two_times
 use electrons,      ONLY:levels
 use R_lattice,      ONLY:bz_samp
 use D_lattice,      ONLY:lattice
 use interpolate,    ONLY:INTERPOLATION_driver_seed,INTERPOLATION_driver_do
 !
#include<memory.h>
 !
 type(levels)  :: en
 type(bz_samp) :: kpt,qpt,RT_k
 !
 ! Work space
 !
 integer  :: ID_RT !,GF_size
 !real(DP),pointer, contiguous :: G_w_t_pt(:,:,:) => null()
 real(SP) :: G_w_t_real(RT_conf%W_n_steps,RT_nk,2)
 !
 if (.not.l_RT_G_two_times) return
 !
 !!GF_size=(/2,size(GreenF_T_and_W%F_W,1),size(GreenF_T_and_W%F_W,2)/)
 !GF_size=(/2,RT_conf%W_n_steps,RT_nk/)
 !G_w_t_pt => linkC2R(GreenF_T_and_W%F_W,isize_loc)
 !
 G_w_t_real(:,:,1)=real(      GreenF_T_and_W%F_W, SP)
 G_w_t_real(:,:,2)=real(aimag(GreenF_T_and_W%F_W),SP)
 !
 YAMBO_FREE(GreenF_T_and_W%F_W)
 !
 call section('=',"Loading special Points for the "//trim(lattice)//" lattice")
 !============================================================================= 
 !
 call RTibz_to_RT_k(RT_k)
 !
 call k_ibz2bz(RT_k,'iku',.TRUE.)
 !
 call k_special()
 !
 call k_circuit_driver( BANDS_path, BANDS_steps )
 !
 call section('=','Interpolation@work: Circuit')
 !============================================================================= 
 !
 call INTERPOLATION_driver_seed("RT_G_w",ID_RT,(/1,RT_conf%W_n_steps/),RT_k,SEED_R3=G_w_t_real)
 call INTERPOLATION_driver_do("RT_G_w",ID_RT,CIRCUIT_k)
 !
 call section('=','Plotting')
 !============================================================================= 
 !
 if(CIRCUIT_k%nbz>0) call plot_interpolated_values(RT_k,en,0._SP,CIRCUIT_k,&
 &                                                  (/ID_RT/),(/1,RT_conf%W_n_steps/),1,(/2/),"interpolated","G_k_w",0)
 if(   USER_k%nbz>0) call plot_interpolated_values(RT_k,en,0._SP,USER_k,   &
 &                                                  (/ID_RT/),(/1,RT_conf%W_n_steps/),1,(/2/),"built_in",    "G_k_w",0)
 !
 call INTERPOLATION_driver_end(0)
 !
end subroutine RT_G_two_times_interp_and_plot
