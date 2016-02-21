subroutine rpn2(ixy,maxm,meqn,mwaves,maux,mbc,mx,ql,qr,auxl,auxr,wave,s,amdq,apdq)

! Riemann solver for the elasticity equations in 2d, with varying
! material properties rho, lambda, and mu (strain-momentum formulation)
!
! waves: 4
! equations: 5
! aux fields: 5

! Conserved quantities:
!       1 epsilon_11
!       2 epsilon_22
!       3 epsilon_12
!       4 momentum (axis 1)
!       5 momentum (axis 2)

! Auxiliary variables:
!       1  density
!       2  lamda
!       3  mu
!       4  cp
!       5  cs

! Note that although there are 5 eigenvectors, one eigenvalue
! is always zero and so we only need to compute 4 waves.	
! 
! solve Riemann problems along one slice of data.
!
! On input, ql contains the state vector at the left edge of each cell
!           qr contains the state vector at the right edge of each cell
!
! Note that the i'th Riemann problem has left state qr(:,i-1)
!                                    and right state ql(:,i)
! From the basic clawpack routines, this routine is called with ql = qr
!
! This data is along a slice in the x-direction if ixy=1 
!                            or the y-direction if ixy=2.
!
! Here it is assumed that auxl=auxr gives the cell values
! for this slice.
!
! On output, wave contains the waves,
!            s the speeds,
!            amdq the  left-going flux difference  A^- \Delta q
!            apdq the right-going flux difference  A^+ \Delta q
!
! Note that the waves are *not* in order of increasing lambda.
! Instead the 1- and 2-waves are the P-waves and the 3- and 4-waves
! are the S-waves.   (The 5th wave would have speed zero and is not computed.)

    implicit none

    integer, intent(in) :: ixy, maxm, meqn, mwaves, mbc, mx, maux
    double precision, intent(in) :: ql, qr, auxl, auxr
    double precision, intent(out) :: wave, s, amdq, apdq

    dimension wave( meqn, mwaves, 1-mbc:maxm+mbc)
    dimension    s(mwaves, 1-mbc:maxm+mbc)
    dimension   ql(meqn, 1-mbc:maxm+mbc)
    dimension   qr(meqn, 1-mbc:maxm+mbc)
    dimension apdq(meqn, 1-mbc:maxm+mbc)
    dimension amdq(meqn, 1-mbc:maxm+mbc)
    dimension auxl(maux, 1-mbc:maxm+mbc)
    dimension auxr(maux, 1-mbc:maxm+mbc)

    integer :: keps11, keps22, ku, kv, i, m
    double precision :: deps11, deps22, deps12, du, dv
    double precision :: alamr, amur, bulkr, cpr, csr
    double precision :: alaml, amul, bulkl, cpl, csl
    double precision :: det, a1, a2, a3, a4

    ! set ku to point to  the component of the system that corresponds
    ! to momentum in the direction of this slice, kv to the orthogonal
    ! momentum.  Similarly keps11 and keps22 point to normal strains.
    ! 3rd component is always shear stress eps12.

    if (ixy.eq.1) then
        keps11 = 1
        keps22 = 2
        ku = 4
        kv = 5
    else
        keps11 = 2
        keps22 = 1
        ku = 5
        kv = 4
    endif

    ! note that notation for u and v reflects assumption that the 
    ! Riemann problems are in the x-direction with u in the normal
    ! direciton and v in the orthogonal direcion, but with the above
    ! definitions of ku and kv the routine also works with ixy=2

    ! split the jump in q at each interface into waves
    ! The jump is split into leftgoing waves traveling at speeds -cp, -cs
    ! relative to the material properties to the left of the interface,
    ! and rightgoing waves traveling at speeds +cp, +cs
    ! relative to the material properties to the right of the interface,

    do i = 2-mbc, mx+mbc
        deps11 = ql(keps11,i) - qr(keps11,i-1)
        deps22 = ql(keps22,i) - qr(keps22,i-1)
        deps12 = ql(3,i) - qr(3,i-1)
        du = ql(ku,i) - qr(ku,i-1)    ! actually difference in rho*u
        dv = ql(kv,i) - qr(kv,i-1)    ! actually difference in rho*v

        ! material properties in cells i (on right) and i-1 (on left):

        alamr = auxl(2,i)
        amur = auxl(3,i)
        bulkr = alamr + 2.d0*amur
        cpr = auxl(4,i)
        csr = auxl(5,i)

        alaml = auxr(2,i-1)
        amul = auxr(3,i-1)
        bulkl = alaml + 2.d0*amul
        cpl = auxr(4,i-1)
        csl = auxr(5,i-1)

        ! P-wave strengths:
        det = bulkl*cpr + bulkr*cpl
        if (det.eq.0.d0) then
            write(6,*) 'det=0 in rpn2'
            stop 
        endif
        ! XXX Switch these to momentum-strain 
        a1 = (cpr*deps11 + bulkr*du) / det
        a2 = (cpl*deps11 - bulkl*du) / det

        ! S-wave strengths:
        det = amul*csr + amur*csl
        if (det.eq.0.d0) then
            ! no s-waves
            a3 = 0.d0
            a4 = 0.d0
        else
            ! XXX Switch these to momentum-strain
            a3 = (csr*deps12 + amur*dv) / det
            a4 = (csl*deps12 - amul*dv) / det
        endif

        ! 5th wave has velocity 0 so is not computed or propagated.


        ! Compute the waves.
        ! XXX Switch these to momentum-strain

        wave(keps11,1,i) = a1 * bulkl
        wave(keps22,1,i) = a1 * alaml
        wave(3,1,i)  = 0.d0
        wave(ku,1,i) = a1 * cpl
        wave(kv,1,i) = 0.d0
        s(1,i) = -cpl

        wave(keps11,2,i) = a2 * bulkr
        wave(keps22,2,i) = a2 * alamr
        wave(3,2,i)  = 0.d0
        wave(ku,2,i) = -a2 * cpr
        wave(kv,2,i) = 0.d0
        s(2,i) = cpr

        wave(keps11,3,i) = 0.d0
        wave(keps22,3,i) = 0.d0
        wave(3,3,i)  = a3*amul
        wave(ku,3,i) = 0.d0
        wave(kv,3,i) = a3*csl
        s(3,i) = -csl

        wave(keps11,4,i) = 0.d0
        wave(keps22,4,i) = 0.d0
        wave(3,4,i)  = a4*amur
        wave(ku,4,i) = 0.d0
        wave(kv,4,i) = -a4*csr
        s(4,i) = csr


        ! compute the leftgoing and rightgoing flux differences:
        ! Note s(i,1),s(i,3) < 0   and   s(i,2),s(i,4) > 0.
        do m=1,meqn
            amdq(m,i) = s(1,i)*wave(m,1,i) + s(3,i)*wave(m,3,i)
            apdq(m,i) = s(2,i)*wave(m,2,i) + s(4,i)*wave(m,4,i)
        enddo
    enddo

    return
end subroutine rpn2
