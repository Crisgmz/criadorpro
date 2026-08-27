# Cabeceras de seguridad, en un archivo aparte porque `add_header` no se
# hereda: un `location` que declare cualquier cabecera propia pierde **todas**
# las del `server`, y las de seguridad se irían con ellas sin que nada falle.
# Incluirlas explícitamente es la única forma de que estén en todas partes.
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
