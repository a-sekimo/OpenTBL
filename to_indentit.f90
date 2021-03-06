  
  
#ifdef CREATEPROFILES
  subroutine create_profiles(rthin,mpiid)
    use alloc_dns,only: re,pi,ax,y,dy,idy,idx,inyv,cofivy,inby
    use point
    use ctesp
    implicit none
    include "mpif.h"

    real*8,dimension(nx)::x,dstar,reth,uep,utau,drota
    real*8,dimension(:,:),allocatable:: u_composite,v_composite,dudx,buffer
    real*8,dimension(ny+1):: eta,yplus,uinnerp,ulogp,Exp1,wouterp,uinfp,uouterp,ucomp,ucompi
    real*8 e1,c1,ei1,kap,ckap,cprim,rd,d1,ee1,ee2,ee3,ee4,ee5,eulcns
    real*8 rx,dx,rthin,w0,w1,w2,w8
    integer i,j,mpiid,dot,ierr,status(MPI_STATUS_SIZE)

    !Every node allocate the buffer:
    allocate(buffer(1:ny+1,2));buffer=0d0
    !Every node allocate the array for U0 & V0:
    allocate(u0c(1:ny+1,ib:ie),v0c(1:ny+1,ib:ie));u0c=0d0;v0c=0d0

    if(mpiid.eq.0) then
       write(*,*) 'VALORES INICIALES: Rtheta_in:',rthin,'Num_planes=',num_planes
       allocate(u_composite(ny+1,num_planes+1),v_composite(ny,num_planes+1),dudx(ny,num_planes))

       u_composite=0d0;v_composite=0d0;dudx=0d0
       uinnerp=0d0;ulogp=0d0;Exp1=0d0;wouterp=0d0;uinfp=0d0;uouterp=0d0
       ucomp=0d0;ucompi=0d0
       x=0d0;dstar=0d0;reth=0d0;uep=0d0;
       eta=0d0;yplus=0d0

       !CONSTANTS FOR THE FITTINGS 
       e1=0.8659d0; c1=0.01277d0;   !!reth=c1*rex^e1
       ei1=1/e1
       kap=0.384d0; ckap=4.127d0;   !! uep=log(reth)/kap+ckap 
       cprim=7.135d0              
       dx=ax*pi/(nx-1)
       !CONSTANTS FOR THE COMPOUND PROFILE
       d1=4.17d0;
       eulcns=0.57721566d0;
       ee1=0.99999193d0;ee2=0.24991055d0;ee3=0.05519968d0;
       ee4=0.00976004d0;ee5=0.00107857d0;
       w0=0.6332d0;w1=-0.096d0;
       w2=28.5d0;  w8=33000d0;

       do i=1,num_planes+1
          !Computing X grid --> Re_x --> Re_theta --> Uinf+ --> u_tau --> H --> delta_star --> delta_rota 
          x(i)=dx*(i-1)
          reth(i)=(rthin**ei1+c1**ei1*re*x(i))**e1
          uep(i)= log(reth(i))/kap+ckap  
          dstar(i)=reth(i)/((1-cprim/uep(i))*re)
          utau(i)=Uinfinity/uep(i)
          drota(i)=uep(i)*dstar(i)
          eta(1:ny+1)=y(1:ny+1)/drota(i)
          yplus(1:ny+1)=y(1:ny+1)*re*utau(i)

          if(i.eq.30) then
             write(*,*) '======= VALUES @ i=30 =================='
             write(*,*) 'x',x(i)
             write(*,*) 'reth(i)',reth(i)
             write(*,*) 'uep(i)',uep(i)
             write(*,*) 'dstar(i)',dstar(i)
             write(*,*) 'drota(i)',drota(i) 
             write(*,*) '========================================'             
          endif

          !==============Composing the profiles===============
          !INNER REGION------------------------------------------
          uinnerp(:)=0.68285472*log(yplus(:)**2 +4.7673096*yplus(:) +9545.9963)+&
               &  1.2408249*atan(0.010238083*yplus(:)+0.024404056)+&
               &  1.2384572*log(yplus(:)+95.232690)-11.930683-&
               &  0.50435126*log(yplus(:)**2-7.8796955*yplus(:)+78.389178)+&
               &  4.7413546*atan(0.12612158*yplus(:)-0.49689982)&
               &  -2.7768771*log(yplus(:)**2+16.209175*yplus(:)+933.16587)+&
               &  0.37625729*atan(0.033952353*yplus(:)+0.27516982)+&
               &  6.5624567*log(yplus(:)+13.670520)+6.1128254   !Eq(6)     
          !LOG PART ------------------------------------------
          ulogp(:)=1d0/kap*log(yplus(:))+d1;  
          !OUTER REGION------------------------------------------
          Exp1(:)=-eulcns-log(eta(:))+ee1*eta(:)-ee2*eta(:)**2+&
               &       ee3*eta(:)**3-ee4*eta(:)**4+ee5*eta(:)**5   !Eq(8)
          wouterp(:)=(1/kap*Exp1(:)+w0)*0.5d0*(1-tanh(w1/eta(:)+w2*eta(:)**2+w8*eta(:)**8)) !Eq(9)
          !Matching---------------------------------------------
          uinfp(:)=1/kap*log(dstar(i)*re)+3.30d0   !Eq(11)
          uouterp(:)=uinfp(:)-wouterp(:)
          !Compouse profile:
          ucomp(:)=uinnerp(:)*uouterp(:)/ulogp(:) !At V position @the cell (u(1)=0d0)
          ucomp(1)=0d0; !Removing singularity @the wall

          !    ucompi(2:ny+1)=0.5d0*(ucomp(1:ny)+ucomp(2:ny+1)) !Interpolated
          !    ucompi(1)=-ucompi(2)
          call interpyy(ucomp(1),u_composite(1,i),inyv,cofivy,inby,ny+1,1,1,1)    
          u_composite(:,i)=u_composite(:,i)*utau(i)
          u_composite(ny+1,i)=u_composite(ny,i)  !Adding ny+1 point        
       enddo

       !Deriving the V0 composite profile:
       v_composite(:,1)=0d0 !Initial Condition

       do j=1,ny-1
          do i=1,num_planes
             dudx(j,i)=idx*(u_composite(j+1,i+1)-u_composite(j+1,i)) !dudx @ (i,j)
          enddo
       enddo

       do i=1,num_planes
          do j=1,ny-1
             v_composite(j+1,i)=-dudx(j,i)/idy(j)+v_composite(j,i)
          enddo
       enddo
       write(*,*) 'Writting composite profiles U0 & V0 in file: extraprofiles '
       write(17) u_composite(1:ny+1,1:num_planes),v_composite(1:ny,1:num_planes)

       !===================Send Info to other nodes============================
       !Node #0 copy its data
       do i=ib,ie  
          if(i.le.num_planes) then
             u0c(1:ny+1,i)=u_composite(1:ny+1,i)
             v0c(1:ny,i)  =v_composite(1:ny  ,i)          
          endif
       enddo

       !Sending U0 and V0 to the nodes:
       write(*,*) 'Sending the composite profiles U0 & V0'
       do dot = 1,nummpi-1
          do i= ibeg(dot),iend(dot)
             if(i.le.num_planes) then
                buffer(1:ny+1,1)=u_composite(1:ny+1,i)
                buffer(1:ny  ,2)=v_composite(1:ny  ,i)   
                call MPI_SEND(buffer,size(buffer),MPI_real8,dot,1,MPI_COMM_WORLD,ierr)             
             endif
          enddo
       enddo
       write(*,*) 'Sending the composite profiles U0 & V0...... DONE'
       !Node #0 free the memory:
       deallocate(u_composite,v_composite,dudx)
    else
       !Receiving the U0 & V0 profiles:
       do i=ib,ie
          if(i.le.num_planes) then
             call MPI_RECV(buffer,size(buffer),MPI_real8,0,1,MPI_COMM_WORLD,status,ierr)
             u0c(1:ny+1,i)=buffer(1:ny+1,1)
             v0c(1:ny,i)  =buffer(1:ny  ,2)   
          endif
       enddo
    endif

    deallocate(buffer)

  endsubroutine create_profiles


  !===========================================================================================
  !===========================================================================================
  !===========================================================================================


  subroutine impose_profiles(ut,vt,wt)
    use point
    use ctesp
    implicit none

    complex*16,dimension(0:nz2,ny+1,ib:ie)::ut,wt
    complex*16,dimension(0:nz2,ny  ,ib:ie)::vt
    integer:: i

    do i=ib,ie
       if(i.le.num_planes) then
          ut(0,1:ny+1,i)=u0c(1:ny+1,i)   !The imaginary part is then set to 0
          vt(0,1:ny  ,i)=v0c(1:ny  ,i) 
          wt(0,1:ny+1,i)=0d0 
       endif
    enddo
  endsubroutine impose_profiles
#endif

