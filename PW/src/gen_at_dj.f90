!
! Copyright (C) 2002-2020 Quantum ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!
!----------------------------------------------------------------------
SUBROUTINE gen_at_dj( ik, dwfcat )
   !----------------------------------------------------------------------
   !! This routine calculates the atomic wfc generated by the derivative
   !! (with respect to the q vector) of the bessel function. This vector
   !! is needed in computing the Hubbard contribution to the stress tensor.
   !
   USE kinds,       ONLY: DP
   USE io_global,   ONLY: stdout
   USE constants,   ONLY: tpi
   USE atom,        ONLY: msh
   USE ions_base,   ONLY: nat, ntyp => nsp, ityp, tau
   USE cell_base,   ONLY: omega, at, bg, tpiba
   USE klist,       ONLY: xk, ngk, igk_k
   USE gvect,       ONLY: mill, eigts1, eigts2, eigts3, g
   USE wvfct,       ONLY: npwx
   USE us,          ONLY: tab_at, dq
   USE uspp_param,  ONLY: upf
   USE basis,       ONLY: natomwfc
   !
   IMPLICIT NONE
   !
   INTEGER, INTENT(IN) :: ik
   !! k-point index
   COMPLEX(DP), INTENT(OUT) :: dwfcat(npwx,natomwfc)
   !! the derivative of the atomic wfcs (all)
   !
   ! ... local variables
   !
   INTEGER :: l, na, nt, nb, iatw, iig, ig, i0, i1, i2 ,i3, m, lm, &
              nwfcm, lmax_wfc, npw
   REAL(DP) :: qt, arg, px, ux, vx, wx
   COMPLEX(DP) :: phase, pref
   REAL(DP),    ALLOCATABLE :: gk(:,:), q(:), ylm(:,:), djl(:,:,:)
   COMPLEX(DP), ALLOCATABLE :: sk(:)
   ! 
   npw = ngk(ik)
   nwfcm = MAXVAL( upf(1:ntyp)%nwfc )
   ! calculate max angular momentum required in wavefunctions
   lmax_wfc = 0
   do nt = 1, ntyp
      lmax_wfc = MAX ( lmax_wfc, MAXVAL (upf(nt)%lchi(1:upf(nt)%nwfc) ) )
   enddo
   !
   ALLOCATE( ylm (npw,(lmax_wfc+1)**2), djl (npw,nwfcm,ntyp) )
   ALLOCATE( gk(3,npw), q (npw) )
   !
   DO ig = 1, npw
      iig = igk_k(ig,ik)
      gk(1,ig) = xk(1,ik) + g(1,iig)
      gk(2,ig) = xk(2,ik) + g(2,iig)
      gk(3,ig) = xk(3,ik) + g(3,iig)
      q(ig) = gk(1,ig)**2 + gk(2,ig)**2 + gk(3,ig)**2
   ENDDO
   !
   !  ylm = spherical harmonics
   !
   CALL ylmr2( (lmax_wfc+1)**2, npw, gk, q, ylm )
   !
   q(:) = DSQRT(q(:))
   !
   DO nt=1,ntyp
      DO nb=1,upf(nt)%nwfc
         IF (upf(nt)%oc(nb) >= 0.d0) THEN
            DO ig = 1, npw
               qt=q(ig)*tpiba
               px = qt / dq - INT(qt/dq)
               ux = 1.d0 - px
               vx = 2.d0 - px
               wx = 3.d0 - px
               i0 = qt / dq + 1
               i1 = i0 + 1
               i2 = i0 + 2
               i3 = i0 + 3
               djl(ig,nb,nt) = &
                     ( tab_at (i0, nb, nt) * (-vx*wx-ux*wx-ux*vx)/6.d0 + &
                       tab_at (i1, nb, nt) * (+vx*wx-px*wx-px*vx)/2.d0 - &
                       tab_at (i2, nb, nt) * (+ux*wx-px*wx-px*ux)/2.d0 + &
                       tab_at (i3, nb, nt) * (+ux*vx-px*vx-px*ux)/6.d0 )/dq
            ENDDO
         ENDIF
      ENDDO
   ENDDO
   DEALLOCATE( q, gk )
   !
   ALLOCATE( sk(npw) )
   !
   iatw = 0
   DO na=1,nat
      nt=ityp(na)
      arg = ( xk(1,ik) * tau(1,na) + &
              xk(2,ik) * tau(2,na) + &
              xk(3,ik) * tau(3,na) ) * tpi
      phase = CMPLX( COS(arg), -SIN(arg), KIND=DP )
      DO ig =1,npw
         iig = igk_k(ig,ik)
         sk(ig) = eigts1(mill(1,iig),na) *      &
                  eigts2(mill(2,iig),na) *      &
                  eigts3(mill(3,iig),na) * phase
      ENDDO
      !
      DO nb = 1,upf(nt)%nwfc
         ! Note: here we put ">=" to be consistent with "atomic_wfc"/"n_atom_wfc" 
         IF ( upf(nt)%oc(nb) >= 0.d0 ) THEN
            l = upf(nt)%lchi(nb)
            pref = (0.d0,1.d0)**l
            DO m = 1,2*l+1
               lm = l*l+m
               iatw = iatw+1
               DO ig=1,npw
                  dwfcat(ig,iatw) = djl(ig,nb,nt)*sk(ig)*ylm(ig,lm)*pref
               ENDDO
            ENDDO
         ENDIF
      ENDDO
   ENDDO
   !
   IF (iatw /= natomwfc) THEN
      WRITE( stdout,*) 'iatw =', iatw, 'natomwfc =', natomwfc
      CALL errore( 'gen_at_dj', 'unexpected error', 1 )
   ENDIF

   DEALLOCATE( sk       )
   DEALLOCATE( djl, ylm )
   !
   RETURN
   !
END SUBROUTINE gen_at_dj
