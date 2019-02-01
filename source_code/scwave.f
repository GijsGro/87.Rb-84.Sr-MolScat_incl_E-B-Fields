      SUBROUTINE SCWAVE(RBEGIN,REND,WVEC,PSIAR,PSIAI,PSIB,WORK,
     1                  W,SR,SI,EVEC,U,L,N,NSQ,NOPEN,NB,NSTEPS,
     2                  ICHAN,IREC,IPRINT)
C  Copyright (C) 2018 J. M. Hutson & C. R. Le Sueur
C  Distributed under the GNU General Public License, version 3

C  CODE WRITTEN BY GC McBane AND ADAPTED FOR USE IN MOLSCAT BY CR Le Sueur
C  NOV 2016
      USE potential
      IMPLICIT NONE
C  CONSTRUCT ASYMPTOTIC WAVEFUNCTION FROM DESIRED INITIAL CHANNEL AND S-MATRIX
C  INITIAL PSI IS RETURNED IN PSIAR (REAL PART) AND PSIAI  (IMAG PART) ,
C  BOTH OF LENGTH N
C
      DOUBLE PRECISION RBEGIN,REND,WVEC,PSIAR,PSIAI,PSIB,WORK,W,SR,SI,
     1                 EVEC,U
      DIMENSION WVEC(N),PSIAR(N),PSIAI(N),PSIB(N),WORK(N),W(N,N),
     1          SR(N,N),SI(N,N),EVEC(N,N),U(N,N)
      INTEGER, INTENT(IN):: L,N,NSQ,NB,NOPEN,ICHAN,IREC,IPRINT
      DIMENSION L(N),NB(N)

C  COMMON BLOCK FOR INPUT/OUTPUT CHANNEL NUMBERS
      LOGICAL PSIFMT
      INTEGER IPSISC,IWAVSC,IPSI,NWVCOL
      COMMON /IOCHAN/ IPSISC,IWAVSC,IPSI,NWVCOL,PSIFMT

      LOGICAL ASYMPK
      PARAMETER (ASYMPK=.FALSE.)

      DOUBLE PRECISION DR,R
      INTEGER IWREC,IPREC,NSTEPS,J,I
      CHARACTER(2)  NCOL
      CHARACTER(20) F990

      WRITE(NCOL,'(I2)') 2*NWVCOL
      F990='(E15.7,'//NCOL//'E15.7)'
      IF (ASYMPK) THEN  ! USE K-MATRIX VERSION
         CALL PSIK(N,NOPEN,NB,U,REND,WVEC,L,ICHAN,PSIAR) !K-MATRIX VERSION
         WRITE(*,*) ' CONSTRUCTING PSI(REND) USING K MATRIX'
         WRITE(*,*) 'ASYMPTOTIC WAVEFUNCTION AT REND = ', REND, ':'
         DO I = 1, N
            WRITE(*,*) PSIAR(I)    !K-MATRIX VERSION
         ENDDO
      ELSE  !S-MATRIX VERSION
         CALL PSIRH(N,NOPEN,NB,SR,SI,REND,WVEC,L,ICHAN,PSIAR,PSIAI)
         WRITE(*,*) ' CONSTRUCTING PSI(REND) USING S MATRIX'
         WRITE(*,*) 'ASYMPTOTIC WAVEFUNCTION AT REND = ', REND, ':'
         DO I = 1, N
            WRITE(*,*) PSIAR(I), PSIAI(I) !S-MATRIX VERSION
         ENDDO
      ENDIF

C  TRANSFORM ASYMPTOTIC WAVEFUNCTION TO PRIMITIVE BASIS
      IF (NCONST.NE.0 .OR. NRSQ.NE.0) THEN
        W=EVEC
        CALL DGEMV('N',N,N,1.0D0,W,N,PSIAR,1,0.0D0,PSIB,1)  ! REAL PART
        CALL DCOPY(N,PSIB,1,PSIAR,1)
        IF (.NOT.ASYMPK) THEN !MUST DO IMAGINARY PART TOO
          CALL DGEMV('N',N,N,1.0D0,W,N,PSIAI,1,0.0D0,PSIB,1) ! IMAG PART
          CALL DCOPY(N,PSIB,1,PSIAI,1)
        ENDIF
      ENDIF


C  GENERATE REAL AND IMAGINARY PARTS OF PSI(R) WITH SEPARATE CALLS TO EFPROP;
C  MUST MAKE TWO RUNS WRITE INTO DIFFERENT RECORDS OF UNIT 10.
      IWREC = IREC          ! NUMBER OF LAST RECORD ON UNIT IWAVSC (+1)

C  PROPAGATE REAL PART (PSIAR)
C  WORK RETURNS SUMPSI (NOT USEFUL HERE)
C  PSIB IS USED AS SCRATCH SPACE
      IPREC = NSTEPS+1      ! POSITION OF INITIAL RECORD TO BE WRITTEN TO UNIT IPSISC
      CALL EFPROP(N,RBEGIN,REND,NSTEPS,PSIB,W,PSIAR,IWREC,
     1            WORK,IPRINT,IPREC)
      IF (.NOT.ASYMPK) THEN
C  PROPAGATE IMAG PART (PSIAI)
         IWREC = IREC
         IPREC = (NSTEPS+1)*2
         CALL EFPROP(N,RBEGIN,REND,NSTEPS,PSIB,W,PSIAI,IWREC,
     1               WORK,IPRINT,IPREC)
      ENDIF

C  COLLECT RESULTS FROM UNIT IPSISC AND WRITE SEQUENTIALLY ON UNIT IPSI
C  IN FORMAT COMPATIBLE WITH READING AS DOUBLE COMPLEX

      PSIAI=0.D0
      DO I = 1, NSTEPS+1
        READ(IPSISC,REC=I,ERR=998) R,PSIAR
        IF (.NOT.ASYMPK) READ(IPSISC,REC=NSTEPS+1+I,ERR=999) R,PSIAI
        IF (PSIFMT) THEN
          WRITE(IPSI,FMT=F990) R,(PSIAR(J),PSIAI(J),J=1,N)
        ELSE
          WRITE(IPSI) R,(PSIAR(J),PSIAI(J),J=1,N)
        ENDIF
      ENDDO

      RETURN
998   WRITE(6,*)'PSIAR',I
      STOP
999   WRITE(6,*)'PSIAI',NSTEPS+1+I
      STOP
      END
