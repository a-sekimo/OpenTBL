  !=====================================================================
  !       Genera o lee las condiciones iniciales (Campos u,v,w,p)
  !       Inicializa las arrays para estadisticas
  !	Lee la malla en la direccion Y
  !
  ! Lee todos los planos YX donde estan los campos y la presion en R*4 y
  ! los copia en R*8 en los buffers (u,v,w,p). 
  !
  !  El master se copia su campo correspondiente y luego envia como R*4 los trozos a
  !  los otros cores que se lo copian como R*8
  !
  !       ACHTUNG!!    allocates one input plane, check there is space
  !==========================================================================
  
  
#define MB *1024*1024
#define MAXPE 64*1024
#define MAXCHARLEN 250
  
  subroutine getstartzy(u,v,w,p,dt,mpiid)
    use alloc_dns
    use statistics
    use names
    use point
    use genmod
    use ctesp
    implicit none
    include "mpif.h"
    ! ---------------------------- I/O -----------------------------------!
    real(8),dimension(nz1,ny,ib:ie)  :: v,p
    real(8),dimension(nz1,ny+1,ib:ie):: u,w
    real*4, dimension(:,:,:),allocatable:: resu 
    ! -------------------------- Work ----------------------------------------!
    integer status(MPI_STATUS_SIZE),ierr,mpiid,commu,tipo,sidio,nfile,mpiw1,mpiw2,mpiw3,mpiw4
    integer nxr,nyr,nzr,nz1r,nzz,j,i,k,l,dot,lim2,rsize,irec,rsize1,rsize2,ji
    integer*8:: chunks1,chunks2,chunksM1,chunksM2,chunkfbs
    real(8) jk,dt,dum(20)
    real*8,dimension(:),allocatable::dummy
    character text*99, uchar*1
    character(len=MAXCHARLEN),intent(out):: fil1,fil2,fil3,fil4

    ! --------------------------  Programa  ----------------------------------!
    commu=MPI_COMM_WORLD
    tipo=MPI_real4

    fil1=chinit(1:index(chinit,' ')-1)//'.'//'u'
    fil2=chinit(1:index(chinit,' ')-1)//'.'//'v'
    fil3=chinit(1:index(chinit,' ')-1)//'.'//'w'
    fil4=chinit(1:index(chinit,' ')-1)//'.'//'p'


#ifdef RPARALLEL
    nfile=1			    !Number of files for parallel IO
    chunkfbs=2*1024*1024            !File block system 2Mb
    chunks1 =nz1*(ny+1)*(ie-ib+1)*4  !Number of bytes in R4 for LocalBuffer
    chunks2 =nz1*(ny  )*(ie-ib+1)*4  !Number of bytes in R4 for LocalBuffer
    chunksM1=nz1*(ny+1)*(ie-ib+1+1)*4  !Number of bytes in R4 for the Master Node
    chunksM2=nz1*(ny  )*(ie-ib+1+1)*4  !Number of bytes in R4 for the Master Node

    if(mpiid.eq.0) then      
       write(*,*) '-------------------------CHUNKS (Mb)---------------------------------------------------'
       write(*,*) '              chunks1          chunks2         chunksM1          chunksM2         chunkfbs'
       write(*,'(5F18.3)') 1.0*chunks1/1024/1024,1.0*chunks2/1024/1024,1.0*chunksM1/1024/1024,1.0*chunksM2/1024/1024,1.0*chunkfbs/1024/1024
       write(*,*) '----------------------------------------------------------------------------------'
    endif
    !PARALLEL WRITTER ==================================================================
    !First the header and last the field
    if(mpiid.ne.0) then       
       allocate (resu(nz1,ny+1,ie-ib+1),stat=ierr);resu=0 !R4 buffer to convert R8 variables
       if(ierr.ne.0) write(*,*) "ERROR ALLOCATING RESU"       
       !Reading u:              
       call blockread(fil1,commu,resu,chunks1,nfile,mpiid,sidio)     
       u=real(resu,kind=8)      
       !Reading v:           
       call blockread (fil2,commu,resu(:,1:ny,:),chunks2,nfile,mpiid,sidio)    
       v=real(resu(:,1:ny,:),kind=8)    
       !Reading w:       
       call blockread (fil3,commu,resu,chunks1,nfile,mpiid,sidio) 
       w=real(resu,kind=8)    
       !Reading p:         
       call blockread (fil4,commu,resu(:,1:ny,:),chunks2,nfile,mpiid,sidio)  
       p=real(resu(:,1:ny,:),kind=8)       
       deallocate (resu)        
    else      
       allocate (resu(nz1,ny+1,(ie-ib+1)+1),stat=ierr);resu=0 !R4 buffer to convert R8 variables
       if(ierr.ne.0) write(*,*) "ERROR ALLOCATING RESU"      
       write(*,'(a75,f10.4,a3)') 'Size of the allocated buffer in order to read:',size(resu)*4.0/1024/1024,'Mb'           
       !Reading u:    
       call readheader(fil1)        
       call blockread (fil1,commu,resu,chunksM1,nfile,mpiid,sidio)     
       u =real(resu(:,:,2:),kind=8)
       u0=real(resu(1,:,2 ),kind=8)              
       !         write(*,*) 'Reading from file u0-Nagib:'
       !         open (110,file='u0-nagib',form='unformatted',status='old')
       !         read(110) u0(1:ny+1)
       !         close(110)    

       !Reading v:       
       call blockread (fil2,commu,resu(:,1:ny,:),chunksM2,nfile,mpiid,sidio)             
       v= real(resu(:,1:ny,2:),kind=8)
       v0=real(resu(1,1:ny,2 ),kind=8)
!                 write(*,*) 'Reading from file V0-Nagib:'
!                 open (110,file='v0-nagib',form='unformatted',status='old')
!                 read(110) v0(1:ny)
!                 close(110) 
!        v0=v0/v0(ny)*vmagic(1)
       !Reading w:         
       call blockread (fil3,commu,resu,chunksM1,nfile,mpiid,sidio)      
       w=real(resu(:,:,2:),kind=8)  
       !Reading p:       
       call blockread (fil4,commu,resu(:,1:ny,:),chunksM2,nfile,mpiid,sidio)             
       p=real(resu(:,1:ny,2:),kind=8) 
       deallocate (resu)            
       write(*,*)
       write(*,*) '=========================================================================='
       write(*,*) 'Done Reading', trim(chinit),' fields'
       write(*,*) '=========================================================================='
    endif

      call MPI_BARRIER(commu,ierr)
      if(mpiid.eq.0) write(*,*) 'cambiando los perfiles:'
! !   Fixing PROFILES
!     if(ib.le.500 .and. ie.ge.500) then
!         write(*,*) 'soy el id...bucle1',mpiid,ib,ie
!         do j=251,ny+1
!            u(:,j,500:ie)=u(:,250,500:ie)
!         enddo  !copying last point
!     elseif (ib.gt.500 .and. ie.le.700) then
!     write(*,*) 'soy el id...bucle2',mpiid,ib,ie
!         do j=251,ny+1
!            u(:,j,:)=u(:,250,:)
!         enddo
!     elseif (ib.le.700 .and. ie.ge.700) then
!     write(*,*) 'soy el id...bucle3',mpiid,ib,ie
!         do j=251,ny+1
!            u(:,j,ib:700)=u(:,j,ib:700)
!         enddo
!     endif



#endif


#ifdef RSERIAL
    !       lee el fichero 
    if (mpiid.eq.0) then
       write(*,*) 'Leyendo del fichero'
       write(*,*) fil1     
       rsize=2*nz2*(ny+1)*4    
       open (20,file=fil1,status='old',form='unformatted',access='direct',recl=rsize)
       write(*,*) 'BG: file open, reading tiempo and dimensions'
       read(20,rec=1) uchar,tiempo,jk,jk,jk,jk,jk,nxr,nyr,nzr
       write(*,*) '==========================================='
       write(*,*) 'in file    ', uchar,tiempo,nxr,nyr,nzr
       write(*,*) 'in ctes    ',nx,ny,nz2
       close(20)          
    endif

    call MPI_BCAST(nxr,1,mpi_integer,0,commu,ierr)
    call MPI_BCAST(nzr,1,mpi_integer,0,commu,ierr)
    call MPI_BCAST(nyr,1,mpi_integer,0,commu,ierr)

    if (ny.ne.nyr) then
       if (mpiid==0) write(*,*) 'changing the y grid has to be done separately'
       if (mpiid==0) write(*,*) 'ny=',ny,'nyr',nyr
       stop
    elseif (nx.ne.nxr) then
       if (mpiid==0) write(*,*) 'changing the x grid has to be done separately'
       if (mpiid==0) write(*,*) 'nx=',nx,'nxr',nxr
    endif

    u = 0d0
    v = 0d0
    w = 0d0
    p = 0d0

    nz1r=2*(nzr+1) 
    rsize = nz1r*(ny+1)*4
    rsize1 = nz1r*(ny+1)
    rsize2 = nz1r*(ny  )

!     nzz = min(nz1r,nz1)
    nzz = nz1r !now nz1r can be > than nz1.
    allocate (resu(nz1r,ny+1,4))

    if (mpiid.eq.0) then

       open (10,file=fil1,status='unknown', &
            & form='unformatted',access='direct',recl=rsize1*4)          
   
#ifdef OLDHEADER
!%%%%%%%%%%%%%%%%%%%%% viejas o nuevas cabeceras! %%%%%%%%%%%%%%%%%%%%
       allocate(dummy(0:nxr+1))
       read(10,rec=1) uchar,tiempo,jk,jk,jk,jk,jk,nxr,nyr,nzr,ji,timeinit,dt, &
          & dum, (dummy(i), i=0,nxr+1), (y(i), i=0,nyr+1), (um(i), i=1,nyr+1)
#else
       read(10,rec=1) uchar,tiempo,jk,jk,jk,jk,jk,nxr,nyr,nzr,ji,timeinit,dt, &
            & (y(i), i=0,nyr+1), (um(i), i=1,nyr+1)
       
#endif
!%%%%%%%%%%%%%%%%%%%%% viejas o nuevas cabeceras! %%%%%%%%%%%%%%%%%%%%

       write(*,*) 'in file    ', uchar,tiempo,nxr,nyr,nzr
       write(*,*) '              x                   y                  um'
       write(*,*) '--------------------------------------------------------------------'      
       do i=1,10
          write(*,'(3f20.6)') x(i),y(i),um(i)
       enddo
       !opening rest of the files: 

       open (11,file=fil2,status='unknown', &
            & form='unformatted',access='direct',recl=rsize2*4)
       open (12,file=fil3,status='unknown', &
            & form='unformatted',access='direct',recl=rsize1*4)
       open (13,file=fil4,status='unknown', &
            & form='unformatted',access='direct',recl=rsize2*4)
       write(*,*) '----- files OPEN ------'
       write(*,*) fil1
       write(*,*) fil2
       write(*,*) fil3
       write(*,*) fil4
    endif

    if (mpiid.eq.0) then
       irec=1
       !!  start reading the flow field  
       do i=ib,ie                
          irec = irec+1
          read(10,rec=irec) resu(1:nzz,1:ny+1,1)
          read(11,rec=irec) resu(1:nzz,1:ny,2)
          read(12,rec=irec) resu(1:nzz,1:ny+1,3)
          read(13,rec=irec) resu(1:nzz,1:ny,4)

          u(1:nz1,1:ny+1,i) = resu(1:nz1,1:ny+1,1)
          v(1:nz1,1:ny,i)   = resu(1:nz1,1:ny,2)
          w(1:nz1,1:ny+1,i) = resu(1:nz1,1:ny+1,3)
          p(1:nz1,1:ny,i)   = resu(1:nz1,1:ny,4)

          if (i==1) then
             u0=resu(1,:,1)
             v0=resu(1,1:ny,2)
          endif
       enddo

       do dot = 1,nummpi-1   ! -- read for the other nodes 
          do i= ibeg(dot),iend(dot)
             if (mod(i,200).eq.0) write(*,*) 'Read & Send up to:',i         
             irec = irec+1
             read(10,rec=irec) resu(1:nzz,1:ny+1,1)
             read(11,rec=irec) resu(1:nzz,1:ny,2)
             read(12,rec=irec) resu(1:nzz,1:ny+1,3)
             read(13,rec=irec) resu(1:nzz,1:ny,4)
             call MPI_SEND(resu,rsize,tipo,dot,1,commu,ierr)                    
          enddo
       enddo
       close(10);close(11);close(12);close(13)
       call flush(6)
    else  !   --- the other nodes receive the information  
       do i=ib,ie       
          call MPI_RECV(resu,rsize,tipo,0,1,commu,status,ierr)
          u(1:nz1,1:ny+1,i) = resu(1:nz1,1:ny+1,1)
          v(1:nz1,1:ny,i)   = resu(1:nz1,1:ny,2)
          w(1:nz1,1:ny+1,i) = resu(1:nz1,1:ny+1,3)
          p(1:nz1,1:ny,i)   = resu(1:nz1,1:ny,4)                
       enddo
    endif
    deallocate(resu)
#endif

#ifdef RSERIAL4
    !MPI Readers nodes:
    mpiw1=0
    mpiw2=nummpi/4
    mpiw3=nummpi/2
    mpiw4=3*nummpi/4
    !       lee el fichero 
    if (mpiid.eq.mpiw1) then
       write(*,*) 'Leyendo del fichero'
       write(*,*) fil1     
       rsize=2*nz2*(ny+1)*4    
       open (20,file=fil1,status='old',form='unformatted',access='direct',recl=rsize)
       write(*,*) 'BG: file open, reading tiempo and dimensions'
       read(20,rec=1) uchar,tiempo,jk,jk,jk,jk,jk,nxr,nyr,nzr
       write(*,*) '==========================================='
       write(*,*) 'in file    ', uchar,tiempo,nxr,nyr,nzr
       write(*,*) 'in ctes    ',nx,ny,nz2
       close(20)          
    endif

    call MPI_BCAST(nxr,1,mpi_integer,0,commu,ierr)
    call MPI_BCAST(nzr,1,mpi_integer,0,commu,ierr)
    call MPI_BCAST(nyr,1,mpi_integer,0,commu,ierr)

    if (ny.ne.nyr) then
       if (mpiid==0) write(*,*) 'changing the y grid has to be done separately'
       if (mpiid==0) write(*,*) 'ny=',ny,'nyr',nyr
       stop
    elseif (nx.ne.nxr) then
       if (mpiid==0) write(*,*) 'changing the x grid has to be done separately'
       if (mpiid==0) write(*,*) 'nx=',nx,'nxr',nxr
    endif

    u = 0d0;v = 0d0;w = 0d0;p = 0d0

    nz1r   = 2*(nzr+1) 
    rsize  = nz1r*(ny+1)*4
    rsize1 = nz1r*(ny+1)
    rsize2 = nz1r*(ny  )

    nzz = min(nz1r,nz1)
    allocate (resu(nz1r,ny+1,4))

    if (mpiid.eq.mpiw1) then
       open (10,file=fil1,status='unknown', &
            & form='unformatted',access='direct',recl=rsize1*4)          
       read(10,rec=1) uchar,tiempo,jk,jk,jk,jk,jk,nxr,nyr,nzr,ji,timeinit,dt, &
            & (y(i), i=0,nyr+1), (um(i), i=1,nyr+1)
       write(*,*) 'in file    ', uchar,tiempo,nxr,nyr,nzr
       write(*,*) '              x                   y                  um'
       write(*,*) '--------------------------------------------------------------------'      
       do i=1,10
          write(*,'(3f20.6)') x(i),y(i),um(i)
       enddo
       irec=1
       !!  start reading the flow field  
       do i=ib,ie                
          irec = irec+1
          read(10,rec=irec) resu(1:nzz,1:ny+1,1)         
          u(1:nzz,1:ny+1,i) = resu(1:nzz,1:ny+1,1)        
          if (i==1) then
             u0=resu(1,:,1)            
          endif
       enddo
       do dot = 1,nummpi-1   ! -- read for the other nodes 
          do i= ibeg(dot),iend(dot)
             if (mod(i,200).eq.0) write(*,*) 'U: Read & Send up to:',i         
             irec = irec+1
             read(10,rec=irec) resu(1:nzz,1:ny+1,1)           
             call MPI_SEND(resu(:,:,1),rsize1,tipo,dot,1,commu,ierr)                    
          enddo
       enddo
       close(10);

    else  !   --- the other nodes receive the information  
       do i=ib,ie       
          call MPI_RECV(resu(:,:,1),rsize1,tipo,0,1,commu,status,ierr)
          u(1:nzz,1:ny+1,i) = resu(1:nzz,1:ny+1,1)                    
       enddo
    endif

    !-----------------------------------
    if (mpiid.eq.mpiw2) then    
       open (11,file=fil2,status='unknown', &
            & form='unformatted',access='direct',recl=rsize2*4)
       irec=1
       !!  start reading the flow field  
       do i=ib,ie                
          irec = irec+1       
          read(11,rec=irec) resu(1:nzz,1:ny,2)                 
          v(1:nzz,1:ny,i)   = resu(1:nzz,1:ny,2)         
          if (i==1) then
             u0=resu(1,:,1)          
          endif
       enddo

       do dot = 0,nummpi-1   ! -- read for the other nodes
          if(dot.ne.mpiw2) then 
             do i= ibeg(dot),iend(dot)   
             if (mod(i,200).eq.0) write(*,*) 'V: Read & Send up to:',i                  
                irec = irec+1             
                read(11,rec=irec) resu(1:nzz,1:ny,2)           
                call MPI_SEND(resu(:,:,2),rsize1,tipo,dot,2,commu,ierr)                    
             enddo
          endif
       enddo
       close(11)      
    else  !   --- the other nodes receive the information  
       do i=ib,ie       
          call MPI_RECV(resu(:,:,2),rsize1,tipo,0,2,commu,status,ierr)         
          v(1:nzz,1:ny,i)   = resu(1:nzz,1:ny,2)                       
       enddo
    endif
    !-----------------------------------
    if (mpiid.eq.mpiw3) then
       open (12,file=fil3,status='unknown', &
            & form='unformatted',access='direct',recl=rsize1*4)
       irec=1
       !!  start reading the flow field  
       do i=ib,ie                
          irec = irec+1         
          read(12,rec=irec) resu(1:nzz,1:ny+1,3)                  
          w(1:nzz,1:ny+1,i) = resu(1:nzz,1:ny+1,3)               
       enddo
       do dot = 0,nummpi-1  
          if(dot.ne.mpiw3) then
             do i= ibeg(dot),iend(dot) 
             if (mod(i,200).eq.0) write(*,*) 'W: Read & Send up to:',i                   
                irec = irec+1          
                read(12,rec=irec) resu(1:nzz,1:ny+1,3)            
                call MPI_SEND(resu(:,:,3),rsize1,tipo,dot,3,commu,ierr)                    
             enddo
          endif
       enddo
       close(12)     
    else   
       do i=ib,ie       
          call MPI_RECV(resu(:,:,3),rsize1,tipo,0,3,commu,status,ierr)         
          w(1:nzz,1:ny+1,i) = resu(1:nzz,1:ny+1,3)               
       enddo
    endif
    !-----------------------------------
    if (mpiid.eq.mpiw4) then
       open (13,file=fil4,status='unknown', &
            & form='unformatted',access='direct',recl=rsize2*4)
       irec=1      
       do i=ib,ie                
          irec = irec+1         
          read(13,rec=irec) resu(1:nzz,1:ny,4)         
          p(1:nzz,1:ny,i)   = resu(1:nzz,1:ny,4)
       enddo
  
          do dot = 0,nummpi-1 
             if(dot.ne.mpiw4) then 
                do i= ibeg(dot),iend(dot)
                if (mod(i,200).eq.0) write(*,*) 'UV: Read & Send up to:',i                            
                   irec = irec+1             
                   read(13,rec=irec) resu(1:nzz,1:ny,4)
                   call MPI_SEND(resu(:,:,4),rsize1,tipo,dot,4,commu,ierr)                    
                enddo
             endif
          enddo
          close(13)      
       else   
          do i=ib,ie       
             call MPI_RECV(resu(:,:,4),rsize1,tipo,0,4,commu,status,ierr)          
             p(1:nzz,1:ny,i)   = resu(1:nzz,1:ny,4)                
          enddo
       endif 

       call MPI_BARRIER(commu,ierr)
       deallocate(resu)
#endif


       if(mpiid.eq.0) then 
          !         write(*,*) "Reading Y from file...."
          !         open (110,file='ybg713',form='unformatted',status='old')
          !         read(110) (y(i), i=0,ny+1)
          !         close(110)    
          write(*,*) 'Values of Y grid and Um after reading:'
          write(*,*) '      y            um      u0            v0     ' 
          write(*,*) '---------------------------------'    
          do i=1,4   
             write(*,'(4f12.9)') y(i-1),um(i),u0(i),v0(i)
          enddo
          write(*,*) '---------------------------------'    
          do i=ny-3,ny+1   
             write(*,'(4f12.9)') y(i-1),um(i),u0(i),v0(i)
          enddo
       endif

       call MPI_BCAST(tiempo,1,mpi_real8,0,commu,ierr)
       call MPI_BCAST(y,ny+2,mpi_real8,0,commu,ierr)
       call MPI_BCAST(dt,1,mpi_real8,0,commu,ierr)
       call mpi_barrier(mpi_comm_world,ierr)

     end subroutine getstartzy


     ! -------------------------------------------------------------------! 
     ! -------------------------------------------------------------------! 
     ! -------------------------------------------------------------------! 
     ! ------------ PARALLEL READING SUBROUTINES ------------------------! 
     ! -------------------------------------------------------------------! 
     ! -------------------------------------------------------------------! 
     ! -------------------------------------------------------------------! 

     subroutine blockread(filename,comm,localbuffer,chunksize,&
          & nfiles,rank,sid)

       !  Read a buffer localbuffer to a single file concurrently using all
       !  the MPI processes
       ! Input arguments:
       !  
       !  filename: String. Name of the file
       !  comm: MPI communicator
       !  localbuffer: Buffer to be read
       !  chunksize: Amount of **bytes** read from localbuffer.  Please, do not
       !             play weird games and use the same size of localbuffer
       !  fsblksize: File system block size.  GPFS is 2 MB
       !  nfiles: Put a variable that contains 1 here.  Not the literal.  Writing
       !          files is not supported yet.
       !  rank: Rank of the MPI process
       !  sid: File id, different from the OS file and obtained from the parallel
       !       opening process
#ifndef BG
       use mpi
#endif
       implicit none
#ifdef BG
       include 'mpif.h'
#endif
       character(len=MAXCHARLEN),intent(in):: filename
       integer,intent(in):: comm
       integer*8,intent(in):: chunksize
       character,dimension(chunksize),intent(in):: localbuffer
       integer,intent(in):: nfiles
       integer,intent(in):: rank
       integer,intent(out):: sid

       character(len=MAXCHARLEN) :: newfname = 'newfile'
       integer:: lcomm,ierr,rankl

       integer*8:: btoread,bread,feof
       integer*8:: sumsize,bsumread,left
       real*8:: checksum_read_fp
       integer:: chunkcnt
       integer:: i !remove after testing
#ifdef TIMER
       real*8:: barr1time,barr2time
       real*8:: readtime,greadtime
       real*8:: starttime,gstarttime
       real*8:: opentime,closetime
#endif
#ifdef TIMER
       starttime = MPI_Wtime();
#endif

       call fsion_paropen_mpi(trim(filename),'br',nfiles,&
            & comm,lcomm,chunksize,2*1024*1024,rank,&
            & newfname,sid)
#ifdef TIMER
       opentime = MPI_Wtime()-starttime
#endif
       call MPI_COMM_RANK(lcomm, rankl, ierr)
#ifdef TIMER
       starttime = MPI_Wtime()
       call barrier_after_open(lcomm)
       barr1time = MPI_Wtime()-starttime
       starttime = MPI_Wtime()
       gstarttime = starttime
#endif

       checksum_read_fp = 0
       left = chunksize
       bsumread = 0
       chunkcnt = 0
       call fsion_feof(sid,feof)
       do while( (left > 0) .AND. (feof /= 1 ) )
          btoread=chunksize

          if( btoread>left ) btoread = left
          call fsion_read(localbuffer, 1, btoread, sid, bread)
#ifdef	CHECKSUM
          do i=1,bread
             checksum_read_fp = checksum_read_fp + real(IACHAR(localbuffer(i)))
          end do
#endif
          left = left - bread
          bsumread = bsumread + bread
          chunkcnt = chunkcnt + 1        
          call fsion_feof(sid,feof)       
       end do
#ifdef TIMER
       readtime = MPI_Wtime()-starttime
       starttime = MPI_Wtime()
       call barrier_after_read(lcomm)
       barr2time = MPI_Wtime()-starttime
       greadtime = MPI_Wtime()-gstarttime
       starttime = MPI_Wtime()
#endif
       call fsion_parclose_mpi(sid,ierr)
#ifdef TIMER
       closetime = MPI_Wtime()-starttime
       if(readtime == 0) readtime = -1
#endif

#ifdef  CHECKSUM
       if (abs(checksum_fp-checksum_read_fp)>1e-5) then
          write(0,*)"ERROR in double checksum  ",checksum_fp,"!=",checksum_read_fp," diff=",(checksum_fp-checksum_read_fp)
       end if
#endif
       call MPI_REDUCE(bsumread, sumsize, 1, MPI_INTEGER8, MPI_SUM, 0, comm, ierr)
       call MPI_BARRIER(comm,ierr)
#ifdef TIMER  
       if (rank == 0) then       
          write(*,'(A)') "-----------------------------------------------------------------------"
          write(*,*) 'File read:',trim(filename)
          write(*,'(a20,f10.4,a3)') 'File Size:',1.0*sumsize/1024/1024/1024,'Gb'
          write(*,'(a20,f10.4)') 'T.Time Master Node:',greadtime
          write(*,'(a20,f10.4,a7)') 'BandWidth:',1.0*sumsize/1024/1024/1024/greadtime,'Gb/sec'                       
       end if
#endif
     end subroutine blockread


     subroutine readheader(filename)    
       use alloc_dns,only: tiempo,y
       use genmod,only:um,timeinit
       implicit none
       character(len = MAXCHARLEN), intent(in):: filename

       real(kind = 8), intent(out):: cfl,re,dt
       real(kind = 8), intent(out):: lx,ly,lz
       !     integer, intent(out):: lx,ly,lz
       integer, intent(out):: nx,ny,nz2
       integer, intent(out):: xout    
       integer,intent(out):: procs
       integer*8:: cursor,i
       character(len=1),intent(in):: field

       open(unit = 11,file=trim(filename), status = "old", access="stream")
       cursor = 2*1024*1024+1  
       read(11,pos=cursor) field
       read(11) tiempo    
       read(11) cfl
       read(11) re
       read(11) lx
       read(11) ly
       read(11) lz
       read(11) nx
       read(11) ny
       read(11) nz2
       read(11) xout
       read(11) timeinit
       read(11) dt     
       read(11) (y(i), i = 0,ny+1)      
       read(11) (um(i), i = 1,ny+1)
       read(11) procs
       write(*,*)
       write(*,*) '============================================================'
       write(*,*) field,tiempo,lx,ly,lz,nx,ny,nz2,xout,timeinit,dt,procs
       write(*,*) '============================================================'
       write(*,*)
       close(11)      
     end subroutine readheader




!============================================================
!============================================================
!============================================================
  
  
#ifdef CREATEPROFILES
  subroutine create_profiles(rthin,mpiid)
    use alloc_dns,only: re,pi,ax,y,dy,idy,idx,inyv,cofivy,inby,vmagic
    use point
    use ctesp
    implicit none
    include "mpif.h"

    real*8,dimension(nx)::x,dstar,reth,uep,utau,drota
    real*8,dimension(:,:),allocatable:: u_composite,v_composite,dudx,buffer
    real*8,dimension(:,:),allocatable:: u_inner,u_log,u_outer
    real*8,dimension(ny+1):: eta,yplus,uinnerp,ulogp,Exp1,wouterp,uinfp,uouterp,ucomp,ucompi,bf
    real*8 e1,c1,ei1,kap,ckap,cprim,rd,d1,ee1,ee2,ee3,ee4,ee5,eulcns
    real*8 rx,dx,rthin,w0,w1,w2,w8,offset
    integer i,j,mpiid,dot,ierr,status(MPI_STATUS_SIZE)
    real*8:: yint(0:ny+1)

    
    !Every node allocate the buffer:
    allocate(buffer(1:ny+1,2));buffer=0d0
    !Every node allocate the array for U0 & V0:
    allocate(u0c(1:ny+1,ib:ie),v0c(1:ny+1,ib:ie));u0c=0d0;v0c=0d0

    if(mpiid.eq.0) then
       write(*,*) 'VALORES INICIALES: Rtheta_in:',rthin,'Num_planes=',num_planes
       allocate(u_composite(ny+1,num_planes+1),v_composite(ny,num_planes+1),dudx(ny,num_planes))
       allocate(u_inner(ny+1,10),u_log(ny+1,10),u_outer(ny,10))

       u_composite=0d0;v_composite=0d0;dudx=0d0
       uinnerp=0d0;ulogp=0d0;Exp1=0d0;wouterp=0d0;uinfp=0d0;uouterp=0d0
       ucomp=0d0;ucompi=0d0
       x=0d0;dstar=0d0;reth=0d0;uep=0d0;
       eta=0d0;yplus=0d0

       !CONSTANTS FOR THE FITTINGS 
       e1=0.8659d0; c1=0.01277d0;   !!reth=c1*rex^e1
       ei1=1d0/e1
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

       yint(0:ny)=(y(0:ny)+y(1:ny+1))*0.5d0 !Interpolate grid Y to U position
       yint(ny+1)=2*yint(ny)-yint(ny-1)

       do i=1,num_planes+1
          !Computing X grid --> Re_x --> Re_theta --> Uinf+ --> u_tau --> H --> delta_star --> delta_rota 
          x(i)=dx*(i-1)
          reth(i)=(rthin**ei1+c1**ei1*re*x(i))**e1
          uep(i)= log(reth(i))/kap+ckap  
          dstar(i)=reth(i)/((1-cprim/uep(i))*re)
          utau(i)=Uinfinity/uep(i)
          drota(i)=uep(i)*dstar(i)
          eta(1:ny+1)=yint(1:ny+1)/drota(i)
          yplus(1:ny+1)=yint(1:ny+1)*re*utau(i)

          if(i.eq.30) then
             write(*,*) '=======Composite Profiles: VALUES @ i=30 =================='
             write(*,*) 'x',x(i)
             write(*,*) 'reth(i)',reth(i)
             write(*,*) 'uep(i)',uep(i)
             write(*,*) 'dstar(i)',dstar(i)
             write(*,*) 'drota(i)',drota(i) 
             write(*,*) '==========================================================='             
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
           if(i.eq.30) write(*,*) 'inner',uinnerp(1:5)
          !LOG PART ------------------------------------------
          ulogp(:)=1d0/kap*log(yplus(:))+d1  
          if(i.le.10) u_log(:,i)=ulogp(:)
          !Blending function:
          bf(:)=(1-tanh((eta(:)-0.04d0)/0.01d0))/2d0;
          uinnerp(:)=bf(:)*uinnerp(:)+(1-bf(:))*ulogp(:)
          if(i.eq.30) write(*,*) 'inner2',uinnerp(1:5)
          if(i.le.10) u_inner(:,i)=uinnerp(:)   
          !OUTER REGION------------------------------------------
          Exp1(:)=-eulcns-log(eta(:))+ee1*eta(:)-ee2*eta(:)**2+&
               &       ee3*eta(:)**3-ee4*eta(:)**4+ee5*eta(:)**5   !Eq(8)
          wouterp(:)=(1/kap*Exp1(:)+w0)*0.5d0*(1-tanh(w1/eta(:)+w2*eta(:)**2+w8*eta(:)**8)) !Eq(9)  
          if(i.eq.30) write(*,*) 'wouter',wouterp(1:5)        
          !Matching---------------------------------------------
          uinfp(:)=1/kap*log(dstar(i)*re)+3.30d0   !Eq(11)
          if(i.eq.30) write(*,*) 'uinfp',uinfp(1:5)
          uouterp(:)=uinfp(:)-wouterp(:)
          if(i.eq.30) write(*,*) 'uouter',uouterp(1:5)        
          if(i.le.10) u_outer(:,i)=uouterp(:)
          !Compouse profile:
          ucomp(2:ny+1)=uinnerp(1:ny)*uouterp(1:ny)/ulogp(1:ny) !At V position @the cell (u(1)=0d0)          
          ucomp(1)=-1d0/inby(2,1)*(inby(2,2)*ucomp(2)+inby(2,3)*ucomp(3)+inby(2,4)*ucomp(4)); !Value at the ghost cell
          u_composite(:,i)=ucomp(:)
          if(i.eq.30) write(*,*) 'UCOMP----------------------------',ucomp(1:5)   

          !    ucompi(2:ny+1)=0.5d0*(ucomp(1:ny)+ucomp(2:ny+1)) !Interpolated
          !    ucompi(1)=-ucompi(2)tail
!           call interpyy(ucomp(1),u_composite(1,i),inyv,cofivy,inby,ny+1,1,1,1)    
          u_composite(:,i)=u_composite(:,i)*utau(i)
          if(i.eq.30) write(*,*) 'UCOMP2----------------------------',u_composite(1:5,i) 
          u_composite(:,i)=u_composite(:,i)/u_composite(ny,i) !Uinf=1d0
          if(i.eq.30) write(*,*) 'UCOMP----------------------------',u_composite(1:5,i) 
          u_composite(ny+1,i)=u_composite(ny,i)  !Adding ny+1 point                  

          if(i.eq.30) then          
	    write(*,*) 'Valor de Ucomp'
	    do j=1,5
	      write(*,*) u_composite(j,i)
	    enddo
	    do j=325,331
	      write(*,*) u_composite(j,i)
	    enddo
          endif
       enddo

       !Deriving the V0 composite profile:
       v_composite(1,:)=0d0 !Initial Condition

       do j=1,ny-1
          do i=2,num_planes
             dudx(j,i)=idx*(u_composite(j+1,i)-u_composite(j+1,i-1)) !dudx @ (i,j)           
          enddo
       enddo

       do i=2,num_planes
          do j=1,ny-1
             v_composite(j+1,i)=-dudx(j,i)/idy(j)+v_composite(j,i)
          enddo          
       enddo
       v_composite(:,1)=v_composite(:,2)

       do i=1,nx
          if(i.lt.num_planes) then
             offset=v_composite(ny,i)-vmagic(i)
             vmagic(i)=v_composite(ny,i)  !Changing Vmagic to avoid any discontinuity             
          else
             vmagic(i)=offset+vmagic(i)
          endif   
       enddo       
       write(*,*) 'Offset between Vmagic and V_composite @ the last plane=', offset                                
       write(*,*) 'Writting composite profiles U0 & V0 in file: extraprofiles '
       write(17) u_composite(1:ny+1,1:num_planes),v_composite(1:ny,1:num_planes),u_inner(1:ny+1,1:10),u_log(1:ny+1,1:10),u_outer(1:ny+1,1:10),bf(1:ny+1)

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
       write(*,*) 'Sending the composite profiles U0 & V0...... DONE';
       write(*,*) '===========================================================' 
       write(*,*)
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
    if(mpiid.eq.0) write(*,*) 'Broadcasting New Vmagic.....'
    call MPI_BCAST(vmagic,nx,MPI_REAL8,0,MPI_COMM_WORLD,ierr) !Broadcasting Vmagic
    deallocate(buffer)
  endsubroutine create_profiles


  !===========================================================================================
  !===========================================================================================
  !===========================================================================================

  subroutine impose_profiles(ut,vt,wt,mpiid)
    use point
    use ctesp
    implicit none
    include "mpif.h"

    complex*16,dimension(0:nz2,ny+1,ib:ie)::ut,wt
    complex*16,dimension(0:nz2,ny  ,ib:ie)::vt
    integer:: i,ierr,status(MPI_STATUS_SIZE),mpiid
!----------------------------------WRITING THE K=0 XY PLANE  TO A FILE-------------------
    paso=paso+1
    if(paso.eq.1) then
      if(mpiid.eq.0) write(*,*) 'WRITING THE K=0 XY PLANE TO A FILE FOR U,V & W before POISON'
      do i=ib,ie   
         pdiv(1:ny,i)=real(ut(0,1:ny,i),kind=8) !Each node copy a piece of the array
      enddo
      call MPI_ALLREDUCE(MPI_IN_PLACE,pdiv,ny*nx,MPI_real8,MPI_SUM,MPI_COMM_WORLD,ierr)      
      if(mpiid.eq.0) write(28) pdiv(1:ny,1:nx)
      pdiv=0d0

      do i=ib,ie   
         pdiv(1:ny,i)=real(vt(0,1:ny,i),kind=8) !Each node copy a piece of the array
      enddo
      call MPI_ALLREDUCE(MPI_IN_PLACE,pdiv,ny*nx,MPI_real8,MPI_SUM,MPI_COMM_WORLD,ierr)
      if(mpiid.eq.0) write(28) pdiv(1:ny,1:nx)      
      pdiv=0d0


      do i=ib,ie   
         pdiv(1:ny,i)=real(wt(0,1:ny,i),kind=8) !Each node copy a piece of the array
      enddo
      call MPI_ALLREDUCE(MPI_IN_PLACE,pdiv,ny*nx,MPI_real8,MPI_SUM,MPI_COMM_WORLD,ierr)      
      if(mpiid.eq.0) write(28) pdiv(1:ny,1:nx)
      pdiv=0d0

      if(mpiid.eq.0) write(*,*) 'WRITING THE K=0 XY PLANE TO A FILE FOR U,V & W before POISON.............DONE'
    endif
!------------------------------------------------------------------    

    do i=ib,ie
       if(i.le.num_planes) then
          ut(0,1:ny+1,i)=u0c(1:ny+1,i)   !The imaginary part is then set to 0
          vt(0,1:ny  ,i)=v0c(1:ny  ,i) 
          wt(0,1:ny+1,i)=0d0                   
       endif
    enddo
  endsubroutine impose_profiles


!===============================================

  subroutine get_modes(ut,vt,wt)
    use point
    use ctesp
    implicit none    
    complex*16,dimension(0:nz2,ny+1,ib:ie)::ut,wt
    complex*16,dimension(0:nz2,ny  ,ib:ie)::vt
    integer:: i
         
    !Copy the good modes before doing anything in poisson:    
      do i=ib,ie
        if(i.eq.num_planes) then
	  uk(1:nz2,1:ny+1)=ut(1:nz2,1:ny+1,i)
	  vk(1:nz2,1:ny  )=vt(1:nz2,1:ny  ,i)
	  wk(1:nz2,1:ny+1)=wt(1:nz2,1:ny+1,i)
	endif
      enddo
  
    endsubroutine get_modes

!===========================================================================+
!===========================================================================+

subroutine check_divergence(ut,vt,wt,rest,mpiid)
  use point
  use alloc_dns,only:idx,idy,idxx,idyy,phiy,dy,y,kaz,kaz2,kmod,ayp
  use ctesp
  use omp_lib
  use temporal
  implicit none
  include 'mpif.h'

  ! ---------------------- I/O -------------------------------------!
  integer mpiid
  
  complex*16, dimension(0:nz2,ny+1,ib:ie):: wt,ut
  complex*16, dimension(0:nz2,ny,ib:ie)  :: pt,vt,rest
  complex*16, dimension(0:nz2,ny+1)  :: rt
  ! -------------------------- Work Arrays -------------------------!
  real*8  aypr(3,ny-1)
  integer i,j,l,k,kk,k2
  ! --------------------- MPI workspaces -----------------------------!
  integer istat(MPI_STATUS_SIZE),ierr,comm,countu,countv,tipo
  ! ----------------------------------------------------------------!
  countu=(nz2+1)*(ny+1)
  countv=(nz2+1)*ny
  comm = MPI_COMM_WORLD
  tipo=MPI_COMPLEX16

  ! --- compute the divergence, we are in (zy) 
  do i=ib0,ie
     !$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(j) SCHEDULE(STATIC)
     do j=1,ny-1
        rest(:,j,i) = wt(:,j+1,i)*kaz +(vt(:,j+1,i)-vt(:,j,i))*idy(j)
     enddo
  enddo
  ! --- add du/dx -------------
  do i=ib+1,ie
     !$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(j) SCHEDULE(STATIC)
     do j=1,ny-1
        rest(:,j,i)=rest(:,j,i)+idx*(ut(:,j+1,i)-ut(:,j+1,i-1))
     enddo
  enddo

  if (mpiid.eq.0) then
     call MPI_SEND(ut(0,1,ie),countu,tipo,mpiid+1,0,comm,istat,ierr)
  elseif (mpiid.eq.pnodes-1) then
     call MPI_RECV(rt,countu,tipo,mpiid-1,0,comm,istat,ierr)
     !$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(j) SCHEDULE(STATIC)
     do j=1,ny-1
        rest(:,j,ib)=rest(:,j,ib)+idx*(ut(:,j+1,ib)-rt(:,j+1))
     enddo
  else
     call MPI_SENDRECV(ut(0,1,ie),countu,tipo,mpiid+1,0,  &
          &                      rt,countu,tipo,mpiid-1,0,  comm,istat,ierr)
     !$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(j) SCHEDULE(STATIC)
     do j=1,ny-1
        rest(:,j,ib)=rest(:,j,ib)+idx*(ut(:,j+1,ib)-rt(:,j+1))
     enddo
  endif

!=========================================
do i=ib0,ie   
   pdiv(1:ny-1,i)=real(rest(0,1:ny-1,i),kind=8) !Each node copy a piece of the array
enddo

call MPI_ALLREDUCE(pdiv(1:ny-1,1:nx),pdiv(1:ny-1,1:nx),(ny-1)*nx,MPI_real8,MPI_SUM,MPI_COMM_WORLD,ierr)

if(mpiid.eq.0) then
 write(*,*) 'ESCRIBIENDO LA DIVERGENCIA INICIAL DEL CAMPO:'
 write(27) pdiv(1:ny-1,1:nx)
 write(*,*) 'Div='
 do i=20,30;write(*,*) pdiv(i,200);enddo
 write(*,*) '                     			.............DONE'
endif
pdiv=0d0
!=========================================
endsubroutine check_divergence




#endif






