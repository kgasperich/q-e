!
! Copyright (C) 2001 PWSCF group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
#ifdef __PARA
!
!----------------------------------------------------------------------
subroutine cft3 (f, n1, n2, n3, nx1, nx2, nx3, sign)
  !----------------------------------------------------------------------
  !
  !   sign = +-1 : parallel 3d fft for rho and for the potential
  !
  !   sign = +1 : G-space to R-space, output = \sum_G f(G)exp(+iG*R)
  !               fft along z using pencils (cft_1)
  !               transpose across nodes    (fft_scatter)
  !                  and reorder
  !               fft along y and x         (cft_2)
  !   sign = -1 : R-space to G-space, output = \int_R f(R)exp(-iG*R)/Omega
  !               fft along x and y         (cft_2)
  !               transpose across nodes    (fft_scatter)
  !                  and reorder
  !               fft along z using pencils (cft_1)
  !
#include "machine.h"
  use parameters, only : DP
  use para
  implicit none
  integer :: n1, n2, n3, nx1, nx2, nx3, sign

  complex (kind=DP) :: f (nxx)
  integer :: nxx_save, mc, i, j, ii, iproc, nppx
  complex (kind=DP), allocatable  :: aux (:)
  data nxx_save / 0 /
  save nxx_save, aux
  !
  call start_clock ('cft3')
  if (nxx_save.ne.nxx) then
     if (nxx_save.ne.0) deallocate (aux)
     nxx_save = nxx
     allocate (aux( nxx))    
  endif
  !
  ! the following is needed if the fft is distributed over only one proces
  ! for the special case nx3.ne.n3. Not an elegant solution, but simple, f
  ! and better than the preceding one that did not work in some cases. Not
  ! that fft_scatter does nothing if nprocp=1. PG
  !
  if (nprocp.eq.1) then
     nppx = nx3
  else
     nppx = npp (me)
  endif
  !
  if (sign.eq.1) then
     call cft_1 (f, ncp (me), n3, nx3, sign, aux)
     call fft_scatter (aux, nx3, nxx, f, ncp, npp, sign)
     call setv (2 * nxx, 0.0d0, f, 1)
     do i = 1, nct
        mc = icpl (i)
        do j = 1, npp (me)
           f (mc + (j - 1) * ncplane) = aux (j + (i - 1) * nppx)
        enddo
     enddo
     call cft_2 (f, npp (me), n1, n2, nx1, nx2, sign)
  elseif (sign.eq. - 1) then
     call cft_2 (f, npp (me), n1, n2, nx1, nx2, sign)
     do i = 1, nct
        mc = icpl (i)
        do j = 1, npp (me)
           aux (j + (i - 1) * nppx) = f (mc + (j - 1) * ncplane)
        enddo
     enddo
     call fft_scatter (aux, nx3, nxx, f, ncp, npp, sign)
     call cft_1 (aux, ncp (me), n3, nx3, sign, f)
  else
     call errore ('cft3', 'not allowed', abs (sign) )

  endif
  call stop_clock ('cft3')
  return
end subroutine cft3
#else
!
!----------------------------------------------------------------------
subroutine cft3 (f, n1, n2, n3, nx1, nx2, nx3, sign)
  !----------------------------------------------------------------------
  !
  use parameters
  implicit none
  integer :: n1, n2, n3, nx1, nx2, nx3, sign

  complex(kind=DP) :: f (nx1 * nx2 * nx3)
  call start_clock ('cft3')
  !
  !   sign = +-1 : complete 3d fft (for rho and for the potential)
  !
  if (sign.eq.1) then
     call cft_3 (f, n1, n2, n3, nx1, nx2, nx3, 1, 1)
  elseif (sign.eq. - 1) then
     call cft_3 (f, n1, n2, n3, nx1, nx2, nx3, 1, - 1)
  else
     call errore ('cft3', 'what should i do?', 1)
  endif

  call stop_clock ('cft3')
  return
end subroutine cft3
#endif

