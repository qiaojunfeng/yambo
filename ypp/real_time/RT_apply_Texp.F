!
!        Copyright (C) 2000-2019 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): CA, DS
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
subroutine RT_apply_Texp(H1,Gret,H2,deltaT,eta,n_order)
 !
 !
 !
 use pars,           ONLY:SP,cI,cZERO
 use wrapper_omp,    ONLY:M_by_M_omp
 use real_time,      ONLY:RT_bands,RT_nbands,I1_matrix
 !
 implicit none
 !
 integer,     intent(in)    :: n_order
 real(SP),    intent(in)    :: deltaT
 real(SP),    intent(in)    :: eta
 complex(SP), intent(in)    :: H1(RT_bands(1):RT_bands(2),RT_bands(1):RT_bands(2))
 complex(SP), intent(inout) :: Gret(RT_bands(1):RT_bands(2),RT_bands(1):RT_bands(2))
 complex(SP), intent(in)    :: H2(RT_bands(1):RT_bands(2),RT_bands(1):RT_bands(2))
 !
 ! Work space
 !
 integer     :: i_order
 complex(SP) :: G_tmp(RT_bands(1):RT_bands(2),RT_bands(1):RT_bands(2))
 !
 complex(SP) :: U1(RT_bands(1):RT_bands(2),RT_bands(1):RT_bands(2))
 complex(SP) :: U2(RT_bands(1):RT_bands(2),RT_bands(1):RT_bands(2))
 !
 complex(SP) :: M1a_tmp(RT_bands(1):RT_bands(2),RT_bands(1):RT_bands(2))
 complex(SP) :: M1b_tmp(RT_bands(1):RT_bands(2),RT_bands(1):RT_bands(2))
 complex(SP) :: M1c_tmp(RT_bands(1):RT_bands(2),RT_bands(1):RT_bands(2))
 !
 complex(SP) :: M2a_tmp(RT_bands(1):RT_bands(2),RT_bands(1):RT_bands(2))
 complex(SP) :: M2b_tmp(RT_bands(1):RT_bands(2),RT_bands(1):RT_bands(2))
 complex(SP) :: M2c_tmp(RT_bands(1):RT_bands(2),RT_bands(1):RT_bands(2))
 !
 ! The code below does an expansion up to arbitrary order
 ! of the U(t) matrix. Taylor expansion:
 !
 ! U(t) = exp(-iHt) = 1 + (-iHt) + (iHt)^2/2! + (iHt)^3/3! + (iHt)^4/4! + (iHt)^5/5! + O(Ht^6)
 !
 ! However in the EOM for rho I need to expand U^dag(t)\rhoU(t) and not U(t) only
 !
 ! U1 = exp ( -i * H1 * dt)
 ! U2 = exp ( -i * H2 * dt)
 !
 ! Order 1 is :
 !
 U1=-cI*deltaT*H1
 U2=-cI*deltaT*H2
 !
 M1a_tmp=U1
 M1b_tmp=U1
 !
 M2a_tmp=U2
 M2b_tmp=U2
 !
 do i_order=2,n_order
   !
   call M_by_M_omp('n','n',RT_nbands,M1a_tmp,M1b_tmp/real(i_order,SP),M1c_tmp)
   call M_by_M_omp('n','n',RT_nbands,M2a_tmp,M2b_tmp/real(i_order,SP),M2c_tmp)
   !
   U1=U1+M1c_tmp
   U2=U2+M2c_tmp
   !
   if (i_order<n_order) M1b_tmp=M1c_tmp
   if (i_order<n_order) M2b_tmp=M2c_tmp
   !
 enddo
 !
 U1=(U1+I1_matrix)*exp(-deltaT*eta)
 U2=(U2+I1_matrix)*exp(-deltaT*eta)
 !
 ! Gret(t+dt,t'-dt) = U1(t';-dt) Gret(t,t') U2(t;dt) exp(-deph*dt)
 !
 G_tmp=cZERO
 call M_by_M_omp('n','n',RT_nbands,U1,Gret,G_tmp)
 call M_by_M_omp('n','n',RT_nbands,G_tmp,U2,Gret)
 !
end subroutine RT_apply_Texp
