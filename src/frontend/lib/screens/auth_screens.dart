import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../models/validation.dart';
import '../state/app_state.dart';
import '../ui/components.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PageShell(
      title: 'Bienvenido a tu agenda',
      showBack: false,
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Brand(large: true),
          const SizedBox(height: 35),
          const Text(
            '¿Qué tipo de usuario eres?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 36),
          LayoutBuilder(
            builder: (context, c) {
              final cards = [
                ActionTile(
                  title: 'Soy alumno',
                  subtitle: 'Ver mis tareas',
                  icon: Icons.backpack_outlined,
                  vertical: true,
                  onTap: () => openPage(context, const StudentClassesScreen()),
                ),
                ActionTile(
                  title: 'Personal o tutor',
                  subtitle: 'Preparar y acompañar',
                  icon: Icons.supervisor_account_outlined,
                  vertical: true,
                  onTap: () => openPage(context, const LoginScreen()),
                ),
              ];
              return c.maxWidth < 650
                  ? Column(children: cards)
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 28),
                        Expanded(child: cards[1]),
                      ],
                    );
            },
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () => openPage(
              context,
              const LoginScreen(initialRole: UserRole.admin),
            ),
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: const Text('Administración'),
          ),
          if (state.demo)
            const Notice(
              'Puedes probar cualquier perfil. Contraseña de demostración: 1234.',
            ),
        ],
      ),
    );
  }
}

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});
  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final form = GlobalKey<FormState>();
  TextEditingController? _url;
  TextEditingController get url => _url!;
  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _url ??= TextEditingController(text: AppScope.of(context).serverUrl);
  }

  @override
  void dispose() {
    url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: 'Conexión al servidor',
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Notice(
            'Introduce la dirección de la API de AUTOVIDA proporcionada por el equipo.',
          ),
          TextFormField(
            controller: url,
            decoration: const InputDecoration(labelText: 'Dirección de la API'),
            keyboardType: TextInputType.url,
            validator: (s) {
              final uri = Uri.tryParse(s?.trim() ?? '');
              return uri == null ||
                      !['http', 'https'].contains(uri.scheme) ||
                      uri.host.isEmpty ||
                      uri.hasQuery ||
                      uri.hasFragment ||
                      uri.userInfo.isNotEmpty
                  ? 'Escribe una dirección http o https válida, sin credenciales ni parámetros.'
                  : null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              AppScope.of(context).setServer(url.text.trim());
            },
            icon: const Icon(Icons.check),
            label: const Text('Usar este servidor'),
          ),
        ],
      ),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.initialRole = UserRole.staff,
    this.student,
  });
  final UserRole initialRole;
  final AppUser? student;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController();
  final password = TextEditingController();
  late UserRole role;
  bool busy = false, obscure = true, visual = true;
  String? error;
  static const symbols = [
    Icons.wb_sunny_outlined,
    Icons.favorite_border,
    Icons.star_border,
    Icons.pets_outlined,
    Icons.local_florist_outlined,
    Icons.directions_car_outlined,
    Icons.sports_soccer,
    Icons.home_outlined,
    Icons.park_outlined,
    Icons.music_note_outlined,
  ];
  static const names = [
    'Sol',
    'Corazón',
    'Estrella',
    'Animal',
    'Flor',
    'Coche',
    'Pelota',
    'Casa',
    'Árbol',
    'Música',
  ];
  @override
  void initState() {
    super.initState();
    role = widget.student != null ? UserRole.student : widget.initialRole;
    username.text = widget.student?.username ?? '';
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    final state = AppScope.of(context);
    try {
      await state.login(username.text.trim(), password.text, role);
      password.clear();
      if (mounted) goHome(context);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final student = role == UserRole.student;
    return PageShell(
      title: student ? 'Introduce tu contraseña' : 'Iniciar sesión',
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: student ? 850 : 650),
          child: Form(
            key: form,
            child: Column(
              children: [
                const Brand(),
                const SizedBox(height: 32),
                if (widget.student != null) ...[
                  UserAvatar(user: widget.student!, size: 150),
                  const SizedBox(height: 12),
                  Text(
                    widget.student!.displayName,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 24),
                ],
                if (!student) ...[
                  DropdownButtonFormField<UserRole>(
                    initialValue: role,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de cuenta',
                    ),
                    items: [UserRole.staff, UserRole.parent, UserRole.admin]
                        .map(
                          (r) =>
                              DropdownMenuItem(value: r, child: Text(r.label)),
                        )
                        .toList(),
                    onChanged: busy ? null : (r) => setState(() => role = r!),
                  ),
                  const SizedBox(height: 20),
                ],
                if (widget.student == null) ...[
                  TextFormField(
                    controller: username,
                    validator: usernameError,
                    enabled: !busy,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(labelText: 'Usuario'),
                  ),
                  const SizedBox(height: 24),
                ],
                if (student && visual) ...[
                  const Text(
                    'Pulsa tus dibujos en orden. Cada dibujo escribe el número que aparece debajo.',
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    label: '${password.text.length} símbolos introducidos',
                    child: Text(
                      password.text.isEmpty
                          ? '○ ○ ○ ○'
                          : List.filled(password.text.length, '●').join(' '),
                      style: const TextStyle(fontSize: 30, letterSpacing: 7),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < 10; i++)
                        SizedBox(
                          width: 110,
                          child: OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => setState(() {
                                    if (password.text.length < 72) {
                                      password.text += '$i';
                                    }
                                  }),
                            child: Column(
                              children: [
                                Icon(symbols[i], size: 36),
                                const SizedBox(height: 5),
                                Text(
                                  '${names[i]} · $i',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            if (password.text.isNotEmpty) {
                              password.text = password.text.substring(
                                0,
                                password.text.length - 1,
                              );
                            }
                          }),
                    icon: const Icon(Icons.backspace_outlined),
                    label: const Text('Borrar el último dibujo'),
                  ),
                ] else
                  TextFormField(
                    controller: password,
                    validator: passwordError,
                    enabled: !busy,
                    obscureText: obscure,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => busy ? null : submit(),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      suffixIcon: IconButton(
                        tooltip: obscure
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                if (student)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() => visual = !visual),
                    child: Text(
                      visual
                          ? 'Escribir la contraseña con el teclado'
                          : 'Usar dibujos',
                    ),
                  ),
                if (error != null) Notice(error!, error: true),
                if (state.demo)
                  Notice(
                    'Cuenta de prueba: ${student
                        ? 'pablo'
                        : role == UserRole.parent
                        ? 'familia'
                        : role == UserRole.admin
                        ? 'admin'
                        : 'lucia'}. Contraseña: 1234.',
                  ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () {
                          if (student && password.text.isEmpty) {
                            setState(() => error = 'Introduce tu contraseña.');
                            return;
                          }
                          submit();
                        },
                  icon: const Icon(Icons.login),
                  label: Text(busy ? 'Entrando…' : 'Entrar'),
                ),
                const SizedBox(height: 12),
                if (!student)
                  TextButton(
                    onPressed: () => setState(
                      () => error =
                          'Si has olvidado tu contraseña, pide al administrador del centro que la cambie.',
                    ),
                    child: const Text('He olvidado mi contraseña'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StudentClassesScreen extends StatelessWidget {
  const StudentClassesScreen({super.key});
  @override
  Widget build(BuildContext context) => PageShell(
    title: '¿A qué clase perteneces?',
    child: Column(
      children: [
        const Brand(),
        const SizedBox(height: 30),
        LoadPanel<List<Classroom>>(
          load: AppScope.of(context).repository.directory,
          builder: (classes) => PagedItems(
            items: classes,
            empty: 'Todavía no hay aulas disponibles.',
            builder: (c) => ActionTile(
              title: c.name,
              leading: ContentPicture(
                bytes: c.image,
                icon: Icons.school_outlined,
                size: 192,
              ),
              icon: Icons.school_outlined,
              onTap: () =>
                  openPage(context, StudentSelectionScreen(classroom: c)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => openPage(
            context,
            const LoginScreen(initialRole: UserRole.student),
          ),
          icon: const Icon(Icons.keyboard_outlined),
          label: const Text('Entrar con mi usuario'),
        ),
      ],
    ),
  );
}

class StudentSelectionScreen extends StatelessWidget {
  const StudentSelectionScreen({super.key, required this.classroom});
  final Classroom classroom;
  @override
  Widget build(BuildContext context) => PageShell(
    title: classroom.name,
    subtitle: 'Busca tu foto',
    child: PagedItems<AppUser>(
      items: classroom.students,
      grid: true,
      pageSize: 8,
      empty: 'No hay alumnos en esta aula.',
      builder: (u) => ActionTile(
        title: u.displayName,
        icon: Icons.person_outline,
        vertical: true,
        leading: UserAvatar(user: u, size: 155),
        onTap: () => openPage(context, LoginScreen(student: u)),
      ),
    ),
  );
}
