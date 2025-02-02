!
!        Copyright (C) 2000-2021 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM, DS
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
subroutine io_RT_components_G_lesser(ID,T_size)
 !
 use pars,           ONLY:SP,schlen
 use drivers,        ONLY:l_real_time
 use R_lattice,      ONLY:nkibz
 use stderr,         ONLY:intc
 use IO_int,         ONLY:def_variable_bulk,io_variable_bulk
 use IO_m,           ONLY:variable_exist,write_is_on,read_is_on,io_sec,io_unit,netcdf_call,nf90_sync
 use hamiltonian,    ONLY:H_rotation
 use RT_control,     ONLY:GF_RT_IO_t,SAVE_G_history,NE_i_start_time
 use real_time,      ONLY:dG_lesser,G_MEM_steps,RT_bands,RT_nbands,RT_nk,l_RT_rotate_DM,&
&                         NE_i_time,RT_dyn_step,RT_step,i_MEM_now,i_MEM_prev,i_MEM_old, &
&                         Ho_plus_Sigma,H_EQ,l_RT_RWA,RTibz
 use netcdf,         ONLY:NF90_UNLIMITED
#if defined _PAR_IO
 use parallel_m,     ONLY:PAR_G_k_range
#endif
 !
 implicit none
 !
 integer, intent(in)  :: ID,T_size
 !
 logical           :: l_H_rot,l_H_sig,l_H_EQ
 integer           :: ib,ik,ikibz,i_sp_pol,i_time,i_mem,i_mem_sorted,G_IO_steps
 integer           :: VAR_SZ(5),IPOS(5),PAR_G_k_range_ibz(2)
 real(SP)          :: time(2)
 character(schlen) :: dim_names(5),var_name,dim_name_ibz
 !
 complex(SP), allocatable ::Delta_Sigma(:,:,:,:)
 !
 i_sp_pol=1
 !
 VAR_SZ(1:3)=(/2,RT_nbands,RT_nbands/)
 dim_names(1:3)  =[character(schlen) :: 'complex', 'RT_nbands','RT_nbands']
 IPOS(1:3)=(/1,1,1/)
 !
 if(.not.SAVE_G_history) then
   VAR_SZ(5)    = G_MEM_steps
   dim_names(5) ='G_MEM_steps'
 else
   VAR_SZ(5)    = NF90_UNLIMITED
   dim_names(5) ='G_IO_time_step'
 endif
 !
 G_IO_steps=GF_RT_IO_t%INTERVAL_steps/nint(RT_dyn_step/RT_step)
 !
#if defined _PAR_IO
 !
 VAR_SZ(4)    = RT_nk
 dim_names(4) ='RT_nk'
 dim_name_ibz ='nkibz'
 !
 if ( NE_i_time==NE_i_start_time .and. write_is_on(ID)) then
   l_H_sig= G_IO_steps==1 .and. SAVE_G_history
 else
   l_H_sig= variable_exist(ID,"Delta_Sigma") .and. allocated(Ho_plus_sigma)
 endif
 !
 l_H_rot=( l_RT_rotate_DM .and. (variable_exist(ID,"H_rotation").or.write_is_on(ID)) )
 !
 if(NE_i_time==NE_i_start_time.or..not.l_real_time) then
   call def_variable_bulk(ID,"dG_lesser", 4,VAR_sz,SP,dim_names=dim_names,par_io_kind='collective',silent=.true.)
   if(l_H_sig) call def_variable_bulk(ID,"Delta_Sigma",5,(/VAR_sz(:3),nkibz,VAR_sz(5)/),SP,&
   &                                  dim_names=(/dim_names(:3),dim_name_ibz,dim_names(5)/),par_io_kind='collective',silent=.true.)
   if(l_H_rot) call def_variable_bulk(ID,"H_rotation",6,VAR_sz(1:4),SP,&
   &                                             dim_names=dim_names(1:4),par_io_kind='collective',silent=.true.)
 endif
 !
 IPOS(4)=PAR_G_k_range(1)
 !
 if ( NE_i_time==1 .and. write_is_on(ID)) then
   l_H_EQ= G_IO_steps==1 .and. SAVE_G_history
 else
   l_H_EQ= variable_exist(ID,"H_equilibrium") .and. allocated(H_EQ)
 endif
 !
 if((NE_i_time==1.or..not.l_real_time) .and. l_H_EQ) then
   call def_variable_bulk(ID,"H_equilibrium",7,VAR_sz(1:4),SP,&
   &                              dim_names=dim_names(1:4),par_io_kind='collective',silent=.true.)
   call io_variable_bulk(ID,7,C3=H_EQ(:,:,PAR_G_k_range(1):PAR_G_k_range(2),1),IPOS=IPOS(1:4))
 endif
 !
 if(l_real_time) then
   do i_mem_sorted=G_MEM_steps-T_size+1,G_MEM_steps
     if(     SAVE_G_history) IPOS(5)=GF_RT_IO_t%N+(i_mem_sorted-G_MEM_steps)
     if(.not.SAVE_G_history) IPOS(5)=      T_size+(i_mem_sorted-G_MEM_steps)
     !i_mem=mod(i_MEM_now+i_mem_sorted-1,G_MEM_steps)+1
     if(i_mem_sorted==G_MEM_steps  ) i_mem=i_MEM_now
     if(i_mem_sorted==G_MEM_steps-1) i_mem=i_MEM_prev
     if(i_mem_sorted==G_MEM_steps-2) i_mem=i_MEM_old
     call io_variable_bulk(ID,4,C4=dG_lesser(:,:,PAR_G_k_range(1):PAR_G_k_range(2),i_mem:i_mem),IPOS=IPOS)
   enddo
 else
   IPOS(5)=GF_RT_IO_t%N
   call io_variable_bulk(ID,4,C4=dG_lesser(:,:,PAR_G_k_range(1):PAR_G_k_range(2),1:1),IPOS=IPOS)
 endif
 !
 if(l_H_sig) then
   PAR_G_k_range_ibz(1)=RTibz%k_map(PAR_G_k_range(1))
   PAR_G_k_range_ibz(2)=RTibz%k_map(PAR_G_k_range(2))
   IPOS(4)=PAR_G_k_range_ibz(1)
   allocate(Delta_Sigma(RT_bands(1):RT_bands(2),RT_bands(1):RT_bands(2),PAR_G_k_range_ibz(1):PAR_G_k_range_ibz(2),1))
   if(write_is_on(ID)) then
     do ikibz=PAR_G_k_range_ibz(1),PAR_G_k_range_ibz(2)
       ik=RTibz%k_range(ikibz,1)
       if(     l_RT_RWA) Delta_Sigma(:,:,ikibz,1:1)=Ho_plus_sigma(:,:,ik,1:1)
       if(.not.l_RT_RWA) Delta_Sigma(:,:,ikibz,1:1)=Ho_plus_sigma(:,:,ik,1:1)-H_EQ(:,:,ik,1:1)
     enddo
   endif
   call io_variable_bulk(ID,5,C4=Delta_Sigma,IPOS=IPOS)
   if(read_is_on(ID)) then
     do ik=PAR_G_k_range(1),PAR_G_k_range(2)
       ikibz=RTibz%k_map(ik)
       Ho_plus_sigma(:,:,ik,1:1)=Delta_Sigma(:,:,ikibz,1:1)
     enddo
   endif
   deallocate(Delta_Sigma)
   IPOS(4)=PAR_G_k_range(1)
 endif
 if(l_H_rot) call io_variable_bulk(ID,6,C4=H_rotation(:,:,PAR_G_k_range(1):PAR_G_k_range(2),1:1),IPOS=IPOS(1:4))
 !
#else
 !
 ik = maxval(io_sec(ID,:))-2
 ikibz=RTibz%k_map(ik)
 !
 VAR_SZ(4)    = 1
 dim_names(4) ='k_fragment'
 IPOS(4)      = 1
 !
 time(1)=(NE_i_time-(T_size-1)*nint(RT_dyn_step/RT_step))*RT_step
 time(2)=(NE_i_time-1)*RT_step
 !
 var_name="dG_lesser_K"//trim(intc(ik))//"_SP_POL"//trim(intc(i_sp_pol))
 call def_variable_bulk(ID,trim(var_name),4,VAR_SZ,SP,dim_names=dim_names,silent=.true.)
 !
 if(l_real_time) then
   do i_mem_sorted=G_MEM_steps-T_size+1,G_MEM_steps
     if(     SAVE_G_history) IPOS(5)=GF_RT_IO_t%N+(i_mem_sorted-G_MEM_steps)
     if(.not.SAVE_G_history) IPOS(5)=      T_size+(i_mem_sorted-G_MEM_steps)
     !i_mem=mod(i_MEM_now+i_mem_sorted-1,G_MEM_steps)+1
     if(i_mem_sorted==G_MEM_steps  ) i_mem=i_MEM_now
     if(i_mem_sorted==G_MEM_steps-1) i_mem=i_MEM_prev
     if(i_mem_sorted==G_MEM_steps-2) i_mem=i_MEM_old
     call io_variable_bulk(ID,4,C4=dG_lesser(:,:,ik:ik,i_mem:i_mem),IPOS=IPOS)
   enddo
 else
   IPOS(5)=GF_RT_IO_t%N
   call io_variable_bulk(ID,4,C4=dG_lesser(:,:,ik:ik,1:1),IPOS=IPOS)
 endif
 !
 var_name="Delta_Sigma_K"//trim(intc(ikibz))//"_SP_POL"//trim(intc(i_sp_pol))
 if ( NE_i_time==NE_i_start_time .and. write_is_on(ID)) then
   l_H_sig= G_IO_steps==1 .and. SAVE_G_history .and. ik==RTibz%k_range(ikibz,1)
 else
   l_H_sig= variable_exist(ID,trim(var_name)) .and. allocated(Ho_plus_sigma)
 endif
 !
 if ( l_H_sig ) then
   call def_variable_bulk(ID,trim(var_name),5,VAR_SZ(1:3),SP,dim_names=dim_names(1:3))
   allocate(Delta_Sigma(RT_bands(1):RT_bands(2),RT_bands(1):RT_bands(2),1,1))
   if(write_is_on(ID)) then
     if(     l_RT_RWA) Delta_Sigma(:,:,1,1)=Ho_plus_sigma(:,:,ik,i_sp_pol)-H_EQ(:,:,ik,i_sp_pol)
     if(.not.l_RT_RWA) Delta_Sigma(:,:,1,1)=Ho_plus_sigma(:,:,ik,i_sp_pol)
   endif
   call io_variable_bulk(ID,5,C2=Delta_Sigma(:,:,1,1))
   if(read_is_on(ID)) then
     do ik=RTibz%k_range(ikibz,1),RTibz%k_range(ikibz,2)
       Ho_plus_sigma(:,:,ik,i_sp_pol)=Delta_Sigma(:,:,1,1)
     enddo
   endif
   deallocate(Delta_Sigma)
 endif
 !
 var_name="H_rotation_K"//trim(intc(ik))//"_SP_POL"//trim(intc(i_sp_pol))
 l_H_rot=( l_RT_rotate_DM .and. (variable_exist(ID,trim(var_name)).or.write_is_on(ID)) )
 !
 if ( l_H_rot ) then
   call def_variable_bulk(ID,trim(var_name),6,VAR_SZ(1:2),SP,dim_names=dim_names(1:2))
   call  io_variable_bulk(ID,6,C2=H_rotation(:,:,ik,i_sp_pol))
 endif
 !
 var_name="H_equilibrium_K"//trim(intc(ik))//"_SP_POL"//trim(intc(i_sp_pol))
 if ( NE_i_time==1 .and. write_is_on(ID)) then
   l_H_EQ = l_H_sig
 else
   l_H_EQ= variable_exist(ID,trim(var_name)) .and. allocated(H_EQ)
 endif
 !
 if(l_H_EQ) then
   call def_variable_bulk(ID,"H_equilibrium",7,VAR_sz(1:3),SP,dim_names=dim_names(1:3))
   call io_variable_bulk(ID,7,C2=H_EQ(:,:,ik,i_sp_pol))
 endif
 !
#endif
 !
 ! In case of frequent I/O this gives a significant slowdown of the simulation
 if (G_IO_steps>=10) call netcdf_call(nf90_sync(io_unit(ID)),ID)
 !
end subroutine io_RT_components_G_lesser
