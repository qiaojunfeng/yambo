#
# EXT_LIBS imported 
#
include lib/archive/package.list
#
INT_LIBS      = qe_pseudo slatec math77 local
YAMBO_INT_LIBS= Yio 
YLIBDRIVER    = interface main options 
YLIBDRIVER_LD = _Ydriver_options _Ydriver_interface _Ydriver_main 
YLIBIO        = modules Yio
YLIBIO_LD     = $(YLIBIO)
#
# Source code
#
BASIC_LIBS   = driver tools modules memory matrices linear_algebra parallel parser communicate common timing Yio io \
               xc_functionals interface stop_and_restart wf_and_fft bz_ops coulomb
BASIC_LIBS_LD= tools memory communicate modules matrices linear_algebra bz_ops parallel parser communicate common timing Yio io \
               xc_functionals interface stop_and_restart wf_and_fft coulomb

MAIN_LIBS    = $(BASIC_LIBS) interpolate qp_control setup tddft dipoles pol_function qp acfdt bse
MAIN_LIBS_LD = $(BASIC_LIBS_LD) interpolate qp_control setup tddft dipoles pol_function qp acfdt bse

PJ_PHLIBS    = $(BASIC_LIBS) interpolate qp_control setup tddft dipoles pol_function el-ph qp acfdt bse real_time_initialize
PJ_PHLIBS_LD = $(BASIC_LIBS_LD) interpolate qp_control setup tddft dipoles pol_function el-ph qp acfdt bse real_time_initialize

PJ_SCLIBS    = $(MAIN_LIBS) collisions hamiltonian sc
PJ_SCLIBS_LD = $(MAIN_LIBS_LD) hamiltonian collisions sc

PJ_RTLIBS    = $(BASIC_LIBS) interpolate qp_control setup \
               tddft dipoles pol_function qp acfdt bse collisions hamiltonian \
               real_time_control real_time_hamiltonian real_time_propagation \
               real_time_initialize real_time_drivers
PJ_RTLIBS_LD = $(BASIC_LIBS_LD) interpolate real_time_control qp_control setup \
               tddft dipoles pol_function qp acfdt bse hamiltonian collisions \
               real_time_hamiltonian real_time_propagation \
               real_time_initialize real_time_drivers

PJ_NLLIBS    = $(PJ_RTLIBS) nloptics
PJ_NLLIBS_LD = $(PJ_RTLIBS_LD) nloptics
#
# YAMBO sources needed by Interfaces
#
2YLIBS       = driver tools modules memory matrices linear_algebra parallel parser communicate common timing Yio io \
               setup interface stop_and_restart bz_ops 
2YLIBS_LD    = tools memory communicate modules matrices linear_algebra parallel parser communicate common timing Yio io \
               setup interface stop_and_restart bz_ops 
#
# YPP
#
YPP_BASIC_LIBS     = modules interface qp plotting k-points symmetries bits electrons dipoles
YPP_BASIC_LIBS_LD  = modules interface qp plotting k-points symmetries bits electrons dipoles
YPP_LIBS           = $(YPP_BASIC_LIBS) excitons
YPP_LIBS_LD        = $(YPP_BASIC_LIBS_LD) excitons
YPPPH_LIBS         = $(YPP_BASIC_LIBS) el-ph excitons
YPPPH_LIBS_LD      = $(YPP_BASIC_LIBS_LD) el-ph excitons
YPPRT_LIBS         = $(YPP_BASIC_LIBS) real_time excitons
YPPRT_LIBS_LD      = $(YPP_BASIC_LIBS_LD) real_time excitons
#
# YAMBO sources needed by YPP
#
YPP_MAIN_LIBS      = $(BASIC_LIBS) interpolate qp_control setup interface tddft dipoles pol_function el-ph qp bse
YPP_MAIN_LIBS_LD   = $(BASIC_LIBS_LD) interpolate qp_control setup interface tddft dipoles pol_function el-ph qp bse
YPPSC_MAIN_LIBS    = $(YPP_MAIN_LIBS) collisions hamiltonian sc
YPPSC_MAIN_LIBS_LD = $(YPP_MAIN_LIBS_LD) collisions hamiltonian sc
YPPRT_MAIN_LIBS    = $(BASIC_LIBS) real_time_control interpolate qp_control setup interface \
                     dipoles pol_function el-ph qp bse collisions hamiltonian 
YPPRT_MAIN_LIBS_LD = $(BASIC_LIBS_LD) real_time_control interpolate qp_control setup interface \
                     dipoles pol_function el-ph qp bse hamiltonian collisions
YPPNL_MAIN_LIBS    = $(BASIC_LIBS) real_time_control interpolate qp_control setup interface \
                     dipoles pol_function el-ph qp bse collisions hamiltonian nloptics 
YPPNL_MAIN_LIBS_LD = $(BASIC_LIBS_LD) real_time_control interpolate qp_control setup interface \
                     dipoles pol_function el-ph qp bse hamiltonian collisions nloptics 
