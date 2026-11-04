# gastos_app

App de gastos de Jhonny, marca propia, solo de práctica: no se conecta a
ninguna cuenta ni banco. Agrega gastos (qué, monto, categoría), ve el total
y los totales por categoría, y borra gastos. Los datos se guardan en el
dispositivo con `shared_preferences` y ya no se borran al cerrar.

## App publicada

https://ingpalestinareza-netizen.github.io/gastos_app/

En el iPhone se puede agregar a la pantalla de inicio desde Safari para
abrirla en pantalla completa, mientras la versión nativa espera a la Mac mini.

La publica GitHub Pages en automático cada vez que se sube código a `main`
(ver `.github/workflows/deploy-pages.yml`).

## Correr en local

```sh
flutter pub get
flutter run -d chrome
```
