
## Ejecutar con Docker

La imagen construye la version Flutter Web y la sirve con Nginx.

### Docker Compose (recomendado)

```powershell
docker compose up --build -d
```

Abre http://localhost:8080. Para ver el estado o detener la aplicacion:

```powershell
docker compose ps
docker compose down
```

Puedes configurar la URL del backend y el puerto del frontend mediante
variables de entorno antes de construir:

```powershell
$env:API_BASE_URL = "http://localhost:3000"
$env:FRONTEND_PORT = "8080"
docker compose up --build -d
```

`API_BASE_URL` se incorpora al frontend durante la construccion de la imagen;
si cambia, vuelve a ejecutar el comando con `--build`.

### Docker sin Compose

```powershell
docker build --build-arg API_BASE_URL=http://localhost:3000 -t fitquest-go .
docker run --rm -p 8080:80 fitquest-go
```

Abre http://localhost:8080.

`API_BASE_URL` se incorpora durante el build. Usa la URL publica o accesible
desde el navegador donde este corriendo tu backend, por ejemplo:

```powershell
docker build --build-arg API_BASE_URL=https://api.example.com -t fitquest-go .
```

El backend debe permitir CORS desde el origen de la app (`http://localhost:8080`)
cuando se ejecute localmente.
# fit_quest_go

FitQuestGo mobile app

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
