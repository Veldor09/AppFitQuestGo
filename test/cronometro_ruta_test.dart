import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/rutas/application/cronometro_ruta.dart';

void main() {
  late DateTime ahora;
  late CronometroRuta cronometro;

  void avanzar(int segundos) => ahora = ahora.add(Duration(seconds: segundos));

  setUp(() {
    ahora = DateTime(2026, 10, 5, 8);
    cronometro = CronometroRuta(ahora: () => ahora);
  });

  test('antes de iniciar marca cero y no esta corriendo', () {
    expect(cronometro.estado, EstadoCronometro.inactivo);
    expect(cronometro.transcurrido, Duration.zero);
    avanzar(30);
    expect(cronometro.transcurrido, Duration.zero);
  });

  test('cuenta el tiempo desde que se inicia', () {
    cronometro.iniciar();
    avanzar(90);

    expect(cronometro.estado, EstadoCronometro.corriendo);
    expect(cronometro.transcurrido, const Duration(seconds: 90));
  });

  test('pausar congela el tiempo', () {
    cronometro.iniciar();
    avanzar(60);
    cronometro.pausar();
    avanzar(600);

    expect(cronometro.estado, EstadoCronometro.pausado);
    expect(cronometro.transcurrido, const Duration(seconds: 60));
  });

  test('reanudar suma solo el tiempo en movimiento, sin lo pausado', () {
    cronometro.iniciar();
    avanzar(60);
    cronometro.pausar();
    avanzar(600);
    cronometro.reanudar();
    avanzar(30);

    expect(cronometro.estado, EstadoCronometro.corriendo);
    expect(cronometro.transcurrido, const Duration(seconds: 90));
  });

  test('varias pausas acumulan bien', () {
    cronometro.iniciar();
    avanzar(10);
    cronometro.pausar();
    avanzar(100);
    cronometro.reanudar();
    avanzar(20);
    cronometro.pausar();
    avanzar(100);
    cronometro.reanudar();
    avanzar(5);

    expect(cronometro.transcurrido, const Duration(seconds: 35));
  });

  test('detener congela el tiempo y deja la sesion finalizada', () {
    cronometro.iniciar();
    avanzar(45);
    cronometro.detener();
    avanzar(100);

    expect(cronometro.estado, EstadoCronometro.finalizado);
    expect(cronometro.transcurrido, const Duration(seconds: 45));
  });

  test('detener estando pausado conserva lo corrido hasta la pausa', () {
    cronometro.iniciar();
    avanzar(45);
    cronometro.pausar();
    avanzar(100);
    cronometro.detener();

    expect(cronometro.transcurrido, const Duration(seconds: 45));
  });

  test('pausar dos veces o reanudar sin pausa no altera nada', () {
    cronometro.iniciar();
    avanzar(10);
    cronometro.reanudar(); // ya corre
    cronometro.pausar();
    avanzar(50);
    cronometro.pausar(); // ya esta pausado
    avanzar(50);

    expect(cronometro.transcurrido, const Duration(seconds: 10));
  });

  test('pausar o reanudar sin iniciar no hace nada', () {
    cronometro.pausar();
    cronometro.reanudar();
    avanzar(30);

    expect(cronometro.estado, EstadoCronometro.inactivo);
    expect(cronometro.transcurrido, Duration.zero);
  });

  test('reiniciar vuelve a cero e inactivo', () {
    cronometro.iniciar();
    avanzar(45);
    cronometro.detener();
    cronometro.reiniciar();

    expect(cronometro.estado, EstadoCronometro.inactivo);
    expect(cronometro.transcurrido, Duration.zero);
  });

  test('iniciar de nuevo empieza desde cero', () {
    cronometro.iniciar();
    avanzar(45);
    cronometro.detener();
    cronometro.iniciar();
    avanzar(5);

    expect(cronometro.transcurrido, const Duration(seconds: 5));
  });
}
