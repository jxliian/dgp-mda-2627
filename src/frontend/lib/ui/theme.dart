import 'package:flutter/material.dart';
import '../models/domain.dart';

/// Identidad visual del Centro CeRA.
///
/// Neutros cálidos de lino, verde bosque sereno como color principal y acentos
/// de terracota y ámbar. Superficies planas con trazo visible: ni degradados ni
/// sombras difusas. Los textos sobre el fondo superan 7:1 de contraste y los
/// acentos se reservan para filos, insignias y foco.
class Paleta {
  const Paleta._();

  static const lino = Color(0xfffbf9f5); // Fondo general
  static const papel = Color(0xfff3efe6); // Tarjetas y superficies
  static const blanco = Color(0xffffffff); // Campos de formulario

  static const bosque = Color(0xff1b4332); // Principal — 14:1 sobre lino
  static const bosqueSuave = Color(0xffe4ede7);
  static const bosqueTinta = Color(0xff14402c);

  static const terracota = Color(0xffc25e3e); // Acento cálido
  static const terracotaSuave = Color(0xfffbece5);
  static const terracotaTinta = Color(0xff8a3a22);

  static const ambar = Color(0xffd97706); // Acento de atención
  static const ambarSuave = Color(0xfffdf1dc);
  static const ambarTinta = Color(0xff7a4b06);

  static const tinta = Color(0xff1f2a24); // Texto principal — 14:1
  static const tintaSuave = Color(0xff3f4c44); // Texto secundario — 8,6:1
  static const trazo = Color(0xffd9d2c4); // Separadores y tarjetas
  // Borde de los controles: 3,1:1 sobre blanco y papel (WCAG 1.4.11).
  static const trazoControl = Color(0xff8d8779);

  static const alertaSuave = Color(0xfffdece8);
  static const alertaTinta = Color(0xff8c2f1c); // Error — 7,4:1 sobre lino
}

/// Medidas compartidas. Ergonomía táctil para tablet y trazo definido.
///
/// El objetivo es que lo pulsable ocupe buena parte de la pantalla: el
/// alumnado trabaja en tablet y conviene que cada destino sea grande y fácil
/// de acertar, muy por encima del mínimo que exige la norma.
class Medidas {
  const Medidas._();

  static const alturaBoton = 76.0; // Acción principal
  static const alturaBotonMenor = 64.0; // Secundarias (mínimo WCAG 2.2: 24)
  static const alturaFicha = 112.0; // Fila de una lista pulsable
  static const iconoFicha = 52.0; // Icono de una fila
  static const iconoFichaVertical = 96.0; // Icono de una tarjeta en rejilla
  static const radioTarjeta = 18.0;
  static const radioControl = 14.0;
  static const trazo = 1.5;
  static const trazoGrueso = 2.0;
  static const anilloFoco = 3.0;
  static const filoTarjeta = 6.0; // Filo de color de las fichas
  static const anchoMaximo = 1120.0;
}

Color colorDesdeHex(String value) {
  var hex = value.replaceFirst('#', '');
  if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
  return Color(int.parse('ff$hex', radix: 16));
}

/// Colores efectivos de una sesión: los del centro o los que el alumno haya
/// personalizado en sus ajustes de accesibilidad.
class _Colores {
  _Colores(AccessSettings ajustes, {required bool alumno})
    : altoContraste = alumno && ajustes.flag('contrast') {
    fondo = altoContraste
        ? Colors.white
        : alumno
        ? colorDesdeHex(ajustes.color('main_col'))
        : Paleta.lino;
    final elegido = altoContraste
        ? Colors.black
        : alumno
        ? colorDesdeHex(ajustes.color('sec_col'))
        : Paleta.bosque;
    // Un color personalizado nunca puede volver ilegible un botón principal.
    principal = elegido.computeLuminance() > .45 ? Paleta.bosque : elegido;
    oscuro = fondo.computeLuminance() < .179;
  }

  final bool altoContraste;
  late final Color fondo;
  late final Color principal;
  late final bool oscuro;

  Color get texto => oscuro
      ? Colors.white
      : altoContraste
      ? Colors.black
      : Paleta.tinta;
  Color get textoSuave => oscuro
      ? Colors.white
      : altoContraste
      ? Colors.black
      : Paleta.tintaSuave;
  Color get superficie => oscuro
      ? const Color(0xff22352f)
      : altoContraste
      ? Colors.white
      : Paleta.papel;
  Color get campo => oscuro ? const Color(0xff22352f) : Paleta.blanco;
  /// Borde de superficies: tarjetas, separadores y bandas.
  Color get borde => oscuro
      ? Colors.white70
      : altoContraste
      ? Colors.black
      : Paleta.trazo;

  /// Borde de controles pulsables y campos, con contraste suficiente.
  Color get bordeControl => oscuro
      ? Colors.white70
      : altoContraste
      ? Colors.black
      : Paleta.trazoControl;
  Color get foco => altoContraste || oscuro ? principal : Paleta.terracota;
  Color get sobrePrincipal =>
      principal.computeLuminance() > .179 ? Colors.black : Colors.white;
}

ThemeData appTheme(AccessSettings ajustes, {bool student = false}) {
  final c = _Colores(ajustes, alumno: student);
  return ThemeData(
    useMaterial3: true,
    colorScheme: _esquema(c),
    scaffoldBackgroundColor: c.fondo,
    focusColor: c.foco,
    textTheme: _tipografia(c),
    inputDecorationTheme: _campos(c),
    filledButtonTheme: FilledButtonThemeData(style: _estiloRelleno(c)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _estiloContorno(c)),
    textButtonTheme: TextButtonThemeData(style: _estiloTexto(c)),
    iconButtonTheme: IconButtonThemeData(style: _estiloIcono(c)),
    chipTheme: _chips(c),
    cardTheme: _tarjetas(c),
    dialogTheme: _dialogos(c),
    listTileTheme: _listas(c),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStatePropertyAll(c.borde),
    ),
    dividerTheme: DividerThemeData(
      color: c.borde,
      thickness: Medidas.trazo,
      space: Medidas.trazo,
    ),
    visualDensity: VisualDensity.standard,
  );
}

ColorScheme _esquema(_Colores c) =>
    ColorScheme.fromSeed(
      seedColor: c.principal,
      brightness: c.oscuro ? Brightness.dark : Brightness.light,
    ).copyWith(
      primary: c.principal,
      onPrimary: c.sobrePrincipal,
      primaryContainer: c.oscuro || c.altoContraste
          ? c.superficie
          : Paleta.bosqueSuave,
      onPrimaryContainer: c.oscuro || c.altoContraste
          ? c.texto
          : Paleta.bosqueTinta,
      secondary: c.foco,
      surface: c.fondo,
      onSurface: c.texto,
      surfaceContainer: c.superficie,
      surfaceContainerHighest: c.superficie,
      onSurfaceVariant: c.textoSuave,
      outline: c.borde,
      outlineVariant: c.borde,
      error: Paleta.alertaTinta,
    );

/// Jerarquía tipográfica: frases cortas, caja mixta y espaciado generoso.
TextTheme _tipografia(_Colores c) {
  final base = ThemeData(
    brightness: c.oscuro ? Brightness.dark : Brightness.light,
  ).textTheme;
  return base
      .apply(bodyColor: c.texto, displayColor: c.texto)
      .copyWith(
        headlineLarge: base.headlineLarge?.copyWith(
          fontSize: 34,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -.2,
          color: c.texto,
        ),
        headlineMedium: base.headlineMedium?.copyWith(
          fontSize: 27,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: .2,
          color: c.texto,
        ),
        titleLarge: base.titleLarge?.copyWith(
          fontSize: 21,
          height: 1.3,
          fontWeight: FontWeight.w600,
          letterSpacing: .15,
          color: c.texto,
        ),
        titleMedium: base.titleMedium?.copyWith(
          fontSize: 18,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: c.texto,
        ),
        bodyLarge: base.bodyLarge?.copyWith(
          fontSize: 17,
          height: 1.5,
          letterSpacing: .1,
          color: c.texto,
        ),
        bodyMedium: base.bodyMedium?.copyWith(
          fontSize: 16,
          height: 1.5,
          letterSpacing: .1,
          color: c.textoSuave,
        ),
        labelLarge: base.labelLarge?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: .2,
        ),
      );
}

InputDecorationTheme _campos(_Colores c) {
  OutlineInputBorder borde(Color color, double ancho) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(Medidas.radioControl),
    borderSide: BorderSide(color: color, width: ancho),
  );
  return InputDecorationTheme(
    filled: true,
    fillColor: c.campo,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    labelStyle: TextStyle(fontSize: 16, color: c.textoSuave),
    helperStyle: TextStyle(fontSize: 14, color: c.textoSuave),
    helperMaxLines: 3,
    errorStyle: const TextStyle(fontSize: 15, color: Paleta.alertaTinta),
    errorMaxLines: 3,
    border: borde(c.bordeControl, Medidas.trazo),
    enabledBorder: borde(c.bordeControl, Medidas.trazo),
    focusedBorder: borde(c.foco, Medidas.anilloFoco),
    errorBorder: borde(Paleta.alertaTinta, Medidas.trazoGrueso),
    focusedErrorBorder: borde(Paleta.alertaTinta, Medidas.anilloFoco),
  );
}

/// Anillo de foco grueso y cálido, visible sobre cualquier superficie.
WidgetStateProperty<BorderSide> _ladoConFoco(
  _Colores c,
  Color base,
  double ancho,
) => WidgetStateProperty.resolveWith(
  (estados) => estados.contains(WidgetState.focused)
      ? BorderSide(color: c.foco, width: Medidas.anilloFoco)
      : BorderSide(color: base, width: ancho),
);

RoundedRectangleBorder get _formaControl => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(Medidas.radioControl),
);

ButtonStyle _estiloRelleno(_Colores c) => FilledButton.styleFrom(
  minimumSize: const Size(72, Medidas.alturaBoton),
  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
  shape: _formaControl,
).copyWith(side: _ladoConFoco(c, Colors.transparent, 0));

ButtonStyle _estiloContorno(_Colores c) => OutlinedButton.styleFrom(
  minimumSize: const Size(72, Medidas.alturaBoton),
  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
  foregroundColor: c.texto,
  backgroundColor: c.oscuro ? null : Paleta.blanco,
  shape: _formaControl,
).copyWith(side: _ladoConFoco(c, c.bordeControl, Medidas.trazoGrueso));

ButtonStyle _estiloTexto(_Colores c) => TextButton.styleFrom(
  minimumSize: const Size(64, Medidas.alturaBotonMenor),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  foregroundColor: c.oscuro ? Colors.white : Paleta.bosque,
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  shape: _formaControl,
).copyWith(side: _ladoConFoco(c, Colors.transparent, 0));

ButtonStyle _estiloIcono(_Colores c) => IconButton.styleFrom(
  minimumSize: const Size(Medidas.alturaBotonMenor, Medidas.alturaBotonMenor),
  shape: _formaControl,
).copyWith(side: _ladoConFoco(c, Colors.transparent, 0));

ChipThemeData _chips(_Colores c) => ChipThemeData(
  backgroundColor: c.oscuro ? c.superficie : Paleta.blanco,
  selectedColor: c.oscuro || c.altoContraste ? c.principal : Paleta.bosqueSuave,
  side: BorderSide(color: c.bordeControl, width: Medidas.trazo),
  labelStyle: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: c.texto,
  ),
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
  shape: _formaControl,
  showCheckmark: true,
  checkmarkColor: c.texto,
);

CardThemeData _tarjetas(_Colores c) => CardThemeData(
  elevation: 0,
  color: c.superficie,
  margin: EdgeInsets.zero,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Medidas.radioTarjeta),
    side: BorderSide(color: c.borde, width: Medidas.trazo),
  ),
);

DialogThemeData _dialogos(_Colores c) => DialogThemeData(
  backgroundColor: c.oscuro ? c.superficie : Paleta.lino,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Medidas.radioTarjeta),
    side: BorderSide(color: c.borde, width: Medidas.trazoGrueso),
  ),
  titleTextStyle: TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: c.texto,
  ),
  contentTextStyle: TextStyle(fontSize: 17, height: 1.5, color: c.texto),
);

ListTileThemeData _listas(_Colores c) => ListTileThemeData(
  minVerticalPadding: 14,
  iconColor: c.texto,
  titleTextStyle: TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: c.texto,
  ),
  subtitleTextStyle: TextStyle(fontSize: 15, color: c.textoSuave),
  shape: _formaControl,
);
