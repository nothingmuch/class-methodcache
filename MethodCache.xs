/* BLECH!!!! needed for HvMROMETA */
#define PERL_CORE
#include "EXTERN.h"
#include "perl.h"
#undef PERL_CORE
#include "XSUB.h"

#include "ppport.h"

#ifdef HvMROMETA
	#define HvCURGEN(stash) ( HvMROMETA(stash)->cache_gen + PL_sub_generation )
#else
	#define HvCURGEN(stash) PL_sub_generation
#endif

STATIC GV *sv_gv(SV *sv) {
	if ( sv ) {
		if ( SvROK(sv) )
			sv = SvRV(sv);

		switch ( SvTYPE(sv) ) {
			case SVt_PVGV:
				return (GV *)sv;
		}
	}

	Perl_croak(aTHX_ "Must provide a glob ref");
}

STATIC HV *sv_stash (SV *sv) {
	HV *hv;
	if ( SvROK(sv) ) {
			SV *rv = SvRV(sv);
			if ( sv_isobject(rv) ) {
				return SvSTASH(rv);
			} else {
				if ( SvTYPE(rv) == SVt_PVHV ) {
					hv = (HV *)rv;
					if ( HvNAME(hv) )
						return hv;
				}
				/* if SVt_PVGV maybe try e.g. *Foo for "Foo" ? */
			}
	} else if ( SvOK(sv) ) {
		return gv_stashsv(sv, 0);
	}

	Perl_croak(aTHX_ "Must provide a class name");
}


MODULE = Class::MethodCache	PACKAGE = Class::MethodCache

U32
get_class_gen (sv)
	INPUT:
		SV *sv
	PREINIT:
		HV *stash = sv_stash(sv);
	CODE:
		RETVAL = HvCURGEN(stash);
	OUTPUT: RETVAL

void
update_cvgen (sv)
	INPUT:
		SV *sv
	PREINIT:
		GV *gv = sv_gv(sv);
	CODE:
		if ( GvCVGEN(gv) )
			GvCVGEN(gv) = HvCURGEN(GvSTASH(gv));
		else
			Perl_croak(aTHX_ "Won't update cvgen for real method.");

void
delete_cv (sv)
	INPUT:
		SV *sv
	PREINIT:
		GV *gv = sv_gv(sv);
	CODE:
		if ( GvCV(gv) )
			SvREFCNT_dec(GvCV(gv));
		GvCV(gv) = Nullcv;
		GvCVGEN(gv) = 0;

SV *
get_cached_method (sv)
	INPUT:
		SV *sv
	PREINIT:
		GV *gv = sv_gv(sv);
	PPCODE:
		if ( GvCV(gv) && GvCVGEN(gv) == HvCURGEN(GvSTASH(gv)) )
			XPUSHs(sv_2mortal(newRV_inc((SV *)GvCV(gv))));
		else
			XPUSHs(&PL_sv_undef);

void
set_cached_method (sv, cv)
	INPUT:
		SV *sv
		CV *cv
	PREINIT:
		GV *gv = sv_gv(sv);
	CODE:
		if ( GvREFCNT(gv) == 1 ) {
			if ( GvCV(gv) ) {
				if ( GvCVGEN(gv) == 0 )
					Perl_croak(aTHX_ "Won't overwrite real method.");
				SvREFCNT_dec(GvCV(gv));
			}
			SvREFCNT_inc(cv);
			GvCV(gv) = cv;
			GvCVGEN(gv) = HvCURGEN(GvSTASH(gv));
		} else {
			Perl_croak(aTHX_ "Setting a cached method in a cached GV might cause strange things to happen.");
		}

SV *
get_cv (sv)
	INPUT:
		SV *sv
	PREINIT:
		GV *gv = sv_gv(sv);
	PPCODE:
		if ( GvCV(gv) )
			XPUSHs(sv_2mortal(newRV_inc((SV *)GvCV(gv))));
		else
			XPUSHs(&PL_sv_undef);

SV *
set_cv (sv, cv_sv)
	INPUT:
		SV *sv
		SV *cv_sv
	PREINIT:
		CV *cv;
		GV *gv = sv_gv(sv);
	PPCODE:
		if ( !SvOK(cv_sv) ) {
			cv = Nullcv;
		} else if ( SvROK(cv_sv) && SvTYPE(SvRV(cv_sv)) == SVt_PVCV ) {
			cv = (CV *)SvRV(cv_sv);
			SvREFCNT_inc(cv);
		} else {
			Perl_croak(aTHX_ "set_cv accepts either a code reference or undef");
		}

		if ( GvCV(gv) )
			SvREFCNT_dec(GvCV(gv));
		GvCV(gv) = cv;


U32
get_gv_refcount (sv)
	INPUT:
		SV *sv
	PREINIT:
		GV *gv = sv_gv(sv);
	CODE:
		RETVAL = GvREFCNT(gv); /* refcount of the GP, not the GV */
	OUTPUT: RETVAL

void
set_cvgen (sv, gen)
	INPUT:
		SV *sv
		U32 gen
	PREINIT:
		GV *gv = sv_gv(sv);
	CODE:
		GvCVGEN(gv) = gen;

U32
get_cvgen (sv)
	INPUT:
		SV *sv
	PREINIT:
		GV *gv = sv_gv(sv);
	CODE:
		RETVAL = GvCVGEN(gv);
	OUTPUT: RETVAL

void
mro_isa_changed_in (sv)
	INPUT:
		SV *sv
	PREINIT:
		HV *stash = sv_stash(sv);
	CODE:
#ifdef mro_isa_changed_in
		mro_isa_changed_in(stash);
#else
		PL_sub_generation++;
#endif

