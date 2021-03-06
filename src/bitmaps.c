/*
 * Copyright (c) 1995,1996 University College London
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed by the Computer Science
 *      Department at University College London
 * 4. Neither the name of the University nor of the Department may be used
 *    to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE UNIVERSITY AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE UNIVERSITY OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
#include <tcl.h>
#include <tk.h>

extern Tcl_Interp *interp;
#include "image_tick.xbm"
#include "image_cross.xbm"
#include "image_uparrow.xbm"
#include "image_downarrow.xbm"
#include "image_phone.xbm"
#include "image_phone1.xbm"
#include "image_phone2.xbm"
#include "image_phone3.xbm"
#include "image_phone4.xbm"
#include "image_mail.xbm"
#include "image_eye.xbm"
#include "image_audio.xbm"
#include "image_wb.xbm"
#include "image_text.xbm"
#include "image_unknown.xbm"
#include "image_clock.xbm"
#include "image_www.xbm"
#include "image_ucl.xbm"
#include "image_tools.xbm"
#include "image_bullet0.xbm"
#include "image_bullet1.xbm"
#include "image_broadcast.xbm"
#include "image_meeting.xbm"
#include "image_test.xbm"
#include "image_secure.xbm"
#include "image_sbroadcast.xbm"
#include "image_smeeting.xbm"
#include "image_stest.xbm"
#include "image_sdr.xbm"
#include "image_directory.xbm"

void init_bitmaps()
{
  Tk_DefineBitmap(interp, Tk_GetUid("tick"), tick_bits, tick_width, tick_height);
  Tk_DefineBitmap(interp, Tk_GetUid("cross"), cross_bits, cross_width, cross_height);
  Tk_DefineBitmap(interp, Tk_GetUid("uparrow"), uparrow_bits, uparrow_width, uparrow_height);
  Tk_DefineBitmap(interp, Tk_GetUid("downarrow"), downarrow_bits, downarrow_width, downarrow_height);
  Tk_DefineBitmap(interp, Tk_GetUid("phone"), phone_bits, phone_width, phone_height);
  Tk_DefineBitmap(interp, Tk_GetUid("phone1"), phone1_bits, phone1_width, phone1_height);
  Tk_DefineBitmap(interp, Tk_GetUid("phone2"), phone2_bits, phone2_width, phone2_height);
  Tk_DefineBitmap(interp, Tk_GetUid("phone3"), phone3_bits, phone3_width, phone3_height);
  Tk_DefineBitmap(interp, Tk_GetUid("phone4"), phone4_bits, phone4_width, phone4_height);
  Tk_DefineBitmap(interp, Tk_GetUid("mail"), mail_bits, mail_width, mail_height);
  Tk_DefineBitmap(interp, Tk_GetUid("eye"), (char *)eye_bits, eye_width, eye_height);
  Tk_DefineBitmap(interp, Tk_GetUid("audio"), (char *)audio_bits, audio_width, audio_height);
  Tk_DefineBitmap(interp, Tk_GetUid("wb"), (char *)wb_bits, wb_width, wb_height);
  Tk_DefineBitmap(interp, Tk_GetUid("www"), www_bits, www_width, www_height);
  Tk_DefineBitmap(interp, Tk_GetUid("text"), (char *)text_bits, text_width, text_height);
  Tk_DefineBitmap(interp, Tk_GetUid("unknown"), unknown_bits, unknown_width, unknown_height);
  Tk_DefineBitmap(interp, Tk_GetUid("clock"), clock_bits, clock_width, clock_height);
  Tk_DefineBitmap(interp, Tk_GetUid("ucl"), ucl_bits, ucl_width, ucl_height);
  Tk_DefineBitmap(interp, Tk_GetUid("tools"), tools_bits, tools_width, tools_height);
  Tk_DefineBitmap(interp, Tk_GetUid("bullet0"), bullet0_bits, bullet0_width, bullet0_height);
  Tk_DefineBitmap(interp, Tk_GetUid("bullet1"), bullet1_bits, bullet1_width, bullet1_height);
  Tk_DefineBitmap(interp, Tk_GetUid("broadcast"), broadcast_bits, broadcast_width, broadcast_height);
  Tk_DefineBitmap(interp, Tk_GetUid("meeting"), meeting_bits, meeting_width, meeting_height);
  Tk_DefineBitmap(interp, Tk_GetUid("test"), test_bits, test_width, test_height);
  Tk_DefineBitmap(interp, Tk_GetUid("sbroadcast"), sbroadcast_bits, sbroadcast_width, sbroadcast_height);
  Tk_DefineBitmap(interp, Tk_GetUid("smeeting"), smeeting_bits, smeeting_width, smeeting_height);
  Tk_DefineBitmap(interp, Tk_GetUid("stest"), stest_bits, stest_width, stest_height);
  Tk_DefineBitmap(interp, Tk_GetUid("secure"), secure_bits, secure_width, secure_height);
  Tk_DefineBitmap(interp, Tk_GetUid("sdr"), sdr_bits, sdr_width, sdr_height);
  Tk_DefineBitmap(interp, Tk_GetUid("directory"), directory_bits, directory_width, directory_height);
}
