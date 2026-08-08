# Plantillas de correo

Se pegan a mano en **Authentication → Emails** del dashboard de Supabase. Los
archivos `.html` de esta carpeta están listos para copiar tal cual: sin
comentarios ni envoltorios, porque el editor del dashboard guarda el cuerpo
literal.

| Plantilla del dashboard | Archivo | Asunto sugerido |
|---|---|---|
| Confirm sign up | [confirm_signup.html](confirm_signup.html) | `Tu código de verificación — Criador Pro` |
| Reset password | [reset_password.html](reset_password.html) | `Recupera tu contraseña — Criador Pro` |

## Por qué código y no enlace

`RF-AUT-06` y `RF-AUT-12` piden un código de seis dígitos: las pantallas 5 y 8
son seis casillas. De ahí que el cuerpo use `{{ .Token }}` y nunca
`{{ .ConfirmationURL }}`.

## Requisitos

- **SMTP propio configurado.** Con el correo integrado de Supabase, el editor
  acepta los cambios pero se sigue enviando la plantilla por defecto. El aviso
  «Set up custom SMTP to edit templates» tiene que haber desaparecido.
- **Vigencia del código en 600 s** (`RV-04`): Sign In / Providers → Email →
  *Email OTP Expiration*.

## Terminología

El correo es un punto de contacto más, así que le aplica la restricción del
BRD §8: ni una palabra de combate, riña o apuesta. Cualquier cambio en estos
textos pasa por la misma revisión que los `.arb`.
