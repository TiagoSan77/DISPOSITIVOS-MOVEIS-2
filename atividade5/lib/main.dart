import 'package:flutter/material.dart';

void main() {
  runApp(const CadastroApp());
}

class CadastroApp extends StatelessWidget {
  const CadastroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cadastro de participante',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        useMaterial3: true,
      ),
      home: const TelaCadastro(),
    );
  }
}

// Guarda os dados do participante.
class Participante {
  final String email;
  final String nome;
  final String telefone;
  final String cpf;

  const Participante({
    required this.email,
    required this.nome,
    required this.telefone,
    required this.cpf,
  });
}

class TelaCadastro extends StatefulWidget {
  const TelaCadastro({super.key});

  @override
  State<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends State<TelaCadastro> {
  // Chave utilizada para validar o formulário inteiro.
  final _formKey = GlobalKey<FormState>();

  // Controladores dos quatro campos.
  final _emailController = TextEditingController();
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _cpfController = TextEditingController();

  // VALIDAÇÃO DO E-MAIL
  String? _validarEmail(String? valor) {
    final email = valor?.trim() ?? '';

    if (email.isEmpty) {
      return 'Informe o e-mail.';
    }

    final formato =
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!formato.hasMatch(email)) {
      return 'Informe um e-mail válido.';
    }

    return null;
  }

  // VALIDAÇÃO DO NOME
  String? _validarNome(String? valor) {
    final nome = valor?.trim() ?? '';

    if (nome.isEmpty) {
      return 'Informe o nome.';
    }

    if (nome.length < 3) {
      return 'O nome deve ter pelo menos três caracteres.';
    }

    return null;
  }

  // VALIDAÇÃO DO TELEFONE
  String? _validarTelefone(String? valor) {
    final telefone = valor?.trim() ?? '';

    if (telefone.isEmpty) {
      return 'Informe o telefone.';
    }

    // Formato exigido: DD-DDDDD-DDDD.
    final formato = RegExp(r'^\d{2}-\d{5}-\d{4}$');

    if (!formato.hasMatch(telefone)) {
      return 'Use o formato DD-DDDDD-DDDD.';
    }

    return null;
  }

  // VALIDAÇÃO DO CPF
  String? _validarCpf(String? valor) {
    final cpf = valor?.trim() ?? '';

    if (cpf.isEmpty) {
      return 'Informe o CPF.';
    }

    // Exatamente 11 números, sem pontos ou traços.
    final formato = RegExp(r'^\d{11}$');

    if (!formato.hasMatch(cpf)) {
      return 'O CPF deve conter 11 dígitos, sem pontos ou traços.';
    }

    return null;
  }

  // VALIDA OS CAMPOS E ABRE A TELA DE RESUMO.
  void _exibirDados() {
    final formularioValido =
        _formKey.currentState!.validate();

    if (!formularioValido) {
      return;
    }

    // Cria o objeto com os dados digitados.
    final participante = Participante(
      email: _emailController.text.trim(),
      nome: _nomeController.text.trim(),
      telefone: _telefoneController.text.trim(),
      cpf: _cpfController.text.trim(),
    );

    // Fecha o teclado.
    FocusScope.of(context).unfocus();

    // Abre a tela de resumo e envia os dados.
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) =>
            TelaResumo(participante: participante),
      ),
    );
  }

  // LIMPA OS CAMPOS E AS MENSAGENS DE ERRO.
  void _limpar() {
    _formKey.currentState!.reset();

    _emailController.clear();
    _nomeController.clear();
    _telefoneController.clear();
    _cpfController.clear();

    FocusScope.of(context).unfocus();
  }

  // LIBERA OS CONTROLADORES QUANDO A TELA É DESCARTADA.
  @override
  void dispose() {
    _emailController.dispose();
    _nomeController.dispose();
    _telefoneController.dispose();
    _cpfController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de participante'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Informe os dados do participante.',
                style: TextStyle(fontSize: 18),
              ),

              const SizedBox(height: 24),

              // CAMPO 1: E-MAIL
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  hintText: 'Ex.: ana@email.com',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                validator: _validarEmail,
              ),

              const SizedBox(height: 16),

              // CAMPO 2: NOME
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Ex.: Ana Souza',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.name,
                textCapitalization:
                    TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: _validarNome,
              ),

              const SizedBox(height: 16),

              // CAMPO 3: TELEFONE
              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefone',
                  hintText: 'DD-DDDDD-DDDD',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: _validarTelefone,
              ),

              const SizedBox(height: 16),

              // CAMPO 4: CPF
              TextFormField(
                controller: _cpfController,
                decoration: const InputDecoration(
                  labelText: 'CPF',
                  hintText: 'Digite 11 números',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                validator: _validarCpf,
                onFieldSubmitted: (_) => _exibirDados(),
              ),

              const SizedBox(height: 24),

              // BOTÃO PARA VALIDAR E EXIBIR OS DADOS.
              ElevatedButton(
                onPressed: _exibirDados,
                child: const Text('Exibir dados'),
              ),

              const SizedBox(height: 8),

              // BOTÃO PARA LIMPAR O FORMULÁRIO.
              OutlinedButton(
                onPressed: _limpar,
                child: const Text('Limpar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// SEGUNDA TELA: RESUMO DOS DADOS.
class TelaResumo extends StatelessWidget {
  final Participante participante;

  const TelaResumo({
    super.key,
    required this.participante,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumo do cadastro'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Dados do participante',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 24),

            Text('E-mail: ${participante.email}'),

            const SizedBox(height: 12),

            Text('Nome: ${participante.nome}'),

            const SizedBox(height: 12),

            Text('Telefone: ${participante.telefone}'),

            const SizedBox(height: 12),

            Text('CPF: ${participante.cpf}'),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Voltar para editar'),
            ),
          ],
        ),
      ),
    );
  }
}