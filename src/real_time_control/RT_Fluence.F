!
!        Copyright (C) 2000-2021 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM DS
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
subroutine RT_Fluence_and_pikind(En,i_field)
 !
 use pars,           ONLY:SP,pi
 use units,          ONLY:SPEED_OF_LIGHT,AU2KWCMm2,PS2AUT
 use real_time,      ONLY:RT_step,NE_steps,NE_i_time
 use fields,         ONLY:Efield,gauge_field
 use functions,      ONLY:theta_function
 use electrons,      ONLY:levels
 use parser_m,       ONLY:parser
 !
 implicit none
 !
 type(levels), intent(in) :: En
 integer, intent(in)      :: i_field
 ! 
 ! Work Space
 !
 type(gauge_field) :: A
 !
 logical      :: l_print_rabi
 integer      :: it0,it,last_it_evaluated,NE_i_time_save
 real(SP)     :: I(NE_steps),Omega(NE_steps),T(NE_steps)
 complex(SP)  :: E(3)
 !
 real(SP),external :: RIntegrate,Rabi_frequency
 !
 call parser("RabiAnalysis",l_print_rabi)
 !
 ! E(t)=-d A(t)/dt / SPEED_OF_LIGHT
 !
 ! From RT_Ext_fields we see that
 !
 ! A'(t)=-Efield(i_field)%amplitude*Efield(i_field)%versor(:)*SPEED_OF_LIGHT * (small_a' theta + small_a theta')
 !
 ! Thus
 ! 
 ! |E(t)|^2= Efield(i_field)%amplitude**2 * | small_a' theta + small_a theta' |^2
 !
 if ( Efield(i_field)%intensity<1.E-15_SP ) then
   Efield(i_field)%t_final=Efield(i_field)%t_initial
   Efield(i_field)%t_final_indx=Efield(i_field)%t_initial_indx
   Efield(i_field)%fluence=0._SP
   Efield(i_field)%pi_kind=0._SP
   return
 endif
 !
 I=0._SP
 T=0._SP
 last_it_evaluated=0
 NE_i_time_save=NE_i_time
 !
 Efield(i_field)%fluence=0._SP
 Efield(i_field)%pi_kind=0._SP
 !
 it0=Efield(i_field)%t_initial_indx
 !
 do it=it0,NE_steps
   !
   T(it)=it*RT_step
   !
   if ((it-it0)>6*nint(Efield(i_field)%width/RT_step)) exit
   !
   NE_i_time=it
   !
   call RT_Ext_fields(A,T(it),i_field)
   !
   I(it)    =A%intensity
   !
   Omega(it)=A%envelop
   !
   last_it_evaluated=it
   !
 enddo
 !
 NE_i_time=NE_i_time_save
 !
 ! Omega(t)
 ! I divide for |E| which is already accounted for in Raby frequency
 ! Rabi_frequency is in THz  
 !
 Omega(:)=Omega(:)*Rabi_frequency(En,i_field,l_print_rabi)/Efield(i_field)%amplitude
 ! 
 ! To get the fluence in kJ/cm^2 I should translate T in sec.
 ! Then I would have a factor 10^-12 ( 1 nJ/cm^2 = 10^-12 kJ/cm^2 )
 ! thus I ruther convert time in ps
 !
 T(:)=T(:)/real(PS2AUT,SP)      ! au -> ps
 !
 Efield(i_field)%fluence=RIntegrate(I(it0:last_it_evaluated),T(it0:last_it_evaluated),last_it_evaluated-it0+1)
 !
 Efield(i_field)%pi_kind=RIntegrate(Omega(it0:last_it_evaluated),T(it0:last_it_evaluated),last_it_evaluated-it0+1)
 !
 Efield(i_field)%t_final_indx=last_it_evaluated
 Efield(i_field)%t_final=(Efield(i_field)%t_final_indx-1)*RT_step
 !
 if(l_print_rabi) call Rabi_frequency_all(En,i_field)
 !
end subroutine RT_Fluence_and_pikind
!
!
function Rabi_frequency(En,i_field,l_print_rabi)
 !
 ! To be fixed in parallel
 ! To be fixed for degenerate states 
 !
 use pars,           ONLY:SP,rZERO,cZERO,cI
 use units,          ONLY:HA2EV,PS2AUT
 use R_lattice,      ONLY:nkibz
 use electrons,      ONLY:n_sp_pol,levels
 use X_m,            ONLY:global_gauge
 use fields,         ONLY:Efield,field_frequency
 use real_time,      ONLY:RT_bands,RT_nbands
 use dipoles,        ONLY:DIP_iR,DIP_v
 use parallel_m,     ONLY:PAR_IND_Xk_ibz,PAR_Xk_ibz_index
 use com,            ONLY:msg,of_open_close
 use vec_operate,    ONLY:degeneration_finder
 !
 implicit none
 !
 real(SP)            :: Rabi_frequency
 !
 type(levels), intent(in)  :: En
 integer,      intent(in)  :: i_field
 logical,      intent(in)  :: l_print_rabi
 !
 ! Workspace
 !
 integer     :: i_fr,i_sp_pol,ik,ik_mem,ib1,ib2,i_grp1,i_grp2,i_sp_pol_ref,ik_ref,ib1_ref,ib2_ref, &
 &              first_el(RT_nbands),n_of_el(RT_nbands),n_deg_grp,n_deg_states(2)
 logical     :: vel_gauge,len_gauge
 real(SP)    :: effective_frequency,E_trans,E_dist,delta_E
 complex(SP) :: POL_or_Jtot(3),field_term
 !
 len_gauge=trim(global_gauge)=="length"
 vel_gauge=trim(global_gauge)=="velocity"
 !
 effective_frequency=0._SP
 do i_fr=1,Efield(i_field)%n_frequencies
   effective_frequency=effective_frequency+field_frequency(Efield(i_field),i_fr)
 enddo
 effective_frequency=effective_frequency/real(Efield(i_field)%n_frequencies,SP)
 !
 Rabi_frequency=rZERO
 E_dist=0.1_SP
 !
 do i_sp_pol=1,n_sp_pol
   do ik=1,nkibz
     !if (.not.PAR_IND_Xk_ibz%element_1D(ik)) cycle
     !ik_mem=PAR_Xk_ibz_index(ik)
     do ib1=RT_bands(1),RT_bands(2)
       do ib2=ib1+1,RT_bands(2)
         delta_E=En%E(ib2,ik,i_sp_pol)-En%E(ib1,ik,i_sp_pol)
         if (delta_E<1.E-5_SP) cycle
         if (abs(delta_E-effective_frequency)>abs(E_dist)) cycle
         E_dist=effective_frequency-delta_E
         E_trans=delta_E
       enddo
     enddo
   enddo
 enddo
 !
 if (E_dist==0.1_SP) then
   call warning(" Rabi_term: No transition found within 0.1 Hartree of the field frequency")
   return
 endif
 !
 do i_sp_pol=1,n_sp_pol
   do ik=1,nkibz
     if (.not.PAR_IND_Xk_ibz%element_1D(ik)) cycle
     ik_mem=PAR_Xk_ibz_index(ik)
     call degeneration_finder(En%E(RT_bands(1):RT_bands(2),ik,i_sp_pol),RT_nbands,first_el,n_of_el,n_deg_grp, &
     &                        0.0001_SP/HA2EV,Include_single_values=.true.)
     do i_grp1=1,n_deg_grp
       ib1=first_el(i_grp1)+RT_bands(1)-1
       do i_grp2=i_grp1+1,n_deg_grp
         ib2=first_el(i_grp2)+RT_bands(1)-1
         delta_E=En%E(ib2,ik,i_sp_pol)-En%E(ib1,ik,i_sp_pol)
         if (abs(delta_E-effective_frequency)>abs(E_trans-effective_frequency)) cycle
         POL_or_Jtot=cZERO
         do ib1=first_el(i_grp1)+RT_bands(1)-1,first_el(i_grp1)+n_of_el(i_grp1)-1+RT_bands(1)-1
           do ib2=first_el(i_grp2)+RT_bands(1)-1,first_el(i_grp2)+n_of_el(i_grp2)-1+RT_bands(1)-1
             if (len_gauge) POL_or_Jtot(1:3)=POL_or_Jtot(1:3)+cI*DIP_iR(1:3,ib2,ib1,ik_mem,i_sp_pol)
             if (vel_gauge) POL_or_Jtot(1:3)=POL_or_Jtot(1:3)-DIP_v(1:3,ib2,ib1,ik_mem,i_sp_pol)
           enddo
         enddo
         field_term=sum(EField(i_field)%versor(1:3)*POL_or_Jtot(1:3) )*Efield(i_field)%amplitude !&
         !&                   /real(n_of_el(i_grp1)*n_of_el(i_grp2),SP) ! E_dot_P or A_dot_J
         if (Rabi_frequency>abs(field_term)) cycle
         Rabi_frequency=abs(field_term)
         i_sp_pol_ref=i_sp_pol
         ik_ref=ik
         ib1_ref=first_el(i_grp1)+RT_bands(1)-1
         ib2_ref=first_el(i_grp2)+RT_bands(1)-1
         n_deg_states=(/n_of_el(i_grp1),n_of_el(i_grp2)/)
       enddo
     enddo
   enddo
 enddo
 !
 Rabi_frequency=Rabi_frequency*real(PS2AUT,SP) !*2._SP
 !
 if (l_print_rabi) then
   call of_open_close("rabi_frequencies","ot")
   call msg("o rabi","#" )
   call msg("o rabi","#"," Main Rabi term",INDENT=0)
   call msg("o rabi","# transition energy and detuning ",(/E_trans,E_dist/)*HA2EV,after_msg="[eV]",INDENT=0)
   call msg("o rabi","# transition indexes             ",(/ik_ref,ib1_ref,ib2_ref/),after_msg="(ik,iv,ic)",INDENT=0)
   call msg("o rabi","# degenerate states              ", n_deg_states,after_msg="(n_v,n_c)",INDENT=0)
   call msg("o rabi","# coupling frequency             ",Rabi_frequency,after_msg="[THz]",INDENT=0)
   call msg("o rabi","#" )
   call of_open_close("rabi_frequencies")
 endif
 !
end function Rabi_frequency
!
!
subroutine Rabi_frequency_all(En,i_field)
 !
 ! To be fixed in parallel
 ! To be fixed for degenerate states 
 !
 use pars,           ONLY:SP,rZERO,cZERO,cI
 use units,          ONLY:HA2EV,PS2AUT
 use R_lattice,      ONLY:nkibz
 use electrons,      ONLY:n_sp_pol,levels,spin_occ
 use X_m,            ONLY:global_gauge
 use fields,         ONLY:Efield,field_frequency
 use real_time,      ONLY:RT_bands,RT_nbands
 use dipoles,        ONLY:DIP_iR,DIP_v
 use parallel_m,     ONLY:PAR_IND_Xk_ibz,PAR_Xk_ibz_index
 use com,            ONLY:msg
 use vec_operate,    ONLY:degeneration_finder
 use OUTPUT_simple,  ONLY:OUTPUT_add_column
 !
 implicit none
 !
 type(levels), intent(in)  :: En
 integer,      intent(in)  :: i_field
 !
 ! Workspace
 !
 real(SP)    :: Rabi_frequency
 integer     :: i_fr,i_sp_pol,ik,ik_mem,ib1,ib2,i_grp1,i_grp2,i_sp_pol_ref,ik_ref,ib1_ref,ib2_ref, &
 &              first_el(RT_nbands),n_of_el(RT_nbands),n_deg_grp,n_deg_states(2)
 logical     :: vel_gauge,len_gauge
 real(SP)    :: effective_frequency,E_trans,E_dist,delta_E
 complex(SP) :: POL_or_Jtot(3),field_term
 !
 len_gauge=trim(global_gauge)=="length"
 vel_gauge=trim(global_gauge)=="velocity"
 !
 call OUTPUT_add_column('rabi_frequencies',action="append")
 !
 effective_frequency=0._SP
 do i_fr=1,Efield(i_field)%n_frequencies
   effective_frequency=effective_frequency+field_frequency(Efield(i_field),i_fr)
 enddo
 effective_frequency=effective_frequency/real(Efield(i_field)%n_frequencies,SP)
 !
 do i_sp_pol=1,n_sp_pol
   do ik=1,nkibz
     if (.not.PAR_IND_Xk_ibz%element_1D(ik)) cycle
     ik_mem=PAR_Xk_ibz_index(ik)
     call degeneration_finder(En%E(RT_bands(1):RT_bands(2),ik,i_sp_pol),RT_nbands,first_el,n_of_el,n_deg_grp, &
     &                        0.0001_SP/HA2EV,Include_single_values=.true.)
     do i_grp1=1,n_deg_grp
       ib1=first_el(i_grp1)+RT_bands(1)-1
       do i_grp2=i_grp1+1,n_deg_grp
         ib2=first_el(i_grp2)+RT_bands(1)-1
         delta_E=En%E(ib2,ik,i_sp_pol)-En%E(ib1,ik,i_sp_pol)
         !if ( En%f(ib1,ik,i_sp_pol)*(spin_occ-En%f(ib2,ik,i_sp_pol))==0._SP ) cycle
         if (delta_E<1.E-5_SP/HA2EV) cycle
         POL_or_Jtot=cZERO
         do ib1=first_el(i_grp1)+RT_bands(1)-1,first_el(i_grp1)+n_of_el(i_grp1)-1+RT_bands(1)-1
           do ib2=first_el(i_grp2)+RT_bands(1)-1,first_el(i_grp2)+n_of_el(i_grp2)-1+RT_bands(1)-1
             if (len_gauge) POL_or_Jtot(1:3)=POL_or_Jtot(1:3)+cI*DIP_iR(1:3,ib2,ib1,ik_mem,i_sp_pol)
             if (vel_gauge) POL_or_Jtot(1:3)=POL_or_Jtot(1:3)-DIP_v(1:3,ib2,ib1,ik_mem,i_sp_pol)
           enddo
         enddo
         field_term=sum(EField(i_field)%versor(1:3)*POL_or_Jtot(1:3) )*Efield(i_field)%amplitude !&
         !&                   /real(n_of_el(i_grp1)*n_of_el(i_grp2),SP) ! E_dot_P or A_dot_J
         E_dist=effective_frequency-delta_E
         E_trans=delta_E
         Rabi_frequency=abs(field_term)*real(PS2AUT,SP)
         i_sp_pol_ref=i_sp_pol
         ik_ref=ik
         ib1_ref=first_el(i_grp1)+RT_bands(1)-1
         ib2_ref=first_el(i_grp2)+RT_bands(1)-1
         n_deg_states=(/n_of_el(i_grp1),n_of_el(i_grp2)/)
         !
         call OUTPUT_add_column("rabi",TITLES=(/" dE ","det."/),    R_VALUES=(/E_trans,E_dist/),UNIT="eV")
         call OUTPUT_add_column("rabi",TITLES=(/"ik ","ib1","ib2"/),I_VALUES=(/ik_ref,ib1_ref,ib2_ref/))
         call OUTPUT_add_column("rabi",TITLES=(/"n_v","n_c"/),      I_VALUES=n_deg_states)
         call OUTPUT_add_column("rabi",TITLES=(/"w"/),              R_VALUES=(/Rabi_frequency/),UNIT="THz")
         call OUTPUT_add_column("rabi",action="write")
         !
       enddo
     enddo
   enddo
 enddo
 !
 call OUTPUT_add_column('rabi_frequencies',action="close")
 !
end subroutine Rabi_frequency_all
