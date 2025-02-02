!
!        Copyright (C) 2000-2021 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): HM, DS
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
integer function io_BS_header(iq,X,ID,mode)
 !
 ! Intialize variables on BSE netcdf parallel file
 !
 use parallel_m,    ONLY:master_cpu
 use parallel_int,  ONLY:PP_redux_wait
 use com,           ONLY:msg
 use pars,          ONLY:schlen,lchlen
 use stderr,        ONLY:intc
 use X_m,           ONLY:X_t
 use BS,            ONLY:BS_K_cutoff_done,l_BSE_restart,l_BSE_kernel_complete
 use BS_solvers,    ONLY:variables_BS,BSS_desc
 use IO_m,          ONLY:frag_BS_K,write_is_on,read_is_on,io_mode,io_BS_K,DUMP
 use IO_int,        ONLY:get_name,io_connect,io_disconnect,io_elemental,io_header
 use descriptors,   ONLY:IO_desc,IO_desc_duplicate
 !
 implicit none
 !
 type(X_t) :: X 
 integer   :: iq, ID
 character(*), intent(in) :: mode
 !
 logical, external :: file_exists
 integer, external :: variables_BS_more
 !
 type(IO_desc)     :: local_desc
 character(schlen) :: db_name,tmp_ch
 character(lchlen) :: full_db_name
 !
 ! Connect to parallel netCDF file.
 !
 if(.not.trim(mode)=="connect") then
   !
   db_name='BS_PAR_Q'//trim(intc(iq))
   full_db_name=get_name(trim(db_name)," ",2,CORE_IO=.FALSE.,MORE_IO=.TRUE.,COM_IO=.FALSE.)
   !
   l_BSE_kernel_complete=.false.
   !
   ! If l_BSE_restart true at this point, I'm already re-starting from a compressed kernel
   !
   if (write_is_on(ID).and.io_BS_K.and..not.l_BSE_restart.and.io_mode(ID)/=DUMP) then
     call msg("s","Looking for "//trim(full_db_name)//".")
     if (.not.file_exists(trim(full_db_name))) then
       call msg("s","BSE file not found. Creating an empty one.")
       l_BSE_restart=.false.
     else if(trim(mode)=="full") then
       call msg("s","Partial BSE file found. Using for restart.")
       l_BSE_restart = .true.
     endif
   endif
   !
   call PP_redux_wait()
   !
 endif
 !
 if(write_is_on(ID).and..not.master_cpu) then
   call io_disconnect(ID,FORCE=.TRUE.)
   return
 endif
 !
 db_name='BS_head_Q'//trim(intc(iq))
 !
 io_BS_header=io_connect(desc=trim(db_name),type=2,ID=ID)
 if(io_BS_header/=0) then
   call io_disconnect(ID,FORCE=.TRUE.)
   return
 endif
 !
 if(trim(mode)=="connect") return
 !
 !
 ! Check if the file already contains data and it is consistent
 ! DS: warning. This is potentially dangerous since all MPI tasts are all writing
 !              both the header and the variables
 !              I cannot put here if(master_cpu) because I need all MPI_tasks to
 !              go through the definition of the variables (see similar issue in io_X.F)
 !
 io_BS_header=io_header(ID,QPTS=.true.,R_LATT=.true.,WF=.true.,&
 &                      IMPOSE_SN=.true.,XC_KIND="K_WF force Xs",CUTOFF=.true.,FRAG=frag_BS_K)
 !
 io_BS_header=variables_BS(ID,iq,local_desc,.TRUE.,X=X)
 !
 if (io_BS_header/=0.and.io_mode(ID)/=DUMP) then
   call io_elemental(ID,VAR="",VAR_SZ=0,MENU=1)
   call warning('Invalid dimensions found. BSE restart file '//trim(full_db_name)//' not accepted')
   return
 endif
 !
 io_BS_header=variables_BS_more(ID,'start')
 !
 if(read_is_on(ID).and.io_BS_K.and.io_mode(ID)/=DUMP) then
   if(l_BSE_kernel_complete) then
     call msg("s","Trying to load complete BSE file  ",trim(full_db_name))
   else
     call msg("s","Possible partial BSE file not accepted in reading mode ",trim(full_db_name))
   endif
 endif
 !
 if(read_is_on(ID).and.allocated(BS_K_cutoff_done).and.l_BSE_kernel_complete.and.io_mode(ID)/=DUMP) then
   if (     io_BS_K) tmp_ch="Backup option will be compressed BSE file"
   if (.not.io_BS_K) tmp_ch="Trying to load compressed BSE file"
   call msg("s",trim(tmp_ch))
   call msg("s","Previously computed compressed files ",BS_K_cutoff_done)
 endif
 !
 call io_disconnect(ID)
 !
 if(read_is_on(ID)) call PP_redux_wait()
 !
 ! Descriptions transfer
 !   
 call IO_desc_duplicate(local_desc,BSS_desc)
 !
end function io_BS_header
!
!
integer function io_BS_PAR_init(iq,ID,mode)
 !
 use stderr,        ONLY:intc,real2ch
 use parallel_m,    ONLY:MPI_COMM_WORLD
 use com,           ONLY:msg
 use pars,          ONLY:IP,IPL,SP,schlen,lchlen,max_io_vars_open
 use BS,            ONLY:BS_K_dim,BS_IO_dim,BS_K_coupling,l_BSE_kernel_complete,&
&                        BSK_IO_mode,MAX_BSK_LIN_size,BS_lin_size_compressed,BS_K_cutoff,     &
&                        BS_res_ares_n_mat,l_BS_ares_from_res,BS_n_eh_spaces
 use IO_m,          ONLY:io_BS_K,io_file,write_is_on,read_is_on
 use IO_int,        ONLY:io_connect,def_variable_bulk,io_disconnect
 !
 implicit none
 !
 integer,      intent(in) :: iq,ID
 character(*), intent(in) :: mode
 !
 ! Workspace
 !
 character(schlen) :: db_name,ch_tmp,dim_names(3,3),BSK_IO_local
 character(lchlen) :: ch(8,max_io_vars_open)
 logical           :: def_var, io_var
 integer(IPL)      :: BS_lin_size
 integer           :: n_vars, i1,i2, i_rep,i_var, BSK_n_dims,n_replica
 !
 io_BS_PAR_init=-1
 !
 if(.not.io_BS_K .and. ((.not.BS_K_cutoff>0._SP) .or. trim(mode)=="full" )) then
   call io_disconnect(ID,FORCE=.TRUE.)
   return
 endif
 !
 if( trim(mode)=="full"        ) db_name='BS_PAR_Q'//trim(intc(iq))
 if(index(mode,"compressed")/=0) db_name='BS_COMPRESS'//trim(adjustl(real2ch(BS_K_cutoff)))//'_Q'//trim(intc(iq))
 !
 ! If I'm in compressed_check mode I skip the definition of variables
 !
 io_BS_PAR_init=io_connect(desc=trim(db_name),type=2,ID=ID,comm=MPI_COMM_WORLD)
 !
 if(write_is_on(ID).and.io_BS_PAR_init/=0) return ! here it should give error
 !
 if( read_is_on(ID).and.index(mode,"compressed")/=0) then
   ch_tmp="Compressed BSE file found"
   if(trim(mode)=="compressed_head") ch_tmp=trim(ch_tmp)//", initializing head "
   if(trim(mode)=="compressed_mat" ) ch_tmp="Compressed BSE file, initializing mat "
   if(io_BS_PAR_init==0) call msg("s",trim(ch_tmp),trim(io_file(ID)))
   if(io_BS_PAR_init/=0.or.trim(mode)=="compressed_check") return
 endif
 if( read_is_on(ID).and.trim(mode)=="full") then
   if(io_BS_PAR_init/=0) then
     call msg("s","Complete BSE file not found",trim(io_file(ID)))
     return
   endif
   if (.not.l_BSE_kernel_complete ) return
   if (     l_BSE_kernel_complete ) then
     call msg("s","Complete BSE file loading  ",trim(io_file(ID)))
   endif
 endif
 !
 io_BS_PAR_init=0
 !
 ! Define vars
 !
 dim_names(1,:)  =  'complex'
 !
 ch(1,:)="BSE_RESONANT"
 ch(2,:)="BSE_COUPLING"
 ch(3,:)="BSE_ANTI-RESONANT"
 !
 if (.not.BS_K_coupling     ) n_vars=1
 if (     BS_K_coupling     ) n_vars=2
 if (.not.l_BS_ares_from_res) n_vars=n_vars+1
 !
 BSK_IO_local=trim(BSK_IO_mode)
 if(index(mode,"compressed")/=0 ) BSK_IO_local=trim(mode)
 !
 select case(trim(BSK_IO_local))
 case("1D_linear","compressed_head","compressed_mat")
   !
   ! This is the upper triangular matrix rescared in (many) 1D arrays
   !
   BSK_n_dims=1
   !
   if(trim(BSK_IO_local)=="1D_linear" .or. trim(BSK_IO_local)=="compressed_head" ) then
     dim_names(2:3,1)=[ 'BS_K_linearized1', 'BS_K_linearized2' ]
     BS_LIN_size=int(BS_K_dim(1),kind=IPL)*int(BS_K_dim(1)+1,kind=IPL)/int(2,kind=IPL)
   endif
   if(trim(BSK_IO_local)=="compressed_mat") then
     dim_names(2:3,1)=[ 'BS_K_compressed1', 'BS_K_compressed2' ]
     BS_LIN_size=BS_lin_size_compressed
   endif
   !
   if(trim(BSK_IO_local)=="1D_linear" )                                                 ch_tmp="_LINEARIZED"
   if(trim(BSK_IO_local)=="compressed_mat" .or. trim(BSK_IO_local)=="compressed_head" ) ch_tmp="_COMPRESSED"
   BS_IO_dim(:,1)=int(min(int(MAX_BSK_LIN_size,IPL),BS_lin_size),IP)
   !
   n_replica=1+int(BS_LIN_size/int(MAX_BSK_LIN_size,IPL),IP)
   do i_rep=1,n_replica
     do i2=1,n_vars
       i1=i2+n_vars*(i_rep-1)
       i_var=i2
       if(i2==2 .and. BS_res_ares_n_mat==2) then; i_var=3; endif
       ch(i_var,i_rep)=trim(ch(i_var,i_rep))//trim(ch_tmp)//trim(intc(i_rep))
     enddo
   enddo
   BS_LIN_size=BS_LIN_size-int(MAX_BSK_LIN_size,IPL)*int(n_replica-1,IPL)
   !
   BS_IO_dim(2,1)=int(BS_LIN_size,IP)
   !
 case("2D_standard")
   !
   ! Here is the 2D mode
   !
   BSK_n_dims=2
   n_replica=1
   !
   dim_names(2:3,1) = [character(schlen) :: 'BS_K_dim', 'BS_K_dim']
   BS_IO_dim(:,1) = (/BS_K_dim(1),BS_K_dim(1)/)
   !
   if(BS_n_eh_spaces==2) then
     dim_names(2:3,2) = [character(schlen) ::  'BS_K_dim', 'BS_K_dim_A']
     BS_IO_dim(:,2) = (/BS_K_dim(1),BS_K_dim(2)/)
     dim_names(2:3,3) = [character(schlen) :: 'BS_K_dim_A', 'BS_K_dim_A']
     BS_IO_dim(:,3) = (/BS_K_dim(2),BS_K_dim(2)/)
   else if (BS_K_coupling) then
     dim_names(2:3,2) = [character(schlen) :: 'BS_K_dim', 'BS_K_dim']
     BS_IO_dim(:,2) = (/BS_K_dim(1),BS_K_dim(1)/)
   endif
   !
 end select
 !
 do i_rep=1,n_replica
   do i2=1,n_vars
     i1=i2+n_vars*(i_rep-1)
     i_var=i2
     if(i2==2 .and. BS_res_ares_n_mat==2) then; i_var=3; endif
     if( (trim(BSK_IO_local)=="1D_linear".or.trim(BSK_IO_local)=="compressed_mat".or.trim(BSK_IO_local)=="compressed_head") &
     &   .and.i_rep==n_replica.and.i_rep>1) then
       dim_names(2,i_var)=dim_names(3,i_var)
       BS_IO_dim(1,i_var)=BS_IO_dim(2,i_var)
     endif
     if(trim(mode)=="full" .or. trim(mode)=="compressed_mat") &
     &  call def_variable_bulk(ID,trim(ch(i_var,i_rep)),         1+(i_var-1)*2+(i_rep-1)*8,&
     &               [2,BS_IO_dim(1:BSK_n_dims,i_var)],SP,dim_names(1:BSK_n_dims+1,i_var),par_io_kind='independent')
     if(                        trim(mode)=="compressed_head") &
     &  call def_variable_bulk(ID,trim(ch(i_var,i_rep))//"_DONE",2+(i_var-1)*2+(i_rep-1)*8,&
     &                  BS_IO_dim(1:BSK_n_dims,i_var) , 0,dim_names(2:BSK_n_dims+1,i_var),par_io_kind='independent')
   enddo
 enddo
 !
end function io_BS_PAR_init
!
subroutine io_BS_PAR_free(ID_head,ID,mode,l_kernel_complete)
 !
 ! close BSE netcdf parallel file
 !
 use pars,          ONLY:SP
 use parallel_m,    ONLY:master_cpu
 use parallel_int,  ONLY:PP_redux_wait
 use BS,            ONLY:l_BSE_kernel_complete,BS_K_has_been_calculated_loaded,BS_K_cutoff
 use IO_m,          ONLY:read_is_on,write_is_on,io_BS_K
 use IO_int,        ONLY:io_disconnect
 !
 implicit none
 !
 integer,      intent(in)  :: ID,ID_head
 logical,      intent(in)  :: l_kernel_complete
 character(*), intent(in)  :: mode
 !
 integer              :: io_BS
 integer, external    :: variables_BS_more
 !
 call PP_redux_wait()
 !
 if(trim(mode)=="compressed_head".or.trim(mode)=="full") then
   if(write_is_on(ID)) then
     BS_K_has_been_calculated_loaded=l_kernel_complete
     l_BSE_kernel_complete          =l_kernel_complete.and.(io_BS_K.or.BS_K_cutoff>0._SP)
   endif
   if((write_is_on(ID_head).and.master_cpu).or.read_is_on(ID_head)) then
     io_BS=variables_BS_more(ID_head,'end')
     call io_disconnect(ID_head)
   endif
   if(read_is_on(ID)) then
     BS_K_has_been_calculated_loaded=l_kernel_complete
     l_BSE_kernel_complete          =l_kernel_complete.and.(io_BS_K.or.BS_K_cutoff>0._SP)
   endif
 endif
 !
 if(.not.io_BS_K .and. trim(mode)=="full" )      return
 !
 if(trim(mode)=="compressed_mat".or.trim(mode)=="full") call io_disconnect(ID)
 !
end subroutine
!
!
subroutine io_BS_PAR_block(iq,i_block,ID,mode)
 !
 ! Write one block of the BSE matrix to disk
 ! There is a single file for the full BSE matrix with maximum four variables
 ! for each of the four blocks that can be present (resonant, anti-resonant, coupling...)
 ! For each block only the upper triangular part is written
 ! Each block has a status variables indicating if the matrix element was already calculated
 !
 use pars,          ONLY:IP,IPL,SP,schlen
 use BS,            ONLY:BS_blk,BSK_IO_mode,MAX_BSK_LIN_size,n_BS_blks_min
 use timing_m,      ONLY:timing
 use IO_m,          ONLY:io_unit,netcdf_call,nf90_sync,&
&                        write_is_on,read_is_on,io_BS_K,YAMBO_CMPLX_NO_FILL
 use IO_int,        ONLY:io_variable_bulk
 !
 implicit none
 !
 integer,      intent(in) :: ID
 integer,      intent(in) :: iq,i_block
 character(*), intent(in) :: mode
 !
 ! Work Space
 !
 character(schlen)   :: BSK_IO_local
 logical             :: lwrite(3)
 integer             :: x1,x2,VAR_IDs(2),stat,ID_now(2)
 integer             :: n2,i1,i2,idx1,idx2,imax,i_rep(2),ilast
 integer(IPL)        :: idx
 !
 complex(SP), allocatable :: TMP_IO_VAR(:)
 !
 if( (.not.io_BS_K) .and. trim(mode)=="full") return
 !
 call timing('io_BS',OPR='start')
 !
 ! Get the type of block that we want to write 
 !
 select case(BS_blk(i_block)%mode)
 case("R")
   VAR_IDs=(/1,2/)
 case("C")
   VAR_IDs=(/3,4/)
 case("A")
   VAR_IDs=(/5,6/)
 end select
 !
 ! Get lower bound coordinates in 2D matrix
 x1=BS_blk(i_block)%coordinate(1)
 x2=BS_blk(i_block)%coordinate(2)
 !
 BSK_IO_local=trim(BSK_IO_mode)
 if(index(mode,"compressed")/=0) BSK_IO_local=trim(mode)
 !
 select case(trim(BSK_IO_local))
 case("1D_linear","compressed_head","compressed_mat")
   !
   do i2=1,BS_blk(i_block)%size(2)
     !
     if(trim(mode)=="compressed_mat") then
       idx = BS_blk(i_block)%idx_compr(i2)
       imax= count(BS_blk(i_block)%done(:,i2)=="t")
     else
       ! tmp coordinate in 2D matrix, runs from x2 to x2 + SIZE -1
       n2  = (x2+i2-1)
       !
       ! coordinate in linearized matrix n2*(n2-1)/2 counting all the elements of the
       ! triangular matrix as follow
       ! 1  2  4  7 11
       ! x  3  5  8 12
       ! x  x  6  9 
       ! x  x  x 10 
       idx = int(n2,kind=IPL)*int(n2-1,kind=IPL)/int(2,kind=IPL)+int(x1,kind=IPL)
       !
       ! number of rows from the first in the block to the diagonal of the matrix
       ! I'm going to write elements from idx to idx+imax-1
       imax=min(BS_blk(i_block)%size(1),n2-x1+1)
       !
     endif
     !
     if(imax<1) cycle
     !
     ! if idx > MAX_BSK_LIN_size switch to the next variable
     i_rep(1)=1+int((idx-int(1,IPL))/int(MAX_BSK_LIN_size,IPL),IP)
     ! if idx+imax  > MAX_BSK_LIN_size switch to the next variable
     i_rep(2)=1+int((idx+int(imax-2,IPL))/int(MAX_BSK_LIN_size,IPL),IP)
     ! I need both the previous two because a block can be written
     ! part on linear variable, part on the next
     !
     idx1= int(idx-int(MAX_BSK_LIN_size,IPL)*int(i_rep(1)-1,IPL),IP)
     !
     if(trim(mode)=="compressed_mat") then
       allocate(TMP_IO_VAR(imax))
       if(write_is_on(ID)) then
         idx=0
         do i1=1,BS_blk(i_block)%size(1)
           if( BS_blk(i_block)%done(i1,i2)/="t") cycle
           idx=idx+1
           TMP_IO_VAR(idx)=BS_blk(i_block)%mat(i1,i2)
         enddo
       endif
     endif
     !
     ! Write column by column in 1D
     !
     lwrite(1)=trim(mode)=="compressed_head"
     lwrite(2)=trim(mode)=="full"
     lwrite(3)=trim(mode)=="compressed_mat"
     !
     if(idx1+int(imax,IPL)-1<=MAX_BSK_LIN_size) then
       ! Block is all in one variable
       ID_now(1)=VAR_IDs(2)+(i_rep(1)-1)*8
       ID_now(2)=VAR_IDs(1)+(i_rep(1)-1)*8
       if(lwrite(1)) call io_variable_bulk(ID,ID_now(1), CH1=BS_blk(i_block)%done(:imax,i2), IPOS=[  idx1] )
       if(lwrite(2)) call io_variable_bulk(ID,ID_now(2),  C1=BS_blk(i_block)%mat(:imax,i2),  IPOS=[1,idx1] )
       if(lwrite(3)) call io_variable_bulk(ID,ID_now(2),  C1=TMP_IO_VAR,                     IPOS=[1,idx1] )
     else
       ! Block is split
       ilast=MAX_BSK_LIN_size-idx1+1
       if(lwrite(1)) then
         ID_now(1)=VAR_IDs(2)+(i_rep(1)-1)*8
         ID_now(2)=VAR_IDs(2)+(i_rep(2)-1)*8
         call io_variable_bulk(ID,ID_now(1), CH1=BS_blk(i_block)%done(:ilast,i2),       IPOS=[  idx1] )
         call io_variable_bulk(ID,ID_now(2), CH1=BS_blk(i_block)%done(ilast+1:imax,i2), IPOS=[     1] )
       endif
       if(lwrite(2)) then
         ID_now(1)=VAR_IDs(1)+(i_rep(1)-1)*8
         ID_now(2)=VAR_IDs(1)+(i_rep(2)-1)*8
         call io_variable_bulk(ID,ID_now(1),  C1=BS_blk(i_block)%mat(:ilast,i2),        IPOS=[1,idx1] )
         call io_variable_bulk(ID,ID_now(2),  C1=BS_blk(i_block)%mat(ilast+1:imax,i2),  IPOS=[1,   1] )
       endif
       if(lwrite(3)) then
         ID_now(1)=VAR_IDs(1)+(i_rep(1)-1)*8
         ID_now(2)=VAR_IDs(1)+(i_rep(2)-1)*8
         call io_variable_bulk(ID,ID_now(1),  C1=TMP_IO_VAR(:ilast),                    IPOS=[1,idx1] )
         call io_variable_bulk(ID,ID_now(2),  C1=TMP_IO_VAR(ilast+1:imax),              IPOS=[1,   1] )
       endif
     endif
     !
     if(trim(mode)=="full".and.read_is_on(ID)) then
       do i1=1,imax
         if(BS_blk(i_block)%mat(i1,i2)==YAMBO_CMPLX_NO_FILL) cycle
         BS_blk(i_block)%done(i1,i2)='t'
       enddo
     endif
     !
     if(trim(mode)=="compressed_mat") then
       if(read_is_on(ID)) then
         idx=0
         do i1=1,BS_blk(i_block)%size(1)
           if( BS_blk(i_block)%done(i1,i2)/="t") cycle
           idx=idx+1
           BS_blk(i_block)%mat(i1,i2)=TMP_IO_VAR(idx)
         enddo
       endif
       deallocate(TMP_IO_VAR)
     endif
     !
   enddo
   !
   if(trim(mode)=="compressed_mat") deallocate(BS_blk(i_block)%idx_compr)
   !
 case("2D_standard")
   ! 
   ! Write one block at a time in 2D
   !
   call io_variable_bulk(ID, VAR_IDs(1),  C2=BS_blk(i_block)%mat , IPOS=(/1,x1,x2/) )
   if(read_is_on(ID)) then
     do i2=1,BS_blk(i_block)%size(2)
       do i1=1,BS_blk(i_block)%size(1)
         if(BS_blk(i_block)%mat(i1,i2)==YAMBO_CMPLX_NO_FILL) cycle
         BS_blk(i_block)%done(i1,i2)='t'
       enddo
     enddo
   endif
   !
 end select
 !
 if(write_is_on(ID).and.i_block<=n_BS_blks_min) then
   stat = nf90_sync(io_unit(ID))
   call netcdf_call(stat,ID)
 endif
 !   
 call timing('io_BS',OPR='stop')
 !
end subroutine
