!----------------------------------------------------------------------------*
! This code is based on compact finite differences in x and y on non-uniform
! grids. The grid is staggered in x and y but at the moment in z it is collo
! cated. The fractional step method used is based on the method presented in
! Perot JCP 108 Analysis of the Fractional Step Method.
! Time integration is a third order Runge-Kutta scheme based on a paper by
! Spalart,Rogers&Moser JCP 96. The method is explicit for ALL terms in x and
! z but the viscous terms in the y-direction are implicit. 
! The pressure poisson will be solved using multigrid.
! This routine is an interface to viscop and pois:
!          viscop is the interface to the routines which calculate all
!                                    derivatives
!          pois   contains the routines which assures mass conservation.     
!          est    write statistics
!          escp   write restart files
!
! Mark Simens 22-4-2005
! Improvements by G.Hauet, J Jimenez, and myself.
! New Version, Sergio Hoyas.
!--------------------------------------------------------------------------*

! ==========================================================================
!                              AAACCCHHHTTTUUUNNNGGG
!   To correct a serious miskeying of p with the rest of the variables
!     that was now becoming very inconvenient,  p HAS BEEN CHANGED
!     p(i=nx) had no meaning, while p(i=1) was meaninful,
!     that was the oposite to everything else, for which
!     i=1 is the inflow condition, which is not integrated 
!        SAME with j
!     To have corresponding indices, I have shifted p by one
!         p(2:ny,2:nx)= p(1:ny,1:nx-1)
!         p(i=1) = 0
!         p(j=1) = 0
!     This version reads new I/O files with p in the new indexing
!     and written in cross (zy) planes. It also uses changes 
!     that are completely independent of xy planes.
!               JJS/01/10
! ==========================================================================

program capalimite
  use hdf5
  use ctesp

  implicit none
  include "mpif.h"

  integer ierr,mpiid,numprocs,i,j,k,new_mpiid
  integer h5err

  !----------------------------------------------------------------------*
  !       el proceso maestro llama a las rut. de inic. del codigo
  !----------------------------------------------------------------------*
 
  !       /*   initializes everything    */
  call MPI_INIT(ierr)
  call h5open_f(h5err)

  call MPI_COMM_RANK(MPI_COMM_WORLD,mpiid,ierr)
  call MPI_COMM_SIZE(MPI_COMM_WORLD,nummpi,ierr)
  numprocs = nummpi !Single boundary layer
  pnodes = nummpi

  call bl_1(mpiid)

  call mpi_barrier(mpi_comm_world,ierr)
  if (mpiid .eq. 0) then
     write(*,*)
     write (*,*) '=============================================='
     write (*,*) 'FINALIZING ALL THE PROCESSES: PROGRAM DONE'
     write (*,*) '=============================================='
  endif

  call h5close_f(h5err)
  call MPI_FINALIZE(ierr)

end program capalimite


!  =======================================
!    auxiliary to read input param. 
!  =======================================

subroutine avanza(text,unit)
  implicit none
  integer:: unit
  character*99 text
  do
     read(unit,'(a)') text     
     if(text(1:2)/='CC') exit
  enddo
endsubroutine avanza
! 
! ----------------------------------------------
! ----------------------------------------------
! ----------------------------------------------

subroutine summary1(istep,dt,vcontrol)
  use temporal
  use genmod
  use alloc_dns
  use statistics,only: ener
  implicit none
  logical:: vcontrol
  real*8::dt
  integer::istep,ierr
  ttotm = ttotm+tmp1
  ttotc = ttotc+tmp2
  ttotr = ttotr+tmp3
  ttotinty = ttotinty+ tmp4
  ttotvdx  = ttotvdx+   tmp5
  ttotintx = ttotintx+ tmp6
  ttotvy   = ttotvy+   tmp7
  ttotdy   = ttotdy+   tmp8
  ttotim   = ttotim+   tmp9
  ttotfft   = ttotfft+   tmp11
  ttotfftc   = ttotfftc+   tmp10
  ttotaux = ttotaux+tmp12
  ttotpois=ttotpois+tmp14
  ttotrhs=ttotrhs+tmp13
  tmpois=tmpois+tmp15
  tmrhs=tmrhs+tmp16
  ttotbou=ttotbou+tmp18
  ttotgen=ttotgen+tmp17
                  tred   =tred+tmp19
  ttot1=ttot1+tmp20
  ttot2=ttot2+tmp21
  ttot3=ttot3+tmp22
  ttot4=ttot4+tmp23
  ttot5=ttot5+tmp24
  ttot6=ttot6+tmp25
  ttot7=ttot7+tmp26
  ttot8=ttot8+tmp27
  ttot9=ttot9+tmp28

  write(*,*)
  write(*,'(a10,i8,2E20.10,a30,2f14.4)')  'BL1: step',istep, dt,tiempo,'Re_theta: in/out-ref',rthin,rthout
  write(*,'(a35,3f10.4)')  'BL1: tiempos: Trans,Comm,Total Step',tmp3,tmp2,tmp1-tmp27-tmp28
  write(*,'(a35,2f10.4)')  'BL1: ffts: fft, cos', tmp11,tmp10
#ifdef CHECKTIME
!!!!!!!!!!!!!!! ONLY FOR 1 PLANE PER NODE !!!!!!!!!!!! CHECKING THE CORRECT TIMING
  if(tmp1-tmp27-tmp28.gt.251) then
  WRITE(*,*) '======== EXCESIVE TIME ============== NOW stopping'
  vcontrol=.true.
  endif
#endif
  write(*,*)
  write(32,'(20d22.14)') tiempo,dt,ener(1:15),tmp2,tmp1
  call flush(32)
  tmp1  =0d0; tmp4=0d0; tmp7=0d0; tmp10=0d0; tmp13=0d0;tmp16=0d0;tmp19=0d0;tmp22=0d0;tmp25=0d0;tmp28=0d0
  tmp2  =0d0; tmp5=0d0; tmp8=0d0; tmp11=0d0; tmp14=0d0;tmp17=0d0;tmp20=0d0;tmp23=0d0;tmp26=0d0;!tmp29=0d0
  tmp3  =0d0; tmp6=0d0; tmp9=0d0; tmp12=0d0; tmp15=0d0;tmp18=0d0;tmp21=0d0;tmp24=0d0;tmp27=0d0;tmp30=0d0     

end subroutine summary1

subroutine summary2()
  use temporal
  use ctesp
  use point
  implicit none
  ttotm=ttotm+tmp29 !tmp29: reading time
  
  write(*,*) '==============================================================='
  write(*,'(a40,1f10.0,a2)') 'BL1: TOTAL MEM ALLOCATED FIRST BL (node):',totmem,'Mb'
  write(*,*) 'Size, Nodes, Threads',nx,ny,nz,nummpi,nthreads
  write(*,*) '---------------------------------------------------------------'
  write(*,'(a30,f15.4)') 'tiempo total: ', ttotm
  write(*,*) '---------------------------------------------------------------'
  write(*,'(a30,2f15.4,a2)') 'Reading Fields (u,v,w,p)', tmp29, tmp29/ttotm*100,'%'  
  write(*,'(a30,2f15.4,a2)') 'Writing Fields (u,v,w,p)', ttot9, ttot9/ttotm*100,'%'
  write(*,'(a30,2f15.4,a2)') 'Writing Statistics & Spectra', ttot8, ttot8/ttotm*100,'%'
  write(*,*) '---------------------------------------------------------------'     
  write(*,'(a30,2f15.4,a2)') 'Poisson Subroutine', ttotpois, ttotpois/ttotm*100,'%'
  write(*,'(a30,2f15.4,a2)') 'RHS Subroutine'    , ttotrhs, ttotrhs/ttotm*100,'%'
  write(*,'(a30,2f15.4,a2)') 'Outflow Subroutine'  , ttotbou, ttotbou/ttotm*100,'%'

       write(*,'(a30,2f15.4,a2)') 'Genflu Subroutine' , ttotgen, ttotgen/ttotm*100,'%'
  write(*,*) '---------------------------------------------------------------'
  write(*,'(a30,2f15.4,a2)') 'transpuestas  '     , ttotr, ttotr/ttotm*100,'%'
  write(*,'(a30,2f15.4,a2)') 'comm Changes       ', ttotc, ttotc/ttotm*100,'%'     
  write(*,'(a30,2f15.4,a2)') 'Poisson Com 1st S/R' , tmpois, tmpois/ttotm*100,'%'
  write(*,'(a30,2f15.4,a2)') 'Poisson Com 2nd S/R' , ttot4, ttot4/ttotm*100,'%'
  write(*,'(a30,2f15.4,a2)') 'RHS Com'     , tmrhs, tmrhs/ttotm*100,'%'
       write(*,'(a30,2f15.4,a2)') 'Time Inside Bound', tred, tred/ttotm*100,'%'
  write(*,*) '----------------------------------------------------------------'
  write(*,'(a30,2f15.4,a2)') 'Inside genflu Master', ttot2, ttot2/ttotm*100,'%'
      write(*,'(a30,2f15.4,a2)') 'Genflu inside max', ttot3, ttot3/ttotm*100,'%'
  write(*,'(a30,2f15.4,a2)') 'Inside genflu Send/Rec', ttot5, ttot5/ttotm*100,'%'
  write(*,'(a30,2f15.4,a2)') 'Inside genflu Inter Loop', ttot6, ttot6/ttotm*100,'%'
  write(*,'(a30,2f15.4,a2)') 'Inside genflu K     Loop', ttot7, ttot7/ttotm*100,'%'

  write(*,'(a30,2f15.4,a2)') 'Time Step Allreduce', ttot1, ttot1/ttotm*100,'%'
  write(*,*) '----------------------------------------------------------------'
  write(*,'(a30,2f15.4,a2)') 'interpy       ', ttotinty, ttotinty/ttotm*100,'%'
  write(*,'(a30,2f15.4,a2)') 'interpx       ', ttotintx, ttotintx/ttotm*100,'%'
  write(*,'(a30,2f15.4,a2)') 'T.Implici     ', ttotim, ttotim/ttotm*100,'%'
  write(*,'(a30,2f15.4,a2)') 'diff_y        ', ttotdy, ttotdy/ttotm*100,'%'
  write(*,'(a30,2f15.4,a2)') 'vis_yy        ', ttotvy, ttotvy/ttotm*100,'%'
  write(*,'(a30,2f15.4,a2)') 'vis_xx+dif_x  ', ttotvdx,ttotvdx/ttotm*100,'%'
  write(*,*) '----------------------------------------------------------------'
  write(*,'(a30,2f15.4,a2)') 'cos transform ', ttotfftc,ttotfftc/ttotm*100,'%'
  write(*,'(a30,2f15.4,a2)') 'cos transform2 ', ttotaux,ttotaux/ttotm*100,'%'
  write(*,'(a30,2f15.4,a2)') 'fft           ', ttotfft, ttotfft/ttotm*100,'%'
  write(*,*) '================================================================='

!        open(31,file='tiempo.dat',status='unknown',convert='BIG_ENDIAN')
!        write(31,*) numprocs,nthreads,blockl,nx,ny,nz,nsteps,real(ttotm),&
!                    &real(ttotc),real(ttotr),real(ttotinty),real(ttotintx),&
!                    &real(ttotim),real(ttotdy),real(ttotvy),real(ttotvdx),&
!                    &real(ttotfft),real(ttotfftc)
end subroutine summary2


