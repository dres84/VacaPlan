# Vacaplan

App para planificar las vacaciones laborales anuales. Al arrancar por primera vez pregunta:

1. Dónde vives, para obtener el calendario laboral (festivos nacionales, autonómicos y locales) del año actual y del siguiente. En España se consulta automáticamente la API pública de [calendariosnacionales.com](https://calendariosnacionales.com/es/api/); si falla o el país no es España, se pueden introducir los festivos a mano.
2. Cuántos días de vacaciones tienes.
3. Si ya has gastado días, para apuntarlos (recomendado, fecha a fecha) o indicar solo el número.

Con esto, la pantalla principal muestra los festivos del año y los días de vacaciones restantes.

## Tech Stack

- **Lenguaje:** C++
- **UI:** Qt 6 / QML
- **Build:** CMake
- **Plataformas:** macOS y Android (mismo código, patrón usado en otros proyectos de dreSoft como Weight & See)

## Build (macOS)

```bash
cmake -B build -DCMAKE_PREFIX_PATH=~/Qt/6.8.2/macos
cmake --build build
open build/appVacaplan.app
```

## Próximos pasos

- Vista de calendario con sugerencias de "puentes" (festivo + fin de semana + vacaciones).
- Edición de festivos manuales tras el onboarding.
- Build y pruebas en Android.
