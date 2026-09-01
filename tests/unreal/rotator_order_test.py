# Python pozicioni redosled unreal.Rotator NIJE citljiv iz izvora: FRotator se registruje
# preko genericnog TPyWrapperInlineStructFactory<FRotator> (PyWrapperMath.cpp) bez rucno
# pisanog redosleda, pa bi se ocekivalo da prati reflektovana polja (Pitch, Yaw, Roll).
# Ne prati — izmereno je (roll, pitch, yaw). Ako Epic to ikad promeni, ovaj test pukne
# umesto da tiho dobijes pogresnu rotaciju.
#
# Pokretanje (ne kao root, Editor zatvoren, radi headless):
#   <EngineRoot>/Engine/Binaries/Linux/UnrealEditor-Cmd <proj>.uproject \
#       -run=pythonscript -script=<abs>/rotator_order_test.py \
#       -unattended -nosplash -RenderOffscreen -NoSound
# Rezultat trazi u stdout-u ILI u Saved/Logs/<proj>.log (unreal.log() ne ide na stdout u
# commandlet rezimu — zato ispod ide i print i unreal.log_error, plus exit code).

import sys

import unreal

R = unreal.Rotator(1.0, 2.0, 3.0)
K = unreal.Rotator(roll=1.0, pitch=2.0, yaw=3.0)
positional = (R.roll, R.pitch, R.yaw)
keyword = (K.roll, K.pitch, K.yaw)

ok = positional == (1.0, 2.0, 3.0) and keyword == (1.0, 2.0, 3.0)
msg = (
    f"ROTATOR_ORDER_TEST {'PASS' if ok else 'FAIL'}: "
    f"Rotator(1,2,3) -> roll={R.roll} pitch={R.pitch} yaw={R.yaw}; "
    f"keyword -> roll={K.roll} pitch={K.pitch} yaw={K.yaw}"
)
print(msg)
(unreal.log if ok else unreal.log_error)(msg)
if not ok:
    sys.exit(1)
