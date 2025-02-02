#
# Variable definitions
#
PRECMP=
SRC_LIBS=$(MAIN_LIBS)
EXE_LIBS=$(MAIN_LIBS_LD)
ifneq (,$(findstring yambo_sc,$(MAKECMDGOALS)))
 PRECMP=-D_SC
 SRC_LIBS=$(PJ_SCLIBS)
 EXE_LIBS=$(PJ_SCLIBS_LD)
else ifneq (,$(findstring yambo_rt_iterative,$(MAKECMDGOALS)))
 PRECMP=-D_RT -D_RT_SCATT -D_ELPH -D_PHEL -D_ELPH_ITERATIVE
 SRC_LIBS=$(PJ_RTITLIBS)
 EXE_LIBS=$(PJ_RTITLIBS_LD)
else ifneq (,$(findstring yambo_rt,$(MAKECMDGOALS)))
 PRECMP=-D_RT 
 SRC_LIBS=$(PJ_RTLIBS)
 EXE_LIBS=$(PJ_RTLIBS_LD)
else ifneq (,$(findstring yambo_ph,$(MAKECMDGOALS)))
 PRECMP=-D_ELPH -D_PHEL
 SRC_LIBS=$(PJ_PHLIBS)
 EXE_LIBS=$(PJ_PHLIBS_LD)
else ifneq (,$(findstring yambo_nl,$(MAKECMDGOALS)))
 PRECMP=-D_NL -D_RT -D_DOUBLE
 SRC_LIBS=$(PJ_NLLIBS)
 EXE_LIBS=$(PJ_NLLIBS_LD)
endif
#
# Compilation
#
yambo yambo_ph yambo_sc yambo_rt yambo_nl: 
	@rm -f ${compdir}/log/"compile_"$@".log"
	@touch config/stamps_and_lists/compiling_$@.stamp
	@$(call todo_precision,$(PRECMP))
	@$(MAKE) $(MAKEFLAGS) dependencies
	@$(MAKE) $(MAKEFLAGS) ext-libs
	@$(MAKE) $(MAKEFLAGS) int-libs
	@+LIBS="$(YLIBDRIVER)";LAB="$@_Ydriver_";BASE="lib/yambo/driver/src";ADF="$(PRECMP) -D_yambo";$(todo_lib);$(mk_lib)
	@+LIBS="$(SRC_LIBS)";BASE="src";ADF="$(PRECMP)";$(todo_lib);$(mk_lib)
	@+X2DO="$@";BASE="driver";XLIBS="$(EXE_LIBS)";ADF="$(PRECMP)";$(todo_driver)
	@+X2DO="$@";BASE="driver";XLIBS="$(EXE_LIBS)";ADF="$(PRECMP)";$(mk_exe)
