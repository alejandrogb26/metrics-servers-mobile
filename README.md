# Metrics Manager — app-mobil

Cliente móvil Flutter para la plataforma **Metrics Manager**. Permite a los administradores de sistemas consultar en tiempo real el estado de servidores monitorizados, visualizar métricas de rendimiento, explorar el catálogo de servicios instalados y gestionar los grupos de usuarios y permisos.

La app se comunica exclusivamente con **api-py**, la API REST backend del proyecto, a través de HTTPS con autenticación Bearer.

---

## Tabla de contenidos

1. [Requisitos previos](#requisitos-previos)
2. [Dependencias principales](#dependencias-principales)
3. [Estructura de directorios](#estructura-de-directorios)
4. [Arquitectura por capas](#arquitectura-por-capas)
5. [Capa de modelos](#capa-de-modelos)
6. [Capa de servicios](#capa-de-servicios)
7. [Capa de providers](#capa-de-providers)
8. [Capa de presentación](#capa-de-presentación)
9. [Sistema de navegación](#sistema-de-navegación)
10. [Tema visual](#tema-visual)
11. [Flujo de autenticación](#flujo-de-autenticación)
12. [Flujo de datos: servidores y paginación](#flujo-de-datos-servidores-y-paginación)
13. [Métricas en tiempo real](#métricas-en-tiempo-real)
14. [Patrones recurrentes en la UI](#patrones-recurrentes-en-la-ui)
15. [Configuración y arranque](#configuración-y-arranque)
16. [Limitaciones conocidas](#limitaciones-conocidas)

---

## Requisitos previos

| Herramienta      | Versión mínima                                     |
| ---------------- | -------------------------------------------------- |
| Flutter SDK      | 3.x (Dart SDK `^3.10.7`)                           |
| Android SDK      | API 21+ (Android 5.0)                              |
| iOS SDK          | iOS 12+                                            |
| api-py (backend) | corriendo en `https://pfc-nginx.alejandrogb.local` |

> **Nota sobre SSL:** El entorno de desarrollo usa nginx con certificado autofirmado. La app acepta cualquier certificado SSL mediante `badCertificateCallback = true` en `ApiService`. Esto es intencionado para desarrollo local y **debe eliminarse antes de un despliegue en producción** con certificados de CA válida.

---

## Dependencias principales

| Paquete                  | Versión    | Uso                                                             |
| ------------------------ | ---------- | --------------------------------------------------------------- |
| `provider`               | `^6.1.5+1` | Gestión de estado reactivo (`ChangeNotifier` + `MultiProvider`) |
| `http`                   | `^1.6.0`   | Cliente HTTP con soporte `IOClient` para SSL personalizado      |
| `fl_chart`               | `^1.2.0`   | Gráficas de línea para métricas en tiempo real                  |
| `flutter_launcher_icons` | `^0.14.4`  | Generación del icono de la app                                  |
| `flutter_lints`          | `^6.0.0`   | Reglas de análisis estático                                     |

---

## Estructura de directorios

```
lib/
├── main.dart                          # Punto de entrada — runApp(Providers())
│
├── core/
│   ├── material_app.dart              # MonitoringApp: tema y rutas
│   └── widgets/
│       ├── shared_widgets.dart        # Widgets reutilizables (AppLoadingWidget,
│       │                              #   AppErrorWidget, EmptyStateWidget,
│       │                              #   ServerImage, ServiceLogo, etc.)
│       └── widgets.dart               # Barrel file de core/widgets/
│
├── routes/
│   └── app_routes.dart                # AppRoutes: constantes + getRoutes()
│
├── models/
│   ├── models.dart                    # Barrel file de todos los modelos
│   ├── model_paged_response.dart      # PagedResponse<T> — envelope paginado
│   ├── model_session.dart             # LoginResponse, Session, GrupoSession,
│   │                                  #   PermissionMap
│   ├── model_servidor.dart            # Servidor
│   ├── model_servicio.dart            # Servicio
│   ├── model_seccion.dart             # Seccion
│   ├── model_grupo.dart               # Grupo, GrupoPermissionMap
│   ├── model_permiso.dart             # Permiso, Ambito
│   └── metrics/
│       └── model_metrics.dart         # MetricPoint, SystemMetrics,
│                                      #   ServiceMetrics y clases auxiliares
│
├── services/
│   ├── api_service.dart               # ApiService (singleton HTTP), ApiException
│   ├── auth_service.dart              # AuthService — /auth/login, /auth/logout
│   ├── servidor_service.dart          # ServidorService — /servidor
│   ├── servicio_service.dart          # ServicioService — /servicio
│   ├── seccion_service.dart           # SeccionService — /seccion
│   ├── grupo_service.dart             # GrupoService — /grupos
│   ├── permiso_service.dart           # PermisoService — /permisos
│   └── metrics_service.dart           # MetricsService — /servidor/{id}/metrics
│
├── providers/
│   ├── providers.dart                 # Barrel + widget raíz Providers
│   ├── auth_provider.dart             # AuthProvider — sesión y permisos
│   ├── servidor_provider.dart         # ServidorProvider — lista + cachés
│   ├── grupo_provider.dart            # GrupoProvider — grupos + permisos
│   └── metrics_provider.dart          # MetricsProvider — polling de métricas
│
└── screens/
    ├── screens.dart                   # Barrel file de todas las pantallas
    ├── login/
    │   └── login_screen.dart          # LoginScreen
    ├── home/
    │   ├── home_screen.dart           # HomeScreen + Drawer + tiles
    │   └── home_user_card.dart        # HomeUserCard, _UserAvatar
    ├── servidores/
    │   ├── lista_servidores_screen.dart  # ListaServidoresScreen, ServidorCard
    │   ├── busqueda_servidores.dart      # ServidorSearchDelegate
    │   ├── lista_servicios_screen.dart   # ListaServiciosScreen
    │   └── detalle_servidor/
    │       ├── detalle_servidor_screen.dart  # DetalleServidorScreen
    │       ├── detalle_info_card.dart        # DetalleInfoCard
    │       └── detalle_servicios_list.dart   # DetalleServiciosList
    ├── metricas/
    │   └── metricas_screen.dart       # MetricasScreen (11 clases internas)
    └── gestion/
        ├── grupos_screen.dart         # GruposScreen
        └── detalle_grupo_screen.dart  # DetalleGrupoScreen, _PermisosTable
```

---

## Arquitectura por capas

La app sigue una arquitectura de **cuatro capas** con dependencias unidireccionales (las capas superiores solo dependen de las inferiores):

```
┌─────────────────────────────────────────────────────────┐
│                   PRESENTACIÓN (screens/)               │
│  Widgets Flutter · StatelessWidget · StatefulWidget     │
│  context.watch / context.read para acceder a providers  │
└────────────────────────┬────────────────────────────────┘
                         │ usa
┌────────────────────────▼────────────────────────────────┐
│                   PROVIDERS (providers/)                │
│  ChangeNotifier · estado reactivo · orquestación        │
│  Llaman a servicios, no a la UI ni a otros providers    │
└────────────────────────┬────────────────────────────────┘
                         │ usa
┌────────────────────────▼────────────────────────────────┐
│                   SERVICIOS (services/)                 │
│  Singletons · HTTP · deserialización a modelos          │
│  ApiService como transporte compartido                  │
└────────────────────────┬────────────────────────────────┘
                         │ usa
┌────────────────────────▼────────────────────────────────┐
│                    MODELOS (models/)                    │
│  Clases inmutables · fromJson · sin lógica de negocio   │
└─────────────────────────────────────────────────────────┘
```

### Principios clave

- **Las screens no llaman a servicios directamente.** Todo acceso HTTP pasa por los providers.
- **Los providers no se comunican entre sí directamente.** La coordinación ante eventos como un 401 se hace a través de `ApiService` como singleton compartido.
- **Los servicios son stateless.** Solo traducen llamadas HTTP a objetos de dominio. El estado lo guardan los providers.
- **`ApiService` es el único punto de acceso a la red.** Todos los servicios de dominio delegan en `ApiService.instance`.

---

## Capa de modelos

Los modelos son clases de datos inmutables que representan las entidades del dominio. Todos implementan un constructor `fromJson(Map<String, dynamic>)` para deserializar respuestas de api-py.

| Modelo             | Descripción                                                                                                                 |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| `PagedResponse<T>` | Envelope genérico para respuestas paginadas: `data`, `total`, `page`, `size`                                                |
| `LoginResponse`    | Respuesta del login: token Bearer + objeto `Session`                                                                        |
| `Session`          | Usuario autenticado: nombre, email, grupo, permisos. Expone `isSuperAdmin`, `canViewUserManagement()`, `canViewAnyServer()` |
| `GrupoSession`     | Snapshot ligero del grupo del usuario en sesión                                                                             |
| `PermissionMap`    | Mapa de permisos como claves compuestas string                                                                              |
| `Servidor`         | Servidor físico/virtual: id, hostname, DNS, OS, arquitectura, kernel, imagen, sección (ID), servicios (lista de IDs)        |
| `Servicio`         | Software instalable: id, nombre, logo URL                                                                                   |
| `Seccion`          | Agrupación lógica de servidores: id, nombre, descripción                                                                    |
| `Grupo`            | Grupo de usuarios con `GrupoPermissionMap` (lista de IDs por ámbito)                                                        |
| `Permiso`          | Permiso del catálogo: id, nombre, `Ambito`                                                                                  |
| `Ambito`           | Enum de categoría de permiso: `SERV`, `USER`, `SYS`                                                                         |
| `MetricPoint`      | Punto de métrica completo: timestamp + `SystemMetrics` + `ServiceMetrics`                                                   |
| `SystemMetrics`    | CPU %, RAM, swap, discos, red                                                                                               |
| `ServiceMetrics`   | Estado de Apache2, MariaDB, SSH                                                                                             |

> El barrel file `models/models.dart` exporta todos los modelos con un único import.

---

## Capa de servicios

Cada servicio es un **singleton** con el patrón `Service._()` + `static final instance`. El único que no sigue este patrón es `ApiService`, que además actúa como transporte compartido.

### `ApiService` — transporte HTTP central

`ApiService` es la única clase que realiza peticiones HTTP. El resto de servicios le delegan.

Características principales:

- **Token Bearer:** `setToken(token)` / `clearToken()` gestionados por `AuthProvider`.
- **SSL bypass:** acepta cualquier certificado (diseñado para entorno dev con nginx autofirmado).
- **Timeout:** 15 segundos por petición.
- **Errores de transporte** (`SocketException`, `HandshakeException`, `TimeoutException`) se convierten en `ApiException(statusCode: 0)`.
- **Errores HTTP** (4xx, 5xx) se convierten en `ApiException(statusCode: código)` con el mensaje extraído de las claves `message`, `detail` o `error` del cuerpo JSON.
- **401 automático:** al recibir un 401, invoca `onUnauthorized` (callback registrado por `AuthProvider`) antes de lanzar la excepción.
- **Logging en debug:** URL, cabeceras (incluido el token), código y cuerpo de cada petición.

### Servicios de dominio

| Servicio          | Endpoint                      | Métodos                        | Retorno                                                 |
| ----------------- | ----------------------------- | ------------------------------ | ------------------------------------------------------- |
| `AuthService`     | `/auth/login`, `/auth/logout` | `login`, `logout`              | `LoginResponse`, `void`                                 |
| `ServidorService` | `/servidor`                   | `getPage`, `getAll`, `getById` | `PagedResponse<Servidor>`, `List<Servidor>`, `Servidor` |
| `ServicioService` | `/servicio`                   | `getAll`, `getById`            | `List<Servicio>`, `Servicio`                            |
| `SeccionService`  | `/seccion`                    | `getAll`, `getById`            | `List<Seccion>`, `Seccion`                              |
| `GrupoService`    | `/grupos`                     | `getAll`, `getById`            | `List<Grupo>`, `Grupo`                                  |
| `PermisoService`  | `/permisos`                   | `getAll`                       | `List<Permiso>`                                         |
| `MetricsService`  | `/servidor/{id}/metrics`      | `getMetrics`                   | `List<MetricPoint>`                                     |

> Los endpoints de api-py usan el singular (`/servidor`, `/servicio`, `/seccion`) a diferencia del convenio REST habitual de plural. Los servicios reproducen ese nombre tal cual.

> `getAll` en `GrupoService`, `PermisoService`, `ServicioService` y `SeccionService` solicita siempre `page=0, size=100` (primera página, máximo 100 ítems). Ver [Limitaciones conocidas](#limitaciones-conocidas).

---

## Capa de providers

Los providers implementan el patrón `ChangeNotifier` y se registran globalmente en `MultiProvider` (widget `Providers`). Las pantallas los consumen con `context.watch<T>()` (reactivo) o `context.read<T>()` (puntual).

### `AuthProvider`

Gestiona el ciclo de vida completo de la autenticación.

**Estados (`AuthStatus`):**

```
initial ──→ loading ──→ authenticated   (login OK)
                    └──→ error           (login fallido)
authenticated ────────→ initial          (logout o 401 en cualquier petición)
```

**Métodos públicos:**

| Método / getter             | Descripción                                                                 |
| --------------------------- | --------------------------------------------------------------------------- |
| `login(username, password)` | Autentica contra api-py, inyecta token, registra callback 401               |
| `logout()`                  | Revoca callback 401, cierra sesión en servidor (best-effort), limpia estado |
| `status`                    | Estado actual (`AuthStatus`)                                                |
| `session`                   | Datos del usuario autenticado (`Session?`)                                  |
| `errorMessage`              | Mensaje del último error de login                                           |
| `isAuthenticated`           | `true` si hay sesión activa                                                 |
| `isSuperAdmin`              | `true` si el grupo del usuario es superadmin                                |
| `canViewUserManagement()`   | Comprobación de acceso a gestión                                            |
| `canViewAnyServer()`        | Comprobación de acceso a servidores                                         |

### `ServidorProvider`

Gestiona la lista paginada de servidores y los catálogos de resolución de IDs.

**Estado expuesto:**

| Getter           | Tipo                 | Descripción                                   |
| ---------------- | -------------------- | --------------------------------------------- |
| `servidores`     | `List<Servidor>`     | Lista acumulada de todas las páginas cargadas |
| `isLoading`      | `bool`               | Carga de la primera página en curso           |
| `isLoadingMore`  | `bool`               | Carga de página adicional en curso            |
| `hasNext`        | `bool`               | Existen más páginas por cargar                |
| `error`          | `String?`            | Mensaje del último error                      |
| `serviciosCache` | `Map<int, Servicio>` | Lookup id → Servicio                          |
| `seccionesCache` | `Map<int, Seccion>`  | Lookup id → Seccion                           |

**Métodos clave:**

- `loadFirstPage()`: carga la página 0. Tiene guarda de re-entrada y de back-navigation.
- `loadNextPage()`: acumula la siguiente página. Llamado desde el `ScrollController` de `ListaServidoresScreen` cuando el usuario está a 300 px del final.
- `preloadCaches()`: carga `serviciosCache` y `seccionesCache` mediante `ServicioService` y `SeccionService`. Tiene guarda: no recarga si ambos cachés ya están poblados.
- `search(query)`: filtro client-side síncrono sobre `servidores` (hostname, DNS, ID).
- `invalidate()`: resetea paginación sin borrar cachés.

### `GrupoProvider`

Carga los grupos y el catálogo de permisos para la pantalla de administración.

- `loadAll()`: carga grupos y permisos en paralelo mediante `GrupoService` y `PermisoService`.
- `getPermisoById(id)`: lookup O(1) en el mapa de permisos en caché.
- `invalidate()`: resetea el estado para forzar recarga.

### `MetricsProvider`

Gestiona el polling periódico de métricas para un servidor concreto.

- `startPolling(serverId)`: inicia un `Timer.periodic` que llama a `MetricsService.getMetrics` en cada intervalo.
- `stopPolling()`: cancela el timer. Llamado por `MetricasScreen.dispose()`.
- `metricPoints`: lista de `MetricPoint` de la sesión de polling activa.

`MetricsProvider` se registra globalmente (no a nivel de pantalla) para que el estado del polling sobreviva a navegaciones internas sin reiniciarse.

---

## Capa de presentación

### Pantallas

| Ruta                      | Pantalla                | Descripción                                                                                                                                                                                                                  |
| ------------------------- | ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/login`                  | `LoginScreen`           | Formulario de login (usuario + contraseña). Guardia `mounted` antes de navegar. Usa `pushReplacementNamed` para impedir volver al login con el botón atrás.                                                                  |
| `/home`                   | `HomeScreen`            | Panel principal con `Drawer`. Tiles de acceso a servidores, servicios y gestión. Muestra la tarjeta del usuario autenticado. Guardia de sesión con `addPostFrameCallback` + `pushNamedAndRemoveUntil`.                       |
| `/servidores`             | `ListaServidoresScreen` | Lista paginada con `CustomScrollView` + `SliverList`. Scroll infinito mediante `ScrollController` (threshold 300 px). Servidores agrupados por sección. Apertura automática del buscador si se navega con `arguments: true`. |
| `/servidores/detalle`     | `DetalleServidorScreen` | Detalle de un servidor con `SliverAppBar(expandedHeight: 220, pinned: true)`. Imagen de fondo, info general, servicios asociados y botón de métricas.                                                                        |
| `/servidores/metricas`    | `MetricasScreen`        | Métricas en tiempo real: CPU, RAM, disco, red, servicios (Apache, MariaDB, SSH). Gráficas de línea (`fl_chart`), barras de workers de Apache. Polling automático, indicador de refresco animado.                             |
| `/servicios`              | `ListaServiciosScreen`  | Catálogo de servicios con chips de hostname de los servidores cargados que usan cada servicio.                                                                                                                               |
| `/gestion/grupos`         | `GruposScreen`          | Lista de grupos de usuarios. Solo accesible para usuarios con permisos de gestión.                                                                                                                                           |
| `/gestion/grupos/detalle` | `DetalleGrupoScreen`    | Detalle de un grupo con tabla de permisos. Resuelve IDs a nombres y colores por ámbito (`SERV`→azul, `USER`→verde, `SYS`→dorado).                                                                                            |

### Widgets compartidos (`core/widgets/`)

Los widgets reutilizables de la app están centralizados en `shared_widgets.dart`:

| Widget             | Descripción                                      |
| ------------------ | ------------------------------------------------ |
| `AppLoadingWidget` | Spinner centrado con mensaje opcional            |
| `AppErrorWidget`   | Estado de error con mensaje y botón "Reintentar" |
| `EmptyStateWidget` | Estado vacío con icono y mensaje                 |
| `ServerImage`      | Imagen de servidor con fallback a `no_image.png` |
| `ServiceLogo`      | Logo de servicio con fallback a `no_image.png`   |

---

## Sistema de navegación

La app usa el **sistema clásico de rutas con nombre** de Flutter (`MaterialApp.routes` + `initialRoute`). No usa GoRouter ni Navigator 2.0.

```
/login  ──(login OK)──→  /home
                          ├──→  /servidores
                          │       ├──→  /servidores/detalle
                          │       │       └──→  /servidores/metricas
                          │       └──(búsqueda abre SearchDelegate)
                          ├──→  /servicios
                          └──→  /gestion/grupos
                                  └──→  /gestion/grupos/detalle
```

**Argumentos de ruta:** Los datos complejos (un objeto `Servidor`, un objeto `Grupo`) se pasan como `arguments` en `Navigator.pushNamed` y se recuperan con `ModalRoute.of(context)!.settings.arguments`.

**Gestión del stack:**

- Login → Home: `pushReplacementNamed` (elimina `/login` del stack).
- Logout: `pushNamedAndRemoveUntil(login, (route) => false)` (limpia el stack completo).
- Búsqueda: `SearchDelegate` con `close(context, servidor)` antes de `pushNamed` para cerrar el overlay.

**Control de acceso:** No hay guardas de ruta en el registro del mapa. Cada pantalla comprueba internamente si el usuario tiene sesión y permisos, redirigiendo si es necesario.

---

## Tema visual

La app usa **Material 3** con un tema oscuro inspirado en la paleta **GitHub Dark**, definido globalmente en `MonitoringApp._buildTheme()`.

| Color hex    | Nombre informal | Uso                                      |
| ------------ | --------------- | ---------------------------------------- |
| `0xFF0D1117` | Negro-azulado   | Fondo de Scaffold (capa base)            |
| `0xFF161B22` | Gris muy oscuro | Cards, AppBar, Drawer (capa 1)           |
| `0xFF21262D` | Gris oscuro     | Inputs, chips, fondo elevado (capa 2)    |
| `0xFF30363D` | Gris            | Bordes y separadores                     |
| `0xFF8B949E` | Gris claro      | Texto y iconos secundarios               |
| `0xFF1F6FEB` | Azul            | Acento primario: botones, foco de inputs |

Componentes con tema explícito: `CardTheme`, `AppBarTheme`, `DrawerTheme`, `InputDecorationTheme`, `ElevatedButtonTheme`, `ChipTheme`.

> Las pantallas individuales usan `Color(0xFF...)` directamente para colores puntuales (barras de progreso, indicadores de estado, gradientes) sin definir un sub-tema. El color semilla para la paleta M3 es `0xFF1565C0` (azul profundo).

---

## Flujo de autenticación

```
LoginScreen
    │  usuario introduce credenciales
    │  context.read<AuthProvider>().login(user, pass)
    ▼
AuthProvider.login()
    │  AuthService.instance.login(user, pass)
    │      └─ ApiService.instance.post('/auth/login', {...})
    │             └─ HTTP POST → api-py
    │  ◄─── LoginResponse { token, session }
    │  ApiService.instance.setToken(token)
    │  ApiService.instance.onUnauthorized = _invalidateSession
    │  _status = authenticated
    │  notifyListeners()
    ▼
LoginScreen
    │  auth.status == authenticated → pushReplacementNamed('/home')
    ▼
HomeScreen
    │  context.watch<AuthProvider>()
    │  si !isAuthenticated → pushNamedAndRemoveUntil('/login')
    ▼
(cualquier petición HTTP posterior)
    │  ApiService incluye Authorization: Bearer {token}
    │  Si respuesta 401 → onUnauthorized() → _invalidateSession()
    │      └─ _status = initial, notifyListeners()
    │      └─ HomeScreen detecta el cambio → vuelve a /login
```

**Logout iniciado por el usuario (orden crítico):**

1. `ApiService.onUnauthorized = null` (evita callback redundante durante el logout).
2. `AuthService.logout()` → POST `/auth/logout` (best-effort, se ignora el error).
3. `ApiService.clearToken()`.
4. `_status = initial` + `notifyListeners()`.

---

## Flujo de datos: servidores y paginación

```
ListaServidoresScreen (StatefulWidget)
    │  initState / addPostFrameCallback
    │      ├─ ServidorProvider.preloadCaches()   → ServicioService + SeccionService
    │      └─ ServidorProvider.loadFirstPage()   → ServidorService.getPage(page:0)
    │
    │  ScrollController._onScroll()
    │      └─ si distancia al final < 300 px → ServidorProvider.loadNextPage()
    │                                               → ServidorService.getPage(page: n+1)
    │
    │  Consumer<ServidorProvider> rebuild
    │      └─ agrupa servidores por sección (Map<int, List<Servidor>> preserva orden)
    │      └─ ServidorCard por cada servidor
    │
    ├─ AppBar → IconButton → showSearch(ServidorSearchDelegate)
    │      └─ ServidorProvider.search(query)  [client-side, síncrono]
    │
    └─ ServidorCard → tap → pushNamed('/servidores/detalle', arguments: servidor)
```

**Resolución de IDs:** `Servidor.seccion` (int) y `Servidor.servicios` (List\<int\>) se resuelven a objetos completos usando `ServidorProvider.seccionesCache` y `ServidorProvider.serviciosCache` en O(1).

---

## Métricas en tiempo real

```
MetricasScreen (StatefulWidget)
    │  didChangeDependencies (no initState: ModalRoute no disponible en initState)
    │      └─ _initialized guard (evita re-ejecución en rebuilds)
    │      └─ MetricsProvider.startPolling(servidor.id)
    │             └─ Timer.periodic(intervalo)
    │                   └─ MetricsService.getMetrics(serverId, rangeMinutes: 60)
    │                          └─ GET /servidor/{id}/metrics?minutes=60
    │
    │  dispose()
    │      └─ MetricsProvider.stopPolling()  → cancela Timer
    │
    │  Consumer<MetricsProvider>
    │      ├─ _LineChartCard       → CPU y RAM (fl_chart LineChart, eje X posicional)
    │      ├─ _DualLineChartCard   → red (entrada/salida en el mismo chart)
    │      ├─ _DiskUsageCard       → uso de discos (_formatBytes, prefijos binarios 1024)
    │      ├─ _WorkersBarCard      → workers Apache (barras proporcionales Expanded(flex))
    │      └─ _ServiceStatusCard   → estado Apache, MariaDB, SSH
    │
    │  _RefreshIndicatorDot
    │      └─ AnimationController.repeat(reverse: true)  → pulso animado
```

**Estrategia del eje X en gráficas:** `fl_chart` recibe puntos con índice posicional (0, 1, 2…), no con timestamp real. Esto simplifica la configuración pero no refleja intervalos de tiempo irregulares entre muestras.

**Techo dinámico:** `maxY = max(valores) * 1.2 + 0.1` garantiza un margen visual sobre el valor máximo y evita que la línea quede pegada al borde superior.

---

## Patrones recurrentes en la UI

### FutureBuilder + Consumer

Usado en `ListaServiciosScreen` y `GruposScreen`:

1. `FutureBuilder` sobre un `Future` almacenado en el estado del widget (evita relanzarlo en cada rebuild).
2. Mientras el Future no completa → spinner.
3. Si el Future falla → `AppErrorWidget` con botón de reintento.
4. Una vez completado → `Consumer<T>` para reactividad posterior sin relanzar el Future.

### `didChangeDependencies` con flag `_initialized`

Usado en `MetricasScreen` para inicializar el polling:

```dart
bool _initialized = false;

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  if (_initialized) return;
  _initialized = true;
  // acceso a ModalRoute.of(context) aquí — no disponible en initState
  final servidor = ModalRoute.of(context)!.settings.arguments as Servidor;
  context.read<MetricsProvider>().startPolling(servidor.id);
}
```

`didChangeDependencies` se llama después de `initState` y después de cada cambio de dependencias heredadas, pero el flag `_initialized` garantiza que el bloque de setup se ejecute solo una vez.

### `context.watch` vs `context.read`

- `context.watch<T>()`: suscribe el widget al provider. Se usa en `build()` cuando el widget debe reconstruirse ante cambios del provider.
- `context.read<T>()`: acceso puntual sin suscripción. Se usa en callbacks de eventos (tap, submit) o en `initState`/`didChangeDependencies` donde no hay que reconstruir el widget por ese acceso.

### Scroll infinito con threshold

```dart
void _onScroll() {
  final position = _scrollController.position;
  if (position.pixels >= position.maxScrollExtent - 300) {
    context.read<ServidorProvider>().loadNextPage();
  }
}
```

El threshold de 300 px activa la carga preventiva antes de que el usuario llegue al final, eliminando la espera visible al final de la lista.

---

## Configuración y arranque

### 1. Clonar e instalar dependencias

```bash
flutter pub get
```

### 2. Configurar la URL del backend

La URL base de api-py está definida en `lib/services/api_service.dart`:

```dart
String baseUrl = 'https://pfc-nginx.alejandrogb.local';
```

Modifica este valor para apuntar al entorno deseado. En producción con CA válida, elimina también el `badCertificateCallback`.

### 3. Ejecutar en dispositivo o emulador

```bash
flutter run
```

Para una build de release:

```bash
flutter build apk --release          # Android
flutter build ios --release          # iOS (requiere macOS + Xcode)
```

### 4. Análisis estático

```bash
flutter analyze
```

### 5. Regenerar el icono de la app

```bash
flutter pub run flutter_launcher_icons
```

La configuración del icono está en `flutter_launcher_icons.yaml` y el asset original en `assets/icon/metrics_servers_logo.png`.

---

## Limitaciones conocidas

### Paginación fija en catálogos

`GrupoService`, `PermisoService`, `ServicioService` y `SeccionService` solicitan siempre `page=0, size=100`. Si algún catálogo supera 100 entradas:

- Los grupos, permisos, servicios o secciones restantes no se cargarán.
- No hay ningún aviso visual de que la lista está truncada.
- En el caso de permisos, los IDs no resueltos aparecen como `#id` en `DetalleGrupoScreen`.

### Búsqueda client-side únicamente

`ServidorProvider.search` y `ServidorSearchDelegate` filtran solo los servidores ya cargados en memoria. Con 200 servidores totales y 20 cargados, la búsqueda solo cubre esos 20. No hay endpoint de búsqueda server-side.

### Sin persistencia de sesión

El token Bearer se almacena en memoria (`ApiService._token`). Cada arranque en frío requiere un nuevo login. No se usa `flutter_secure_storage` ni ningún otro mecanismo de persistencia.

### Sin refresco de token

Cuando un token expira en el servidor, la siguiente petición recibe un 401 y la sesión se invalida automáticamente (`_invalidateSession`). No hay implementación de refresh token: el usuario debe volver a hacer login.

### Estado de servidor siempre "En línea"

`DetalleServidorScreen` muestra el estado del servidor como "En línea" de forma hardcodeada. No hay ningún campo de estado real obtenido de api-py.

### SSL bypass en toda la app

`ApiService._buildClient()` acepta cualquier certificado SSL devolviendo siempre `true` en `badCertificateCallback`. Esto es aceptable en desarrollo contra un nginx local, pero **introduce un riesgo de MITM en producción**.

### Asociación servicio → servidores es parcial

En `ListaServiciosScreen`, los chips de hostname bajo cada servicio reflejan únicamente los servidores ya cargados en `ServidorProvider.servidores`. Si el usuario accede al catálogo de servicios directamente desde Home sin haber pasado por la lista de servidores, no aparecerá ningún chip.
