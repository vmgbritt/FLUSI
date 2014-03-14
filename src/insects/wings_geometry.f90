!------------------------------------------------------------------------------
! Draws a wing
! here, a wing is a rigid plate of constant thickness that differs from
! a rectangular plate only in the x-direction
! 
! note to save a bit of computing time, we first check the easy
! conditions (thickness and spanwise length) and then the shape
! function since this saves many evaluations of the shape.
subroutine DrawWing(ix,iy,iz,x_wing,M,rot)
  use fsi_vars
  use mpi
  implicit none
  real(kind=pr) :: a_body, R, R0, steps, x_top, x_bot, R_tmp
  real(kind=pr) :: y_tmp, x_tmp, z_tmp, xroot,yroot, f,xc,yc, a0
  real(kind=pr), dimension(:), allocatable :: ai, bi
  real(kind=pr) :: v_tmp(1:3), mask_tmp, theta
  integer :: n_fft
  integer, intent(in) :: ix,iy,iz
  integer :: i
  real(kind=pr),intent(in) :: x_wing(1:3), rot(1:3), M(1:3,1:3)

  select case (Insect%WingShape) 
  
  !*****************************************************************************
  ! in these two cases, we have two given x_w(y_w) that delimit the wing
  !*****************************************************************************
  case ('TwoEllipses','rectangular')  
    ! spanwise length:
    if ((x_wing(2)>=-Insect%safety).and.(x_wing(2)<=Insect%L_span + Insect%safety)) then
    ! thickness: (note left and right wing have a different orientation of the z-axis
    ! but this does not matter since this is the same.
    if (abs(x_wing(3))<=0.5*Insect%WingThickness + Insect%safety) then
        
        
    ! wing shape (determine between which x-values (x_bot, x_top) the wing is
    ! these values depend on the spanwise direction (which is y)
    select case(Insect%WingShape)
      case ('TwoEllipses')
        a_body = 0.5d0 * Insect%L_span
        if ((1.d0 - ((x_wing(2)-a_body)**2)/(a_body**2)) >= 0.d0) then
        x_top =  dsqrt((Insect%b_top**2)*(1.d0-((x_wing(2)-a_body)**2)/(a_body**2)))
        x_bot = -dsqrt((Insect%b_bot**2)*(1.d0-((x_wing(2)-a_body)**2)/(a_body**2)))
        else
        x_top = 0.d0
        x_bot = 0.d0
        endif
      case ('rectangular')
        x_top = Insect%b_top
        x_bot =-Insect%b_bot
    end select
        
    
    ! in the x-direction, the actual wing shape plays.    
    if ((x_wing(1)>x_bot-Insect%safety).and.(x_wing(1)<x_top+Insect%safety)) then        
        
      ! smooth length
      if (x_wing(2)<0.d0) then  ! xs is chordlength coordinate
        y_tmp = steps(-x_wing(2),0.d0)
      else
        y_tmp = steps( x_wing(2),Insect%L_span)
      endif

      ! smooth height
      z_tmp = steps(dabs(x_wing(3)),0.5d0*Insect%WingThickness) ! thickness       

      ! smooth shape
      if (x_wing(1)<0.d0) then
        x_tmp = steps(-x_wing(1),-x_bot)
      else
        x_tmp = steps( x_wing(1), x_top)
      endif
      
      mask_tmp = z_tmp*y_tmp*x_tmp
      
      if ((mask(ix,iy,iz) <= mask_tmp).and.(mask_tmp>0.0)) then 
        mask(ix,iy,iz) = mask_tmp
        ! wings have the color "1"
        mask_color(ix,iy,iz) = 1
        !------------------------------------------------
        ! solid body rotation
        ! Attention: the Matrix transpose(M) brings us back to the body
        ! coordinate system, not to the inertial frame. this is done in 
        ! the main routine Draw_Insect
        !------------------------------------------------
        v_tmp(1) = rot(2)*x_wing(3)-rot(3)*x_wing(2)
        v_tmp(2) = rot(3)*x_wing(1)-rot(1)*x_wing(3)
        v_tmp(3) = rot(1)*x_wing(2)-rot(2)*x_wing(1)
        
        ! note we set this only if it is a part of the wing
        us(ix,iy,iz,1:3) = matmul(transpose(M), v_tmp)
      endif
    endif  
    
    endif
    endif
    
  
  !*****************************************************************************
  ! in this case, we have given the wing shape as a function R(theta) which is 
  ! given by some Fourier coefficients
  !*****************************************************************************
  case ('drosophila','drosophila_mutated','drosophila_sandberg',&
        'drosophila_maeda','flapper_sane')
    ! first, check if the point lies inside the rectanglee L_span x L_span
    ! here we assume that the chordlength is NOT greater than the span
    if ((x_wing(2)>=-Insect%safety).and.(x_wing(2)<=Insect%L_span + Insect%safety)) then
    if ((x_wing(1)>=-(Insect%L_span+Insect%safety)).and.(x_wing(1)<=Insect%L_span+Insect%safety)) then
    if (abs(x_wing(3))<=0.5*Insect%WingThickness + Insect%safety) then
    
      !-----------------------------------------
      ! hard-coded Fourier coefficients for R(theta)
      !-----------------------------------------
      if (Insect%WingShape == 'drosophila') then
        !********************************************
        ! Drosophila wing from Jan Gruber's png file
        !********************************************
        n_fft = 40
        allocate ( ai(1:n_fft), bi(1:n_fft) )
        a0 = 0.5140278
        ai = (/0.1276258,-0.1189758,-0.0389458,0.0525938,0.0151538,-0.0247938,&
              -0.0039188,0.0104848,-0.0030638,-0.0064578,0.0042208,0.0043248,&
              -0.0026878,-0.0021458,0.0017688,0.0006398,-0.0013538,-0.0002038,&
              0.0009738,0.0002508,-0.0003548,-0.0003668,-0.0002798,0.0000568,&
              0.0003358,0.0001408,-0.0002208,0.0000028,0.0004348,0.0001218,&
              -0.0006458,-0.0003498,0.0007168,0.0003288,-0.0007078,-0.0001368,&
              0.0007828,0.0001458,-0.0007078,-0.0001358/) 
              
        bi = (/-0.1072518,-0.0449318,0.0296558,0.0265668,-0.0043988,-0.0113218,&
              -0.0003278,0.0075028,0.0013598,-0.0057338,-0.0021228,0.0036178,&
              0.0013328,-0.0024128,-0.0007688,0.0011478,0.0003158,-0.0005528,&
              0.0000458,0.0003768,0.0002558,0.0000168,-0.0006018,-0.0006338,&
              0.0001718,0.0007758,0.0001328,-0.0005888,-0.0001088,0.0006298,&
              0.0000318,-0.0008668,-0.0000478,0.0009048,0.0001198,-0.0008248,&
              -0.0000788,0.0007028,-0.0000118,-0.0006608/)
              
        ! wing root point        
        xroot =+0.1122
        yroot =-0.0157
        ! center of circle
        xc =-0.1206 + xroot
        yc = 0.3619 + yroot      
      elseif (Insect%WingShape == 'drosophila_mutated') then
        !********************************************
        ! mutated Drosophila wing from Jan Gruber's png file
        !********************************************  
        n_fft = 70
        allocate ( ai(1:n_fft), bi(1:n_fft) )
        a0 = 0.4812548
        ai = (/0.1593968, -0.1056828, -0.0551518, 0.0508748, 0.0244538, -0.0264738,&
                -0.0080828, 0.0181228, 0.0023648, -0.0134578, -0.0037068, 0.0064508,&
                0.0028748, -0.0014258, -0.0006028, -0.0008898, -0.0020408, 0.0009218,&
                0.0029938, 0.0002768, -0.0026968, -0.0011518, 0.0017798, 0.0016538,&
                -0.0006098, -0.0012998, -0.0001918, 0.0003478, 0.0001408, 0.0003098,&
                0.0001078, -0.0005568, -0.0005998, 0.0006128, 0.0009078, -0.0003798,&
                -0.0009268, 0.0002128, 0.0009098, -0.0000598, -0.0010668, -0.0003428,&
                0.0009228, 0.0007688, -0.0003568, -0.0010458, -0.0004378, 0.0008738,&
                0.0009478, -0.0004108, -0.0012248, -0.0000638, 0.0013148, 0.0004978,&
                -0.0010638, -0.0007148, 0.0006338, 0.0007438, -0.0003278, -0.0006078,&
                0.0001838, 0.0003768, -0.0001698, -0.0002148, 0.0001318, 0.0001628,&
                -0.0000878, 0.0000068, 0.0001478, -0.0001128/) 
              
        bi = (/-0.1132588, -0.0556428, 0.0272098, 0.0221478, -0.0063798, -0.0059078,&
                  0.0043788, 0.0043208, -0.0003308, -0.0026598, -0.0013158, 0.0025178,&
                  0.0022438, -0.0023798, -0.0037048, 0.0001528, 0.0031218, 0.0022248,&
                  -0.0007428, -0.0027298, -0.0018298, 0.0014538, 0.0028888, 0.0000648,&
                  -0.0023508, -0.0009418, 0.0017848, 0.0016578, -0.0008058, -0.0017348,&
                  -0.0001368, 0.0011138, 0.0004218, -0.0005918, -0.0002798, 0.0002388,&
                  0.0002148, 0.0001408, 0.0000218, -0.0005138, -0.0003458, 0.0008208,&
                  0.0009888, -0.0007468, -0.0015298, 0.0002728, 0.0015588, 0.0002758,&
                  -0.0012498, -0.0006908,0.0008718, 0.0008848, -0.0003038, -0.0008048,&
                  -0.0001538, 0.0005418, 0.0003658, -0.0001988, -0.0003938, 0.0000048,&
                  0.0003008, 0.0000538, -0.0002748, -0.0000598, 0.0002898, 0.0001398,&
                  -0.0002108, -0.0001888, 0.0001838, 0.0001888 /)
              
        ! wing root point        
        xroot =+0.1122
        yroot =-0.0157
        ! center of circle
        xc =-0.1206 + xroot
        yc = 0.3619 + yroot        
      elseif (Insect%WingShape == 'drosophila_sandberg') then
        !********************************************
        !  Drosophila wing from Ramamurti & Sandberg ( JEB 210, 881-896, 2007)
        !********************************************        
        n_fft = 24 
        allocate ( ai(1:n_fft), bi(1:n_fft) )
        a0 = 0.4995578 
        ai = (/0.0164168,-0.1621518,0.0030938,0.0601108,-0.0083988,-0.0199988,&
        0.0049048,0.0047878,-0.0005648,-0.0001108,-0.0008638,-0.0006928,&
        0.0006608,0.0001978,0.0001558,0.0006878,-0.0007498,-0.0008018,&
        0.0003878,0.0007028,0.0000408,-0.0001108,-0.0001068,-0.0003958 &
        /)
        bi = (/-0.2083518,-0.0106488,0.0878308,-0.0018168,-0.0338278,0.0045768,&
        0.0113778,-0.0020678,-0.0026928,0.0002758,-0.0000838,-0.0001298,&
        0.0004118,0.0005638,-0.0001018,-0.0006918,-0.0002268,0.0005238,&
        0.0004008,-0.0001818,-0.0003038,-0.0000068,-0.0001218,0.0002008 &
        /)
        xc =-0.0235498  
        yc = 0.1531398 
      elseif (Insect%WingShape == 'drosophila_maeda') then
        !********************************************
        !  Drosophila wing from Maeda and Liu, similar to Liu and Aono, BB2009
        !********************************************        
        n_fft = 25
        allocate ( ai(1:n_fft), bi(1:n_fft) )
        a0 = 0.591294836514357
        ai = (/0.11389995408864588, -0.08814321795213981, -0.03495210456149335,&
        0.024972085605453047, 0.009422293191002384, -0.01680813499169695,&
        -0.006006435254421029, 0.012157932943676907, 0.00492283934032996,&
        -0.009882103857127606, -0.005421102356676356, 0.007230876076797827,&
        0.005272314598249222, -0.004519437431722127, -0.004658072133773225,&
        0.0030795046767766853, 0.003970792618725898, -0.0016315879319092456,&
        -0.002415442110272326, 0.0011118187761994598, 0.001811261693911865,&
        -2.6496695842951815E-4, -0.0012472769174353662, -1.7427507835680091E-4,&
        0.0010049640224536927/)
        bi = (/0.0961275426181888, 0.049085916171592914, -0.022051083533094627,&
        -0.014004783021121204, 0.012955446778711292, 0.006539648525493488,&
        -0.011873438993933363, -0.00691719567010525, 0.008479044683798266,&
        0.0045388280405204194, -0.008252172088956379, -0.005091347100627815,&
        0.004626409662755484, 0.004445034936616318, -0.0030708884306814804,&
        -0.004428808427471962, 0.0014113707529017868, 0.003061279043478891,&
        -8.658653756413232E-4, -0.002153349816945423, 3.317570161883452E-4,&
        0.001573518502682025, 2.14583094242007E-4, -0.0011299834277813852,&
        -5.172854674801216E-4/)
        !xc = 0.0 ! original mesh 
        xc = 0.0473 ! shifted towards t.e. to 1/4 of the root chord ("+" sign here)
        !xc = -0.0728 ! shifted towards l.e., to 0.2cmean from the l.e. (Liu and Aono BB 2009)
        yc = 0.7
      elseif (Insect%WingShape == 'flapper_sane') then
        !********************************************
        !  Mechanical model from Sane and Dickinson, JEB 205, 2002 
        !  'The aerodynamic effects...'
        !********************************************        
        n_fft = 25
        allocate ( ai(1:n_fft), bi(1:n_fft) )
        a0 = 0.5379588906565078
        ai = (/0.135338653455782,-0.06793162622123261,-0.0398235167675977,&
        0.006442194893963269,0.0012783260416583853,-0.007014398516674715,&
        0.0017710765408983137,0.006401601802033519,-2.970619204124993E-4,&
        -0.0038483478773981405,-6.180958756568494E-4,8.015784831786756E-4,&
        -6.957513357109226E-4,-1.4028929172227943E-4,0.0013484885717868547,&
        4.827827498543977E-4,-9.747844462919694E-4,-5.838504331939134E-4,&
        2.72834004831554E-4,2.8152492682871664E-5,-1.2802199282558645E-4,&
        4.117887216124469E-4,3.364169982438278E-4,-3.33258003686823E-4,&
        -3.5615733035757616E-4/)
        bi = (/2.686408368800394E-4,0.01649582345310688,0.01288513083639708,&
        0.004711436946785864,-0.0035725088809005073,-0.00898640397179334,&
        -0.003856509905612652,0.004536524572892801,0.004849677692836578,&
        2.9194421255236984E-4,-7.512780802871473E-4,7.12685261783966E-4,&
        -1.5519932673320404E-4,-0.0012695469974603026,2.2861692091158138E-4,&
        0.0016461316319681953,5.257476721137781E-4,-7.686482830046961E-4,&
        -3.108879176661735E-4,2.2437540206568518E-4,-2.578427217327782E-4,&
        -2.5120263516966855E-4,4.1693453021778877E-4,3.9290173948150096E-4,&
        -1.9762601237675826E-4/)
        xc = 0.0  
        yc = 0.6
      endif
      
      !-----------------------------------------
      ! get normalized angle (theta)
      !-----------------------------------------
      theta = atan2 (x_wing(2)-yc,x_wing(1)-xc )
      theta = ( theta + pi ) / (2.d0*pi)
      
      !-----------------------------------------
      ! construct R by evaluating the fourier series
      !-----------------------------------------
      R0 = a0/2.0
      f = 2.d0*pi    
      do i = 1, n_fft
        R0=R0 + ai(i)*dcos(f*dble(i)*theta) + bi(i)*dsin(f*dble(i)*theta)
      enddo
      deallocate (ai, bi)
      
      !-----------------------------------------
      ! get smooth (radial) step function
      !-----------------------------------------
      R = sqrt ( (x_wing(1)-xc)**2 + (x_wing(2)-yc)**2 )
      R_tmp = steps(R,R0)
      
      ! smooth also the thicknes
      z_tmp = steps(dabs(x_wing(3)),0.5d0*Insect%WingThickness) ! thickness
      mask_tmp = z_tmp*R_tmp      
      
      !-----------------------------------------
      ! set new value for mask and velocity us
      !-----------------------------------------
      if ((mask(ix,iy,iz) <= mask_tmp).and.(mask_tmp>0.0)) then 
        mask(ix,iy,iz) = mask_tmp
        ! wings have the color "1"
        mask_color(ix,iy,iz) = 1
        !------------------------------------------------
        ! solid body rotation
        ! Attention: the Matrix transpose(M) brings us back to the body
        ! coordinate system, not to the inertial frame. this is done in 
        ! the main routine Draw_Insect
        !------------------------------------------------
        v_tmp(1) = rot(2)*x_wing(3)-rot(3)*x_wing(2)
        v_tmp(2) = rot(3)*x_wing(1)-rot(1)*x_wing(3)
        v_tmp(3) = rot(1)*x_wing(2)-rot(2)*x_wing(1)
        ! note we set this only if it is a part of the wing
        us(ix,iy,iz,1:3) = matmul(transpose(M), v_tmp)
      endif
      
    endif
    endif
    endif
  end select
end subroutine DrawWing