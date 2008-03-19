/*
    # Win32::API::Callback - Perl Win32 API Import Facility
    #
    # Version: 0.40
    # Date: 07 Mar 2003
    # Author: Aldo Calpini <dada@perl.it>
	# $Id: Callback.xs,v 1.0 2002/03/19 10:25:00 dada Exp $
 */

#define  WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <memory.h>

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#define CROAK croak

#include "../API.h"

#pragma optimize("", off)

/*
 * some Perl macros for backward compatibility
 */
#ifdef NT_BUILD_NUMBER
#define boolSV(b) ((b) ? &sv_yes : &sv_no)
#endif

#ifndef PL_na
#	define PL_na na
#endif

#ifndef SvPV_nolen
#	define SvPV_nolen(sv) SvPV(sv, PL_na)
#endif

#ifndef call_pv
#	define call_pv(name, flags) perl_call_pv(name, flags)
#endif

#ifndef call_sv
#	define call_sv(name, flags) perl_call_sv(name, flags)
#endif

int PerformCallback(SV* self, int nparams, APIPARAM* params);

SV* fakesv;
int fakeint;
char *fakepointer;

int RelocateCode(unsigned char* cursor, unsigned int displacement) {
	int skip;
	unsigned int reladdr;

	switch(*cursor) {

		// skip +0
		case 0x50:	// push eax
		case 0x51:	// push ecx
		case 0x55:	// push ebp
		case 0x56:	// push esi
		case 0x59:	// pop ecx
		case 0x5E:	// pop esi
		case 0xC3:	// ret
		case 0xC9:	// leave
			skip = 0;
			break;

		// skip +1
		case 0x33:	// xor
		case 0x3B:	// cmp
		case 0x6A:	// push (1 byte)
		case 0x74:	// je
		case 0x75:	// jne
		case 0x7D:	// jge
		case 0x7E:	// jle
		case 0x85:	// test
		case 0xEB:	// jmp
			skip = 1;
			break;

		// skip +1/+2
		case 0x2B:
			if(*(cursor+1) == 0x30	// sub esi, dword ptr [eax]
			) {
				skip = 1;
				break;
			} else
			if (*(cursor+1) == 0x45	// sub eax, dword ptr [ebp+1 byte]
			) {
				skip = 2;
				break;
			}

		// skip +1/+2
		case 0x89:

			if(*(cursor+1) == 0x01	// mov dword ptr [ecx], eax
			|| *(cursor+1) == 0x08	// mov dword ptr [eax], ecx
			|| *(cursor+1) == 0x30	// mov dword ptr [eax], esi
			) {
				skip = 1;
				break;
			}
			if(*(cursor+1) == 0x45	// mov dword ptr [ebp+1 byte], eax
			|| *(cursor+1) == 0x4D	// mov dword ptr [ebp+1 byte], ecx
			|| *(cursor+1) == 0x04	// mov dword ptr [edx+ecx*1 byte], eax
			) {
				skip = 2;
				break;
			}

		// skip +1/+2
		case 0x8B:

			if(*(cursor+1) == 0x00	// mov eax,dword ptr [eax]
			|| *(cursor+1) == 0x09	// mov ecx,dword ptr [ecx]
			|| *(cursor+1) == 0x0E	// mov ecx,dword ptr [esi]
			|| *(cursor+1) == 0xEC	// mov ebp,esp
			|| *(cursor+1) == 0xF0	// mov esi,eax
			) {
				skip = 1;
				break;
			} else
			if(*(cursor+1) == 0x40	// mov eax,dword ptr [eax+1 byte]
			|| *(cursor+1) == 0x45	// mov eax,dword ptr [ebp+1 byte]
			|| *(cursor+1) == 0x4D	// mov ecx,dword ptr [ebp+1 byte]
			|| *(cursor+1) == 0x55	// mov edx,dword ptr [ebp+1 byte]
			|| *(cursor+1) == 0x75	// mov esi,dword ptr [ebp+1 byte]
			) {
				skip = 2;
				break;
			}

		case 0xFF:
			if(*(cursor+1) == 0x30	// push dword ptr [eax]
			) {
				skip = 1;
				break;
			} else
			if(*(cursor+1) == 0x75	// push dword ptr [epb+1 byte]
			|| *(cursor+1) == 0x34	// push dword ptr [ecx+eax*4]
			) {
				skip = 2;
				break;
			} else
			if(*(cursor+1) == 0x15	// call dword ptr ds:(4 byte)
			|| *(cursor+1) == 0x35	// push dword ptr ds:(4 byte)
			) {
				skip = 5;
				break;
			}

		// skip +2
		case 0xC1:	// sar
			skip = 2;
			break;

		// skip +2/+3
		case 0x83:
			if(*(cursor+1) != 0x65	// add|sub|cmp
			) {
				skip = 2;
				break;
			} else
			if(*(cursor+1) == 0x65	// add|sub|cmp
			) {
				skip = 3;
				break;
			}

		// skip +4
		case 0x25:	// and
		case 0x68:	// push (4 bytes)
			skip = 4;
			break;


		// skip +6
		case 0xC7:	// mov dword ptr (ebp+1 byte), (4 byte)
			skip = 6;
			break;

		case 0xE8:
			// we relocate here!
			reladdr = *((int*)(cursor + 1));
			*((int*)(cursor + 1)) = (unsigned int) (reladdr - displacement);
			skip = 4;
			break;

		default:
#ifdef WIN32_API_DEBUG
			printf("(C)RelocateCode: %08X ????    0x%x\n", cursor, *cursor);
#endif
			skip = 0;
			break;
	}
#ifdef WIN32_API_DEBUG
	{
		int i;
		printf("(C)RelocateCode: %08X skip +%1d ", cursor, skip);
		for(i = 0; i <= skip; i++) {
			printf("%02X ", *(cursor+i));
		}
		printf("\n");
	}
#endif
	return 1 + skip;
}


// SV* CallbackMakeStruct(SV* self, int nparam, char *addr) {
int CallbackMakeStruct(SV* self, int nparam, char *addr) {
#ifdef dTHX
	dTHX;
#endif
	dSP;
	SV* structobj = NULL;
	char ikey[80];
/*
#ifdef WIN32_API_DEBUG
	printf("(C)CallbackMakeStruct: got self='%s'\n", SvPV_nolen(self));
	sv_dump(self);
	if(SvROK(self)) sv_dump(SvRV(self));
	printf("(C)CallbackMakeStruct: got nparam=%d\n", nparam);
	printf("(C)CallbackMakeStruct: got addr=0x%08x\n", addr);
	// memcpy( SvPV_nolen(self), 0, 1000);
#endif
*/
	ENTER;
	SAVETMPS;
	// XPUSHs(sv_2mortal(newSVrv(self, "Win32::API::Callback")));
	PUSHMARK(SP);
	XPUSHs(sv_2mortal(newSVsv(self)));
	XPUSHs(sv_2mortal(newSViv(nparam)));
	XPUSHs(sv_2mortal(newSViv((long) addr)));
	PUTBACK;
	call_pv("Win32::API::Callback::MakeStruct", G_SCALAR);
	SPAGAIN;
	structobj = newSVsv(POPs);

	itoa(nparam, ikey, 10);
	hv_store( (HV*)SvRV(self), ikey, strlen(ikey), structobj, 0 );
#ifdef WIN32_API_DEBUG
	printf("(C)CallbackTemplate: self{'%s'}='%s'\n", ikey, SvPV_nolen(*(hv_fetch( (HV*)SvRV(self), ikey, strlen(ikey), 0 ))));
#endif
/*
#ifdef WIN32_API_DEBUG
	printf("(C)CallbackMakeStruct: structobj='%s'\n", SvPV_nolen(structobj));
	sv_dump(structobj);
	if(SvROK(structobj)) sv_dump(SvRV(structobj));
#endif
*/
	PUTBACK;
	FREETMPS;
	LEAVE;
	return 1;
	// return structobj;
}

int CALLBACK CallbackTemplate() {
	SV* myself = (SV*) 0xC0DE0001; 	// checkpoint_SELFPOS
	int nparams = 0xC0DE0002; 		// checkpoint_NPARAMS
	APIPARAM* params;
	unsigned int checkpoint;
	int i, r;

#ifdef WIN32_API_DEBUG
	printf("(C)CallbackTemplate: nparams=%d\n", nparams);
//	printf("(C)CallbackTemplate: myself='%s'\n", SvPV_nolen(myself));
//	sv_dump(myself);
//	if(SvROK(myself)) sv_dump(SvRV(myself));
#endif

	params = (APIPARAM*) safemalloc(  nparams * sizeof(APIPARAM) );
	checkpoint = 0xC0DE0010;		// checkpoint_PUSHI
	i = 0xC0DE0003;					// checkpoint_IPOS
	params[i].t = T_INTEGER;
	params[i].l = fakeint;
#ifdef WIN32_API_DEBUG
	printf("(C)CallbackTemplate: PUSHI(%d)=", i);
	printf("%d\n", params[i].l);
#endif
	checkpoint = 0xC0DE0020;		// checkpoint_PUSHL
	i = 0xC0DE0003;					// checkpoint_IPOS
	params[i].t = T_NUMBER;
	params[i].l = fakeint;
	checkpoint = 0xC0DE0030;		// checkpoint_PUSHP
	i = 0xC0DE0003;					// checkpoint_IPOS
	params[i].t = T_POINTER;
	params[i].p = (char*) fakeint;
#ifdef WIN32_API_DEBUG
	printf("(C)CallbackTemplate: PUSHP(%d)=", i);
	printf("%08x (%s)\n", params[i].p, params[i].p);
#endif
	checkpoint = 0xC0DE0040;		// checkpoint_PUSHS
	i = 0xC0DE0003;					// checkpoint_IPOS
	params[i].t = T_STRUCTURE;
	params[i].p = (char*) fakeint;
#ifdef WIN32_API_DEBUG
	printf("(C)CallbackTemplate: PUSHS(%d)=", i);
	printf("%08x\n", params[i].p);
#endif

/*
	checkpoint = 0xC0DE0050;		// checkpoint_PUSHD
	i = 0xC0DE0003;					// checkpoint_IPOS
	params[i].t = T_DOUBLE;
	params[i].d = fakedouble;
*/

	checkpoint = 0xC0DE9999;		// checkpoint_END
#ifdef WIN32_API_DEBUG
	printf("(C)CallbackTemplate: Calling PerformCallback...\n");
#endif
	r = PerformCallback(myself, nparams, params);
#ifdef WIN32_API_DEBUG
	printf("(C)CallbackTemplate: r=%d\n", r);
#endif
	safefree(params);
#ifdef WIN32_API_DEBUG
	printf("(C)CallbackTemplate: RETURNING\n");
#endif
	return r;
}

int PerformCallback(SV* self, int nparams, APIPARAM* params) {
	SV* mycode;
	int i = 0;
	char ikey[80];
	unsigned int checkpoint;
	I32 size;
	int r;
#ifdef dTHX
	dTHX;
#endif
	dSP;

	mycode = *(hv_fetch((HV*)SvRV(self), "sub", 3, FALSE));

	for(i=0; i < nparams; i++) {
		if(params[i].t == T_STRUCTURE) {
			CallbackMakeStruct(self, i, params[i].p);
		}
	}

	ENTER;
	SAVETMPS;
	PUSHMARK(SP);
	for(i=0; i < nparams; i++) {
		switch(params[i].t) {
		case T_STRUCTURE:
			itoa(i, ikey, 10);
			XPUSHs(sv_2mortal(*(hv_fetch((HV*)SvRV(self), ikey, strlen(ikey), 0))));
			break;
		case T_POINTER:
			XPUSHs(sv_2mortal(newSVpv((char *) params[i].p, 0)));
			break;
		case T_INTEGER:
		case T_NUMBER:
			XPUSHs(sv_2mortal(newSViv((int) params[i].l)));
			break;
		}
	}

	PUTBACK;
	call_sv(mycode, G_EVAL | G_SCALAR);
	SPAGAIN;
	r = POPi;
	PUTBACK;
	FREETMPS;
	LEAVE;
	return r;
}

unsigned char * CallbackCreate(int nparams, APIPARAM *params, SV* self, SV* callback) {

	unsigned char * code;
	unsigned char * cursor;
	unsigned int i, j, r, toalloc, displacement;
	unsigned char ebpcounter = 8;
	unsigned char * source = (unsigned char *) (void *) CallbackTemplate;
	BOOL done = FALSE;
	unsigned int distance = 0;
	BOOL added_INIT_STRUCT = FALSE;
	int N_structs = 0;

	unsigned int
		checkpoint_PUSHI = 0,
		checkpoint_PUSHL = 0,
		checkpoint_PUSHP = 0,
		checkpoint_PUSHS = 0,
		checkpoint_END = 0,
		checkpoint_DONE = 0;

	unsigned int
		section_START,
		section_PUSHI,
		section_PUSHL,
		section_PUSHP,
		section_PUSHS,
		section_END;

	cursor = source;

	while(!done) {

		if(*(cursor+0) == 0x10
		&& *(cursor+1) == 0x00
		&& *(cursor+2) == 0xDE
		&& *(cursor+3) == 0xC0
		) {
#ifdef WIN32_API_DEBUG
			printf("(C)CallbackCreate.Study: checkpoint_PUSHI=%d\n", distance);
#endif
			checkpoint_PUSHI = distance - 3;
		}

		if(*(cursor+0) == 0x20
		&& *(cursor+1) == 0x00
		&& *(cursor+2) == 0xDE
		&& *(cursor+3) == 0xC0
		) {
#ifdef WIN32_API_DEBUG
			printf("(C)CallbackCreate.Study: checkpoint_PUSHL=%d\n", distance);
#endif
			checkpoint_PUSHL = distance - 3;
		}

		if(*(cursor+0) == 0x30
		&& *(cursor+1) == 0x00
		&& *(cursor+2) == 0xDE
		&& *(cursor+3) == 0xC0
		) {
#ifdef WIN32_API_DEBUG
			printf("(C)CallbackCreate.Study: checkpoint_PUSHP=%d\n", distance);
#endif
			checkpoint_PUSHP = distance - 3;
		}

		if(*(cursor+0) == 0x40
		&& *(cursor+1) == 0x00
		&& *(cursor+2) == 0xDE
		&& *(cursor+3) == 0xC0
		) {
#ifdef WIN32_API_DEBUG
			printf("(C)CallbackCreate.Study: checkpoint_PUSHS=%d\n", distance);
#endif
			checkpoint_PUSHS = distance - 3;
		}

		if(*(cursor+0) == 0x99
		&& *(cursor+1) == 0x99
		&& *(cursor+2) == 0xDE
		&& *(cursor+3) == 0xC0
		) {
#ifdef WIN32_API_DEBUG
			printf("(C)CallbackCreate.Study: checkpoint_END=%d\n", distance);
#endif
			checkpoint_END = distance - 3;
		}


#ifdef WIN32_API_DEBUG
		if(checkpoint_END > 0) {
			printf("(C)CallbackCreate.Study: after END got 0x%02X at %d\n", *cursor, distance);
		}
#endif
	
		
		

		if(*(cursor+0) == 0xC9	// leave
		&& *(cursor+1) == 0xC3	// ret
		) {
#ifdef WIN32_API_DEBUG
			printf("(C)CallbackCreate.Study: checkpoint_DONE=%d\n", distance);
#endif
			checkpoint_DONE = distance + 2;
			done = TRUE;
		}

		if(cursor >= (unsigned char *) PerformCallback) {
			checkpoint_DONE = distance;
		 	done = TRUE;
		}
		// TODO: add fallback (eg. if cursor >= CallbackCreate then done)

		cursor++;
		distance++;
	}

	section_START 	= checkpoint_PUSHI;
	section_PUSHI	= checkpoint_PUSHL	- checkpoint_PUSHI;
	section_PUSHL	= checkpoint_PUSHP	- checkpoint_PUSHL;
	section_PUSHP	= checkpoint_PUSHS	- checkpoint_PUSHP;
	section_PUSHS	= checkpoint_END 	- checkpoint_PUSHS;
	section_END		= checkpoint_DONE	- checkpoint_END;

	toalloc = section_START;

	toalloc += section_END;
	toalloc += 3; // we'll need 3 extra bytes for the callback epilogue

#ifdef WIN32_API_DEBUG
	printf("(C)CallbackCreate: toalloc=%d\n", toalloc);
#endif

	for(i=0; i<nparams; i++) {

		if(params[i].t == T_NUMBER) {
			toalloc += section_PUSHI;
		}

		if(params[i].t == T_POINTER) {
			toalloc += section_PUSHP;
		}

		if(params[i].t == T_STRUCTURE) {
			toalloc += section_PUSHS;
		}

#ifdef WIN32_API_DEBUG
		printf("(C)CallbackCreate: summing param[%d] (%d), toalloc=%d\n", i, params[i].t, toalloc);
#endif

	}

#ifdef WIN32_API_DEBUG
	printf("(C)CallbackCreate: fakeint          is at: 0x%08X\n", &fakeint);
	printf("(C)CallbackCreate: fakepointer      is at: 0x%08X\n", &fakepointer);
	printf("(C)CallbackCreate: fakesv           is at: 0x%08X\n", &fakesv);
	printf("(C)CallbackCreate: CallbackTemplate is at: 0x%08X\n", CallbackTemplate);
	printf("(C)CallbackCreate: allocating %d bytes\n", toalloc);
#endif
	code = (unsigned char *) malloc(toalloc);

	if(code == NULL) {
		printf("can't allocate callback code, aborting!\n");
		return 0;
	}
	cursor = code;

	displacement = code - source;
#ifdef WIN32_API_DEBUG
	printf("(C)CallbackCreate: source       = 0x%x\n", source);
	printf("(C)CallbackCreate: code         = 0x%x\n", code);
#endif

#ifdef WIN32_API_DEBUG
	printf("(C)CallbackCreate: COPYING SECTION section_START (%d bytes)\n", section_START);
#endif
	memcpy( (void *) cursor, source, section_START);

	for(i=0; i < section_START; i++) {
		r = RelocateCode(cursor, displacement);
		if(r == 7
		&& *(cursor+3) == 0xDE
		&& *(cursor+4) == 0xC0
		&& *(cursor+5) == 0xFF
		&& *(cursor+6) == 0xFF) {
#ifdef WIN32_API_DEBUG
			printf("(C)CallbackCreate:     FOUND CODE at 0x%x...\n", cursor+3);
			printf("(C)CallbackCreate:     callback    = 0x%x\n", callback);
#endif
			*((int*)(cursor+3)) = (int) callback;

#ifdef WIN32_API_DEBUG
			printf("(C)CallbackCreate:     CODE now is = 0x%x\n", *((int*)(cursor+3)));
#endif
		}
		if(r == 7
		&& *(cursor+3) == 0x01
		&& *(cursor+4) == 0x00
		&& *(cursor+5) == 0xDE
		&& *(cursor+6) == 0xC0) {
#ifdef WIN32_API_DEBUG
			printf("(C)CallbackCreate:     FOUND SELF at 0x%08x...\n", cursor+3);
			printf("(C)CallbackCreate:     self        = 0x%08x\n", self);
#endif
			hv_store((HV*) SvRV(self), "selfpos", 7, newSViv((long) cursor+3), 0);
			*((int*)(cursor+3)) = (int) self;

#ifdef WIN32_API_DEBUG
			printf("(C)CallbackCreate:     SELF now is = 0x%08x\n", *((int*)(cursor+3)));
#endif
		}
		if(r == 7
		&& *(cursor+3) == 0x02
		&& *(cursor+4) == 0x00
		&& *(cursor+5) == 0xDE
		&& *(cursor+6) == 0xC0) {
#ifdef WIN32_API_DEBUG
			printf("(C)CallbackCreate:     FOUND NPARAMS 0x%08x...\n", cursor+3);
			printf("(C)CallbackCreate:     NPARAMS     = 0x%08x\n", nparams);
#endif
			*((int*)(cursor+3)) = nparams;

#ifdef WIN32_API_DEBUG
			printf("(C)CallbackCreate:     NPARAMS now = 0x%08x\n", *((int*)(cursor+3)));
#endif
		}

		cursor += r;
		if(r > 1) i += (r-1);
	}

	for(j=0; j<nparams; j++) {

		if(params[j].t == T_STRUCTURE) {
#ifdef WIN32_API_DEBUG
			printf("(C)CallbackCreate: COPYING SECTION section_PUSHS (%d bytes)\n", section_PUSHS);
#endif
			memcpy( (void *) cursor, source + checkpoint_PUSHS, section_PUSHS );
			displacement = cursor - (source + checkpoint_PUSHS);

			for(i=0; i < section_PUSHS; i++) {

				if(*(cursor+0) == 0x8B
				&& *(cursor+1) == 0x15
				&& *((int*)(cursor+2)) == (int) &fakeint
				) {
#ifdef WIN32_API_DEBUG
					printf("(C)CallbackCreate:     FOUND THE SVPV at 0x%x\n", cursor);
					printf("(C)CallbackCreate:     writing EBP+%02Xh\n", ebpcounter);
#endif
					*(cursor+0) = 0x8B;
					*(cursor+1) = 0x55;
					*(cursor+2) = ebpcounter;
					*(cursor+3) = 0x90;		// nop
					*(cursor+4) = 0x90;		// nop
					*(cursor+5) = 0x90;		// nop
					cursor += 5;
					i += 4;
				} else
				if(*(cursor+0) == 0xC7
				&& *(cursor+1) == 0x45
				&& *(cursor+2) == 0xEC
				&& *((int*)(cursor+3)) == 0xC0DE0003
				) {
#ifdef WIN32_API_DEBUG
					printf("(C)CallbackCreate:     FOUND NPARAM   at 0x%x\n", cursor);
					printf("(C)CallbackCreate:     writing         = 0x%08X\n", j);
#endif
					*((int*)(cursor+3)) = j;
#ifdef WIN32_API_DEBUG
					printf("(C)CallbackCreate:     NPARAM now is   = 0x%08X\n", *((int*)(cursor+3)));
#endif
					cursor += 6;
					i += 5;
				} else {
					r = RelocateCode(cursor, displacement);
					cursor += r;
					if(r > 1) i += (r-1);
				}

			}
		}

		if(params[j].t == T_NUMBER) {
#ifdef WIN32_API_DEBUG
			printf("(C)CallbackCreate: COPYING SECTION section_PUSHI (%d bytes)\n", section_PUSHI);
#endif
			memcpy( (void *) cursor, source + checkpoint_PUSHI, section_PUSHI );
			displacement = cursor - (source + checkpoint_PUSHI);

			for(i=0; i < section_PUSHI; i++) {

				if(*(cursor+0) == 0x8B
				&& *(cursor+1) == 0x15
				&& *((int*)(cursor+2)) == (int) &fakeint
				) {
#ifdef WIN32_API_DEBUG
					printf("(C)CallbackCreate:     FOUND THE SVIV at 0x%x\n", cursor);
					printf("(C)CallbackCreate:     writing EBP+%02Xh\n", ebpcounter);
#endif
					*(cursor+0) = 0x8B;
					*(cursor+1) = 0x55;
					*(cursor+2) = ebpcounter;
					*(cursor+3) = 0x90;		// push ecx
					*(cursor+4) = 0x90;		// push esi
					*(cursor+5) = 0x90;		// pop esi
					cursor += 5;
					i += 4;
				} else
				if(*(cursor+0) == 0xC7
				&& *(cursor+1) == 0x45
				&& *(cursor+2) == 0xEC
				&& *((int*)(cursor+3)) == 0xC0DE0003
				) {
#ifdef WIN32_API_DEBUG
					printf("(C)CallbackCreate:     FOUND NPARAM   at 0x%x\n", cursor);
					printf("(C)CallbackCreate:     writing         = 0x%08X\n", j);
#endif
					*((int*)(cursor+3)) = j;
#ifdef WIN32_API_DEBUG
					printf("(C)CallbackCreate:     NPARAM now is   = 0x%08X\n", *((int*)(cursor+3)));
#endif
					cursor += 6;
					i += 5;
				} else {
					r = RelocateCode(cursor, displacement);
					cursor += r;
					if(r > 1) i += (r-1);
				}

			}
		}


		if(params[j].t == T_POINTER) {
#ifdef WIN32_API_DEBUG
			printf("(C)CallbackCreate: COPYING SECTION section_PUSHP (%d bytes)\n", section_PUSHP);
#endif
			memcpy( (void *) cursor, source + checkpoint_PUSHP, section_PUSHP );
			displacement = cursor - (source + checkpoint_PUSHP);

			for(i=0; i < section_PUSHP; i++) {

				if(*(cursor+0) == 0x8B
				&& *(cursor+1) == 0x15
				&& *((int*)(cursor+2)) == (int) &fakeint
				) {
#ifdef WIN32_API_DEBUG
					printf("(C)CallbackCreate:     FOUND THE SVPV at 0x%x\n", cursor);
					printf("(C)CallbackCreate:     writing EBP+%02Xh\n", ebpcounter);
#endif
					*(cursor+0) = 0x8B;
					*(cursor+1) = 0x55;
					*(cursor+2) = ebpcounter;
					*(cursor+3) = 0x90;		// nop
					*(cursor+4) = 0x90;		// nop
					*(cursor+5) = 0x90;		// nop
					cursor += 5;
					i += 4;
				} else
				if(*(cursor+0) == 0xC7
				&& *(cursor+1) == 0x45
				&& *(cursor+2) == 0xEC
				&& *((int*)(cursor+3)) == 0xC0DE0003
				) {
#ifdef WIN32_API_DEBUG
					printf("(C)CallbackCreate:     FOUND NPARAM   at 0x%x\n", cursor);
					printf("(C)CallbackCreate:     writing         = 0x%08X\n", j);
#endif
					*((int*)(cursor+3)) = j;
#ifdef WIN32_API_DEBUG
					printf("(C)CallbackCreate:     NPARAM now is   = 0x%08X\n", *((int*)(cursor+3)));
#endif
					cursor += 6;
					i += 5;
				} else {
					r = RelocateCode(cursor, displacement);
					cursor += r;
					if(r > 1) i += (r-1);
				}

			}
		}

		ebpcounter += 4;
	}

#ifdef WIN32_API_DEBUG
	printf("(C)CallbackCreate: COPYING SECTION section_END (%d bytes) at 0x%08x\n", section_END, cursor);
#endif
	memcpy( (void *) cursor, source + checkpoint_END, section_END );

	displacement = cursor - (source + checkpoint_END);

	for(i=0; i < section_END; i++) {
		r = RelocateCode(cursor, displacement);
		cursor += r;
		if(r > 1) i += (r-1);
	}

#ifdef WIN32_API_DEBUG
	printf("(C)CallbackCreate: adjusting callback epilogue...\n");
#endif

	// #### back up two bytes (leave/ret)
	cursor -= 2;

	// #### insert the callback epilogue
	*(cursor+0) = 0x8B; // mov esp,ebp
	*(cursor+1) = 0xE5;
	*(cursor+2) = 0x5D; // pop ebp
	*(cursor+3) = 0xC2; // ret + 2 bytes
	*(cursor+4) = ebpcounter - 8;
	*(cursor+5) = 0x00;

#ifdef WIN32_API_DEBUG
	printf("(C)CallbackCreate: DONE!\n");
#endif

	return code;
}


MODULE = Win32::API::Callback   PACKAGE = Win32::API::Callback

PROTOTYPES: DISABLE

unsigned int
CallbackCreate(self)
	SV* self
PREINIT:
    APIPARAM *params;
    int    iParam;
    long   lParam;
    float  fParam;
    double dParam;
	char   cParam;
    char  *pParam;
    LPBYTE ppParam;
    HV*		obj;
    SV**	obj_sub;
    SV*		sub;
    SV**	obj_proto;
    SV**	obj_in;
    SV**	obj_out;
    SV**	obj_intypes;
    SV**	in_type;
    AV*		inlist;
    AV*		intypes;
    int nin, tout, i;
CODE:
#ifdef WIN32_API_DEBUG
	printf("(XS)CallbackCreate: got self='%s'\n", SvPV_nolen(self));
	printf("(XS)CallbackCreate: self dump:\n");
	sv_dump(self);
	if(SvROK(self)) sv_dump(SvRV(self));
#endif
    obj = (HV*) SvRV(self);
    obj_in = hv_fetch(obj, "in", 2, FALSE);
    obj_out = hv_fetch(obj, "out", 3, FALSE);
    inlist = (AV*) SvRV(*obj_in);
    nin  = av_len(inlist);
#ifdef WIN32_API_DEBUG
	printf("(XS)CallbackCreate: nin=%d\n", nin);
#endif
    tout = SvIV(*obj_out);
#ifdef WIN32_API_DEBUG
	printf("(XS)CallbackCreate: tout=%d\n", tout);
#endif
	obj_sub = hv_fetch(obj, "sub", 3, FALSE);
	sub = *obj_sub;
#ifdef WIN32_API_DEBUG
	printf("(XS)CallbackCreate: self.sub='%s'\n", SvPV_nolen(sub));
	printf("(XS)CallbackCreate: self.sub dump:\n");
	sv_dump(sub);
	if(SvROK(sub)) sv_dump(SvRV(sub));
#endif
    EXTEND(SP, 1);
    if(nin >= 0) {
        params = (APIPARAM *) safemalloc((nin+1) * sizeof(APIPARAM));
        for(i = 0; i <= nin; i++) {
            in_type = av_fetch(inlist, i, 0);
            params[i].t = SvIV(*in_type);
            // params[i].t = T_NUMBER;
        }
	}
	RETVAL = (unsigned int) CallbackCreate(nin+1, params, self, sub);
#ifdef WIN32_API_DEBUG
	printf("(XS)CallbackCreate: got RETVAL=0x%08x\n", RETVAL);
#endif
	if(nin > 0) safefree(params);
#ifdef WIN32_API_DEBUG
	printf("(XS)CallbackCreate: returning to caller\n");
#endif
OUTPUT:
	RETVAL


void
PushSelf(self)
	SV* self
PREINIT:
	HV*		obj;
	SV**	obj_selfpos;
	unsigned char *selfpos;
CODE:
#ifdef WIN32_API_DEBUG
	printf("(XS)PushSelf: got self='%s' (SV=0x%08x)\n", SvPV_nolen(self), self);
#endif
	obj = (HV*) SvRV(self);
	obj_selfpos = hv_fetch(obj, "selfpos", 7, FALSE);
	if(obj_selfpos != NULL) {
#ifdef WIN32_API_DEBUG
		printf("(XS)PushSelf: obj_selfpos=0x%08x\n", SvIV(*obj_selfpos));
#endif
		*((int*)SvIV(*obj_selfpos)) = (int) self;
	}

void
DESTROY(self)
	SV* self
PREINIT:
    HV*		obj;
    SV**	obj_code;
CODE:
	obj = (HV*) SvRV(self);
	obj_code = hv_fetch(obj, "code", 4, FALSE);
	if(obj_code != NULL) free((unsigned char *) SvIV(*obj_code));


